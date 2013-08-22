# Trains up cross word models by first training monophone
# models using the phonetically transcribed data in the TIMIT
# corpus.
#
# This version uses both the SI-84 and SI-200 trianing data
# during a single training run.
#
# Note: WSJ0_DIR and WSJ1_DIR should be directories below
# WSJ_ROOT on the file system.

echo "Training cross word triphones using TIMIT and SI-284 data from WSJ0, WSJ1..."
echo ""
echo "Environment variables:"
echo "TRAIN_TIMIT    = $TRAIN_TIMIT"
echo "TRAIN_WSJ0     = $TRAIN_WSJ0"
echo "TRAIN_WSJ1     = $TRAIN_WSJ1"
echo "TRAIN_COMMON   = $TRAIN_COMMON"
echo "TRAIN_SCRIPTS  = $TRAIN_SCRIPTS"
echo "TIMIT_DIR      = $TIMIT_DIR"
echo "WSJ0_DIR       = $WSJ0_DIR"
echo "WSJ1_DIR       = $WSJ1_DIR"
echo "WSJ_ROOT       = $WSJ_ROOT"
echo "HEREST_SPLIT   = $HEREST_SPLIT"
echo "HEREST_THREADS = $HEREST_THREADS"
echo ""

# We need to massage the CMU dictionary for our use
echo "Preparing CMU dictionary..."
cd $TRAIN_TIMIT
$TRAIN_TIMIT/prep_cmu_dict.sh

# Code the audio files to MFCC feature vectors
echo "Coding TIMIT..."
$TRAIN_TIMIT/prep_code.sh

# Use the transcriptions to train up the monophone models
echo "Training TIMIT monophones..."
$TRAIN_TIMIT/train_mono.sh

# As a sanity check, we'll evaluate the monophone models
# doing just phone recognition on the training data.
echo "Evaluating TIMIT monophones..."
$TRAIN_TIMIT/eval_mono.sh

# Now we'll start in on the WSJ0 training data
cd $TRAIN_WSJ0

# Code the audio files to MFCC feature vectors
echo "Coding WSJ0 audio..."
$TRAIN_WSJ0/prep.sh
echo "Coding Nov92 audio..."
$TRAIN_WSJ0/prep_nov92.sh
echo "Coding WSJ1 audio..."
$TRAIN_WSJ1/prep.sh

# Initial setup of language model, dictionary, training and test MLFs
echo "Building language models and dictionary..."
$TRAIN_WSJ0/build_lm.sh

echo "Building training MLF..."
$TRAIN_WSJ1/make_mlf.sh 
echo "Building test MLF..."
$TRAIN_WSJ0/make_mlf_nov92.sh

# Create a new MLF that is aligned based on our monophone model
echo "Aligning with monophones..."
$TRAIN_WSJ1/align_mlf.sh

# More training for the monophones, create triphones, train
# triphones, tie the triphones, train tied triphones, then
# mixup the number of Gaussians per state.
echo "Training monophones..."
$TRAIN_WSJ1/train_mono.sh
echo "Prepping triphones..."
$TRAIN_WSJ1/prep_tri.sh cross
echo "Training triphones..."
$TRAIN_WSJ1/train_tri.sh

# These values of RO and TB seem to work fairly well, but
# there may be more optimal values.  These values were
# tuned to perform well on the Nov92 test set.
echo "Prepping state-tied triphones..."
$TRAIN_WSJ1/prep_tied.sh 200 750 cross
echo "Training state-tied triphones..."
$TRAIN_WSJ1/train_tied.sh

cp $TRAIN_WSJ1/tiedlist $TRAIN_WSJ0/tiedlist

echo "Mixing up..."
$TRAIN_WSJ1/train_mixup.sh
$TRAIN_WSJ1/train_mixup2.sh
$TRAIN_WSJ1/train_mixup3.sh
$TRAIN_WSJ1/train_mixup4.sh

# Evaluate how we did, also produces lattices we use for tuning.
echo "Evaluating on Nov92 test set..."
$TRAIN_WSJ1/eval_nov92.sh hmm72 _ro200_tb750_prune250_cross_si284 250.0 -4.0 15.0 cross

# Tune the insertion penalty and language model scale factor
echo "Tuning insertion penalty and scale factor..."
$TRAIN_WSJ1/tune.sh cross

# You can probably now increase results slightly by running
# the best penalty and scale factor with a higher beam width,
# say 350.0.  Then relax and have a beer- you've earned it.

$TRAIN_WSJ1/eval_nov92_no_lat.sh hmm72 _ro200_tb750_prune350_cross_si284 350.0 -4.0 15.0 cross


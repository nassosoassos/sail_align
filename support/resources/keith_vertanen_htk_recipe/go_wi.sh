# Trains up word internal models by first training monophone
# models using the phonetically transcribed data in the TIMIT
# corpus.

echo "Training word internal triphones using TIMIT and WSJ0..."
echo ""
echo "Environment variables:"
echo "TRAIN_TIMIT    = $TRAIN_TIMIT"
echo "TRAIN_WSJ0     = $TRAIN_WSJ0"
echo "TRAIN_COMMON   = $TRAIN_COMMON"
echo "TRAIN_SCRIPTS  = $TRAIN_SCRIPTS"
echo "TIMIT_DIR      = $TIMIT_DIR"
echo "WSJ0_DIR       = $WSJ0_DIR"
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

echo "Coding Nov92 audio..."
$TRAIN_WSJ0/prep_nov92.sh

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
echo "Coding audio..."
$TRAIN_WSJ0/prep.sh

# Initial setup of language model, dictionary, training and test MLFs
echo "Building language models and dictionary..."
$TRAIN_WSJ0/build_lm.sh
echo "Building training MLF..."
$TRAIN_WSJ0/make_mlf.sh 
echo "Building test MLF..."
$TRAIN_WSJ0/make_mlf_nov92.sh

# Create a new MLF that is aligned based on our monophone model
echo "Aligning with monophones..."
$TRAIN_WSJ0/align_mlf.sh

# More training for the monophones, create triphones, train
# triphones, tie the triphones, train tied triphones, then
# mixup the number of Gaussians per state.
echo "Training monophones..."
$TRAIN_WSJ0/train_mono.sh
echo "Prepping triphones..."
$TRAIN_WSJ0/prep_tri.sh
echo "Training triphones..."
$TRAIN_WSJ0/train_tri.sh

# These values of RO and TB seem to work fairly well, but
# there may be more optimal values.
echo "Prepping state-tied triphones..."
$TRAIN_WSJ0/prep_tied.sh 200 750

echo "Training state-tied triphones..."
$TRAIN_WSJ0/train_tied.sh
echo "Mixing up..."
$TRAIN_WSJ0/train_mixup.sh

# Evaluate how we did, also produces lattices we use for tuning
echo "Evaluating on Nov92 test set..."
$TRAIN_WSJ0/eval_nov92.sh hmm42 _ro200_tb750_prune250_wi 250.0 -0.0 15.0

# Tune the insertion penalty and language model scale factor
echo "Tuning insertion penalty and scale factor..."
$TRAIN_WSJ0/tune.sh

# You can probably now increase results slightly by running
# the best penalty and scale factor with a higher beam width,
# say 350.0.  Then relax and have a beer- you've earned it.

$TRAIN_WSJ0/eval_nov92_no_lat.sh hmm42 _ro200_tb750_prune350_wi 350.0 -0.0 15.0



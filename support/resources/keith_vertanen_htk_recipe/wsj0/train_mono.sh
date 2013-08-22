# Take the best TIMIT monophone models and reestimate using the
# forced aligned phone transcriptions of WSJ0.
#
# Parameters:
#  $1 - "flat" if we are flat starting from monophone models living
#       in hmm5 in this directory.

cd $TRAIN_WSJ0

# Copy our lists of monophones over from TIMIT directory
cp $TRAIN_TIMIT/monophones0 .
cp $TRAIN_TIMIT/monophones1 .

# Cleanup old files and directories
rm -f -r hmm6 hmm7 hmm8 hmm9
mkdir hmm6 hmm7 hmm8 hmm9
rm -f hmm6.log hmm7.log hmm8.log hmm9.log

# Now do three rounds of Baum-Welch reesimtation of the monophone models
# using the phone-level transcriptions.
cd $WSJ0_DIR

if [[ $1 != "flat" ]]
then

# Copy over the TIMIT monophones to the same directory that a 
# flat-start would use.
mkdir -p $TRAIN_WSJ0/hmm5
cp -f $TRAIN_TIMIT/hmm8/* $TRAIN_WSJ0/hmm5
fi

# We'll create a new variance floor macro that reflects 1% of the 
# global variance over our WSJ0 + WSJ1 training data.

# First convert to text format so we can edit the macro file
mkdir -p $TRAIN_WSJ0/hmm5_text
HHEd -H $TRAIN_WSJ0/hmm5/hmmdefs -H $TRAIN_WSJ0/hmm5/macros -M $TRAIN_WSJ0/hmm5_text /dev/null $TRAIN_WSJ0/monophones1

# HCompV parameters:
#  -C   Config file to load, gets us the TARGETKIND = MFCC_0_D_A_Z
#  -f   Create variance floor equal to value times global variance
#  -m   Update the means as well (not needed?)
#  -S   File listing all the feature vector files
#  -M   Where to store the output files
#  -I   MLF containg phone labels of feature vector files
HCompV -A -T 1 -C $TRAIN_COMMON/config -f 0.01 -m -S train.scp -M $TRAIN_WSJ0/hmm5_text -I $TRAIN_WSJ0/aligned2.mlf $TRAIN_TIMIT/proto >$TRAIN_WSJ0/hcompv.log
cp $TRAIN_TIMIT/macros $TRAIN_WSJ0/hmm5_text/macros
cat $TRAIN_WSJ0/hmm5_text/vFloors >> $TRAIN_WSJ0/hmm5_text/macros

$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ0 hmm5_text hmm6 monophones1 aligned2.mlf 3
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ0 hmm6 hmm7 monophones1 aligned2.mlf 3
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ0 hmm7 hmm8 monophones1 aligned2.mlf 3

# Do an extra round just so we end up with hmm9 and synched with the tutorial
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ0 hmm8 hmm9 monophones1 aligned2.mlf 3

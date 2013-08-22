# If previous monophone models aren't available (say from TIMIT), then
# this script can be used to flat start the models using the word 
# level MLF of WSJ0.

rm -f -r hmm0 hhed_flat.log hcompv_flat.log hmm1 hmm2 hmm3 hmm4 hmm5
mkdir hmm0 hmm1 hmm2 hmm3 hmm4 hmm5
cp $TRAIN_TIMIT/monophones0 .
cp $TRAIN_TIMIT/monophones1 .

# First convert the word level MLF into a phone MLF
HLEd -A -T 1 -l '*' -d $TRAIN_TIMIT/cmu6 -i phones0.mlf mkphones0.led words.mlf >hhed_flat.log

cd $WSJ0_DIR

# Compute the global mean and variance and set all Gaussians in the given
# HMM to have the same mean and variance

# HCompV parameters:
#  -C   Config file to load, gets us the TARGETKIND = MFCC_0_D_A_Z
#  -f   Create variance floor equal to value times global variance
#  -m   Update the means as well
#  -S   File listing all the feature vector files
#  -M   Where to store the output files
HCompV -A -T 1 -C $TRAIN_COMMON/config -f 0.01 -m -S train.scp -M $TRAIN_WSJ0/hmm0 $TRAIN_TIMIT/proto >hcompv_flat.log

# Create the master model definition and macros file
cd $TRAIN_WSJ0
cp $TRAIN_TIMIT/macros hmm0
cat hmm0/vFloors >> hmm0/macros
perl $TRAIN_SCRIPTS/CreateHMMDefs.pl hmm0/proto monophones0 >hmm0/hmmdefs

cd $WSJ0_DIR

# Okay now to train up the models
#
# HERest parameters:
#  -d    Where to look for the monophone defintions in
#  -C    Config file to load
#  -I    MLF containing the phone-level transcriptions
#  -t    Set pruning threshold (3.2.1)
#  -S    List of feature vector files
#  -H    Load this HMM macro definition file
#  -M    Store output in this directory
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ0 hmm0 hmm1 monophones0 phones0.mlf 3 text
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ0 hmm1 hmm2 monophones0 phones0.mlf 3 text
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ0 hmm2 hmm3 monophones0 phones0.mlf 3 text

cd $TRAIN_WSJ0

# Finally we'll fix the silence model and add in our short pause sp 
# See HTKBook 3.2.2.
perl $TRAIN_SCRIPTS/DuplicateSilence.pl hmm3/hmmdefs >hmm4/hmmdefs
cp hmm3/macros hmm4/macros

HHEd -A -T 1 -H hmm4/macros -H hmm4/hmmdefs -M hmm5 $TRAIN_TIMIT/sil.hed monophones1 >hhed_flat_sil.log

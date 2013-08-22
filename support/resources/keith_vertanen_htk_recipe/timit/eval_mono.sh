# Evaluate the TIMIT monophone models by testing them on their
# own training data (unfair but tests for fundamental brokenness). 
# Uses a simple word loop grammar where each word is a monophone.
# We use monophones0 since sp is allowed in the grammar since 
# it has a transition with no output.

rm -f hbuild.log hresults.log hvite.log

# Create a dictionary where each word is a monophone 
perl $TRAIN_SCRIPTS/DuplicateLine.pl monophones0 >dict_monophones0

# Build the word network
HBuild -A -T 1 monophones0 wdnet_monophones0 >hbuild.log

# Recognize the data on the final monophone models
rm -f hresults.log
cd $TIMIT_DIR

# HVite parameters:
#  -H    HMM macro definition files to load
#  -S    List of feature vector files to recognize
#  -i    Where to output the recognition MLF file
#  -w    Word network to you as language model
#  -p    Insertion penalty
#  -s    Language model scale factor
HVite -A -T 1 -H $TRAIN_TIMIT/hmm8/macros -H $TRAIN_TIMIT/hmm8/hmmdefs -S $TIMIT_DIR/train.scp -i $TRAIN_TIMIT/recout.mlf -w $TRAIN_TIMIT/wdnet_monophones0 -p -1.0 -s 4.0 $TRAIN_TIMIT/dict_monophones0 $TRAIN_TIMIT/monophones0 >$TRAIN_TIMIT/hvite.log

# Now lets see how we did!
cd $TRAIN_TIMIT
HResults -A -T 1 -I phone.mlf monophones1 recout.mlf >hresults.log


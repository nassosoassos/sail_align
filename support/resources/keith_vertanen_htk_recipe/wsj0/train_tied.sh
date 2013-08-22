
# Train the word internal phonetic decision tree state tied models

cd $TRAIN_WSJ0

# Cleanup old files and create new directories for model files
rm -f -r hmm14 hmm15 hmm16 hmm17
mkdir hmm14 hmm15 hmm16 hmm17
rm -f hmm14.log hmm15.log hmm16.log hmm17.log

cd $WSJ0_DIR

# HERest parameters:
#  -d    Where to look for the monophone defintions in
#  -C    Config file to load
#  -I    MLF containing the phone-level transcriptions
#  -t    Set pruning threshold (3.2.1)
#  -S    List of feature vector files
#  -H    Load this HMM macro definition file
#  -M    Store output in this directory
#  -m    Sets the minimum number of examples for training, by setting 
#        to 0 we stop suprious warnings about no examples for the 
#        sythensized triphones
#
# As per the CSTIT notes, do four rounds of reestimation (more than
# in the tutorial).

#HERest -B -A -T 1 -m 0 -C $TRAIN_COMMON/config -I $TRAIN_WSJ0/wintri.mlf -t 250.0 150.0 1000.0 -S train.scp -H $TRAIN_WSJ0/hmm13/macros -H $TRAIN_WSJ0/hmm13/hmmdefs -M $TRAIN_WSJ0/hmm14 $TRAIN_WSJ0/tiedlist >$TRAIN_WSJ0/hmm14.log
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ0 hmm13 hmm14 tiedlist wintri.mlf 0

#HERest -B -A -T 1 -m 0 -C $TRAIN_COMMON/config -I $TRAIN_WSJ0/wintri.mlf -t 250.0 150.0 1000.0 -S train.scp -H $TRAIN_WSJ0/hmm14/macros -H $TRAIN_WSJ0/hmm14/hmmdefs -M $TRAIN_WSJ0/hmm15 $TRAIN_WSJ0/tiedlist >$TRAIN_WSJ0/hmm15.log
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ0 hmm14 hmm15 tiedlist wintri.mlf 0

#HERest -B -A -T 1 -m 0 -C $TRAIN_COMMON/config -I $TRAIN_WSJ0/wintri.mlf -t 250.0 150.0 1000.0 -S train.scp -H $TRAIN_WSJ0/hmm15/macros -H $TRAIN_WSJ0/hmm15/hmmdefs -M $TRAIN_WSJ0/hmm16 $TRAIN_WSJ0/tiedlist >$TRAIN_WSJ0/hmm16.log
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ0 hmm15 hmm16 tiedlist wintri.mlf 0

#HERest -B -A -T 1 -m 0 -C $TRAIN_COMMON/config -I $TRAIN_WSJ0/wintri.mlf -t 250.0 150.0 1000.0 -S train.scp -H $TRAIN_WSJ0/hmm16/macros -H $TRAIN_WSJ0/hmm16/hmmdefs -M $TRAIN_WSJ0/hmm17 $TRAIN_WSJ0/tiedlist >$TRAIN_WSJ0/hmm17.log
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ0 hmm16 hmm17 tiedlist wintri.mlf 0

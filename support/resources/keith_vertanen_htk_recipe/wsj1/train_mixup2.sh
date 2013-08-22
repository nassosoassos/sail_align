# Mixes up the non-sil states from 8->10->12

cd $TRAIN_WSJ1

# Prepare new directories for all our model files
rm -f -r hmm43 hmm44 hmm45 hmm46 hmm47 hmm48 hmm49 hmm50 hmm51 hmm52
rm -f hmm43.log hmm44.log hmm45.log hmm46.log hmm47.log hhed_mix10.log hmm48.log hmm49.log hmm50.log hmm51.log hmm52.log hhed_mix12.log
mkdir hmm43 hmm44 hmm45 hmm46 hmm47 hmm48 hmm49 hmm50 hmm51 hmm52

cd $WSJ_ROOT

# HERest parameters:
#  -d    Where to look for the monophone defintions in
#  -C    Config file to load
#  -I    MLF containing the phone-level transcriptions
#  -t    Set pruning threshold (3.2.1)
#  -S    List of feature vector files
#  -H    Load this HMM macro definition file
#  -M    Store output in this directory
#  -m    Minimum examples needed to update model

# As per the CSTIT notes, do four rounds of reestimation (more than
# in the tutorial).

#######################################################
# Mixup normal states from 8->10
HHEd -B -H $TRAIN_WSJ1/hmm42/macros -H $TRAIN_WSJ1/hmm42/hmmdefs -M $TRAIN_WSJ1/hmm43 $TRAIN_WSJ1/mix10.hed $TRAIN_WSJ1/tiedlist >$TRAIN_WSJ1/hhed_mix10.log

$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm43 hmm44 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm44 hmm45 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm45 hmm46 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm46 hmm47 tiedlist wintri.mlf 0

#######################################################
# Mixup normal states from 10->12
HHEd -B -H $TRAIN_WSJ1/hmm47/macros -H $TRAIN_WSJ1/hmm47/hmmdefs -M $TRAIN_WSJ1/hmm48 $TRAIN_WSJ1/mix12.hed $TRAIN_WSJ1/tiedlist >$TRAIN_WSJ1/hhed_mix12.log

$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm48 hmm49 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm49 hmm50 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm50 hmm51 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm51 hmm52 tiedlist wintri.mlf 0
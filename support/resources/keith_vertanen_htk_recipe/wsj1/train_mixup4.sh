# Mixes up:
#   non-sil states from 12->14->16
#   sil states from 24->28->32

cd $TRAIN_WSJ1

# Prepare new directories for all our model files
rm -f -r hmm63 hmm64 hmm65 hmm66 hmm67 hmm68 hmm69 hmm70 hmm71 hmm72

rm -f hmm63.log hmm64.log hmm65.log hmm66.log hmm67.log hhed_mix16_sil32.log hmm68.log hmm69.log hmm70.log hmm71.log hmm72.log hhed_mix14_sil28.log
mkdir hmm63 hmm64 hmm65 hmm66 hmm67 hmm68 hmm69 hmm70 hmm71 hmm72

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
# Mixup 12->14 and sil 24->28
HHEd -B -H $TRAIN_WSJ1/hmm62/macros -H $TRAIN_WSJ1/hmm62/hmmdefs -M $TRAIN_WSJ1/hmm63 $TRAIN_WSJ1/mix14_sil28.hed $TRAIN_WSJ1/tiedlist >$TRAIN_WSJ1/hhed_mix14_sil28.log

$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm63 hmm64 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm64 hmm65 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm65 hmm66 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm66 hmm67 tiedlist wintri.mlf 0

#######################################################
# Mixup 14->16 and sil 28->32
HHEd -B -H $TRAIN_WSJ1/hmm67/macros -H $TRAIN_WSJ1/hmm67/hmmdefs -M $TRAIN_WSJ1/hmm68 $TRAIN_WSJ1/mix16_sil32.hed $TRAIN_WSJ1/tiedlist >$TRAIN_WSJ1/hhed_mix16_sil32.log

$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm68 hmm69 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm69 hmm70 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm70 hmm71 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm71 hmm72 tiedlist wintri.mlf 0
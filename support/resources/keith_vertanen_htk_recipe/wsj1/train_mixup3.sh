# Mixes up the sil states from 16->20->24

cd $TRAIN_WSJ1

# Prepare new directories for all our model files
rm -f -r hmm53 hmm54 hmm55 hmm56 hmm57 hmm58 hmm59 hmm60 hmm61 hmm62

rm -f hmm53.log hmm54.log hmm55.log hmm56.log hmm57.log hhed_mix_sil20.log hmm58.log hmm59.log hmm60.log hmm61.log hmm62.log hhed_mix_sil24.log
mkdir hmm53 hmm54 hmm55 hmm56 hmm57 hmm58 hmm59 hmm60 hmm61 hmm62

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
# Mixup sil states from 16->20
HHEd -B -H $TRAIN_WSJ1/hmm52/macros -H $TRAIN_WSJ1/hmm52/hmmdefs -M $TRAIN_WSJ1/hmm53 $TRAIN_WSJ1/mix_sil20.hed $TRAIN_WSJ1/tiedlist >$TRAIN_WSJ1/hhed_mix_sil20.log

$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm53 hmm54 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm54 hmm55 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm55 hmm56 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm56 hmm57 tiedlist wintri.mlf 0

#######################################################
# Mixup sil states from 20->24
HHEd -B -H $TRAIN_WSJ1/hmm57/macros -H $TRAIN_WSJ1/hmm57/hmmdefs -M $TRAIN_WSJ1/hmm58 $TRAIN_WSJ1/mix_sil24.hed $TRAIN_WSJ1/tiedlist >$TRAIN_WSJ1/hhed_mix_sil24.log

$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm58 hmm59 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm59 hmm60 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm60 hmm61 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm61 hmm62 tiedlist wintri.mlf 0
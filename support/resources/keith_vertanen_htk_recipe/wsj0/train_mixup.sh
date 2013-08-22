
# Mixup the number of Gaussians per state, from 1 up to 8.
# We do this in 4 steps, with 4 rounds of reestimation 
# each time.  We mix to 8 to match paper "Large Vocabulary
# Continuous Speech Recognition Using HTK"
#
# Also per Phil Woodland's comment in the mailing list, we
# will let the sp/sil model have double the number of 
# Gaussians.
#
# This version does sil mixup to 2 first, then from 2->4->6->8 for
# normal and double for sil.

cd $TRAIN_WSJ0

# Prepare new directories for all our model files
rm -f -r hmm18 hmm19 hmm20 hmm21 hmm22 hmm23 hmm24 hmm25 hmm26 hmm27 hmm28 hmm29 hmm30 hmm31 hmm32 hmm33 hmm34 hmm35 hmm36 hmm37 hmm38 hmm39 hmm40 hmm41 hmm42
mkdir hmm18 hmm19 hmm20 hmm21 hmm22 hmm23 hmm24 hmm25 hmm26 hmm27 hmm28 hmm29 hmm30 hmm31 hmm32 hmm33 hmm34 hmm35 hmm36 hmm37 hmm38 hmm39 hmm40 hmm41 hmm42
rm -f hmm18.log hmm19.log hmm20.log hmm21.log hmm22.log hmm23.log hmm24.log hmm25.log hmm26.log hmm27.log hmm28.log hmm29.log hmm30.log hmm31.log hmm32.log hmm33.log hmm34.log hmm35.log hmm36.log hmm37.log hmm38.log hmm39.log hmm40.log hmm41.log hmm42.log hhed_mixup2.log hhed_mixup3.log hhed_mixup4.log hhed_mixup5.log hhed_mixup8.log hhed_mixup12.log hhed_mixup16.log

cd $WSJ1_DIR

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

cd $WSJ0_DIR

#######################################################
# Mixup sil from 1->2
HHEd -B -H $TRAIN_WSJ0/hmm17/macros -H $TRAIN_WSJ0/hmm17/hmmdefs -M $TRAIN_WSJ0/hmm18 $TRAIN_WSJ0/mix1.hed $TRAIN_WSJ0/tiedlist >$TRAIN_WSJ0/hhed_mix1.log

#HERest -B -m 0 -A -T 1 -C $TRAIN_COMMON/config -I $TRAIN_WSJ0/wintri.mlf -t 250.0 150.0 1000.0 -S train.scp -H $TRAIN_WSJ0/hmm18/macros -H $TRAIN_WSJ0/hmm18/hmmdefs -M $TRAIN_WSJ0/hmm19 $TRAIN_WSJ0/tiedlist >$TRAIN_WSJ0/hmm19.log

#HERest -B -m 0 -A -T 1 -C $TRAIN_COMMON/config -I $TRAIN_WSJ0/wintri.mlf -t 250.0 150.0 1000.0 -S train.scp -H $TRAIN_WSJ0/hmm19/macros -H $TRAIN_WSJ0/hmm19/hmmdefs -M $TRAIN_WSJ0/hmm20 $TRAIN_WSJ0/tiedlist >$TRAIN_WSJ0/hmm20.log

#HERest -B -m 0 -A -T 1 -C $TRAIN_COMMON/config -I $TRAIN_WSJ0/wintri.mlf -t 250.0 150.0 1000.0 -S train.scp -H $TRAIN_WSJ0/hmm20/macros -H $TRAIN_WSJ0/hmm20/hmmdefs -M $TRAIN_WSJ0/hmm21 $TRAIN_WSJ0/tiedlist >$TRAIN_WSJ0/hmm21.log

#HERest -B -m 0 -A -T 1 -C $TRAIN_COMMON/config -I $TRAIN_WSJ0/wintri.mlf -t 250.0 150.0 1000.0 -S train.scp -H $TRAIN_WSJ0/hmm21/macros -H $TRAIN_WSJ0/hmm21/hmmdefs -M $TRAIN_WSJ0/hmm22 $TRAIN_WSJ0/tiedlist >$TRAIN_WSJ0/hmm22.log

$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ0 hmm18 hmm19 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ0 hmm19 hmm20 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ0 hmm20 hmm21 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ0 hmm21 hmm22 tiedlist wintri.mlf 0

#######################################################
# Mixup 1->2, sil 2->4
HHEd -B -H $TRAIN_WSJ0/hmm22/macros -H $TRAIN_WSJ0/hmm22/hmmdefs -M $TRAIN_WSJ0/hmm23 $TRAIN_WSJ0/mix2.hed $TRAIN_WSJ0/tiedlist >$TRAIN_WSJ0/hhed_mix2.log

#HERest -B -m 0 -A -T 1 -C $TRAIN_COMMON/config -I $TRAIN_WSJ0/wintri.mlf -t 250.0 150.0 1000.0 -S train.scp -H $TRAIN_WSJ0/hmm23/macros -H $TRAIN_WSJ0/hmm23/hmmdefs -M $TRAIN_WSJ0/hmm24 $TRAIN_WSJ0/tiedlist >$TRAIN_WSJ0/hmm24.log

#HERest -B -m 0 -A -T 1 -C $TRAIN_COMMON/config -I $TRAIN_WSJ0/wintri.mlf -t 250.0 150.0 1000.0 -S train.scp -H $TRAIN_WSJ0/hmm24/macros -H $TRAIN_WSJ0/hmm24/hmmdefs -M $TRAIN_WSJ0/hmm25 $TRAIN_WSJ0/tiedlist >$TRAIN_WSJ0/hmm25.log

#HERest -B -m 0 -A -T 1 -C $TRAIN_COMMON/config -I $TRAIN_WSJ0/wintri.mlf -t 250.0 150.0 1000.0 -S train.scp -H $TRAIN_WSJ0/hmm25/macros -H $TRAIN_WSJ0/hmm25/hmmdefs -M $TRAIN_WSJ0/hmm26 $TRAIN_WSJ0/tiedlist >$TRAIN_WSJ0/hmm26.log

#HERest -B -m 0 -A -T 1 -C $TRAIN_COMMON/config -I $TRAIN_WSJ0/wintri.mlf -t 250.0 150.0 1000.0 -S train.scp -H $TRAIN_WSJ0/hmm26/macros -H $TRAIN_WSJ0/hmm26/hmmdefs -M $TRAIN_WSJ0/hmm27 $TRAIN_WSJ0/tiedlist >$TRAIN_WSJ0/hmm27.log

$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ0 hmm23 hmm24 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ0 hmm24 hmm25 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ0 hmm25 hmm26 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ0 hmm26 hmm27 tiedlist wintri.mlf 0

#######################################################
# Mixup 2->4, sil from 4->8
HHEd -B -H $TRAIN_WSJ0/hmm27/macros -H $TRAIN_WSJ0/hmm27/hmmdefs -M $TRAIN_WSJ0/hmm28 $TRAIN_WSJ0/mix4.hed $TRAIN_WSJ0/tiedlist >$TRAIN_WSJ0/hhed_mix4.log

#HERest -B -m 0 -A -T 1 -C $TRAIN_COMMON/config -I $TRAIN_WSJ0/wintri.mlf -t 250.0 150.0 1000.0 -S train.scp -H $TRAIN_WSJ0/hmm28/macros -H $TRAIN_WSJ0/hmm28/hmmdefs -M $TRAIN_WSJ0/hmm29 $TRAIN_WSJ0/tiedlist >$TRAIN_WSJ0/hmm29.log

#HERest -B -m 0 -A -T 1 -C $TRAIN_COMMON/config -I $TRAIN_WSJ0/wintri.mlf -t 250.0 150.0 1000.0 -S train.scp -H $TRAIN_WSJ0/hmm29/macros -H $TRAIN_WSJ0/hmm29/hmmdefs -M $TRAIN_WSJ0/hmm30 $TRAIN_WSJ0/tiedlist >$TRAIN_WSJ0/hmm30.log

#HERest -B -m 0 -A -T 1 -C $TRAIN_COMMON/config -I $TRAIN_WSJ0/wintri.mlf -t 250.0 150.0 1000.0 -S train.scp -H $TRAIN_WSJ0/hmm30/macros -H $TRAIN_WSJ0/hmm30/hmmdefs -M $TRAIN_WSJ0/hmm31 $TRAIN_WSJ0/tiedlist >$TRAIN_WSJ0/hmm31.log

#HERest -B -m 0 -A -T 1 -C $TRAIN_COMMON/config -I $TRAIN_WSJ0/wintri.mlf -t 250.0 150.0 1000.0 -S train.scp -H $TRAIN_WSJ0/hmm31/macros -H $TRAIN_WSJ0/hmm31/hmmdefs -M $TRAIN_WSJ0/hmm32 $TRAIN_WSJ0/tiedlist >$TRAIN_WSJ0/hmm32.log

$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ0 hmm28 hmm29 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ0 hmm29 hmm30 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ0 hmm30 hmm31 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ0 hmm31 hmm32 tiedlist wintri.mlf 0

#######################################################
# Mixup 4->6, sil 8->12
HHEd -B -H $TRAIN_WSJ0/hmm32/macros -H $TRAIN_WSJ0/hmm32/hmmdefs -M $TRAIN_WSJ0/hmm33 $TRAIN_WSJ0/mix6.hed $TRAIN_WSJ0/tiedlist >$TRAIN_WSJ0/hhed_mix6.log

#HERest -B -m 0 -A -T 1 -C $TRAIN_COMMON/config -I $TRAIN_WSJ0/wintri.mlf -t 250.0 150.0 1000.0 -S train.scp -H $TRAIN_WSJ0/hmm33/macros -H $TRAIN_WSJ0/hmm33/hmmdefs -M $TRAIN_WSJ0/hmm34 $TRAIN_WSJ0/tiedlist >$TRAIN_WSJ0/hmm34.log

#HERest -B -m 0 -A -T 1 -C $TRAIN_COMMON/config -I $TRAIN_WSJ0/wintri.mlf -t 250.0 150.0 1000.0 -S train.scp -H $TRAIN_WSJ0/hmm34/macros -H $TRAIN_WSJ0/hmm34/hmmdefs -M $TRAIN_WSJ0/hmm35 $TRAIN_WSJ0/tiedlist >$TRAIN_WSJ0/hmm35.log

#HERest -B -m 0 -A -T 1 -C $TRAIN_COMMON/config -I $TRAIN_WSJ0/wintri.mlf -t 250.0 150.0 1000.0 -S train.scp -H $TRAIN_WSJ0/hmm35/macros -H $TRAIN_WSJ0/hmm35/hmmdefs -M $TRAIN_WSJ0/hmm36 $TRAIN_WSJ0/tiedlist >$TRAIN_WSJ0/hmm36.log

#HERest -B -m 0 -A -T 1 -C $TRAIN_COMMON/config -I $TRAIN_WSJ0/wintri.mlf -t 250.0 150.0 1000.0 -S train.scp -H $TRAIN_WSJ0/hmm36/macros -H $TRAIN_WSJ0/hmm36/hmmdefs -M $TRAIN_WSJ0/hmm37 $TRAIN_WSJ0/tiedlist >$TRAIN_WSJ0/hmm37.log

$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ0 hmm33 hmm34 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ0 hmm34 hmm35 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ0 hmm35 hmm36 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ0 hmm36 hmm37 tiedlist wintri.mlf 0

#######################################################
# Mixup 6->8, sil 12->16
HHEd -B -H $TRAIN_WSJ0/hmm37/macros -H $TRAIN_WSJ0/hmm37/hmmdefs -M $TRAIN_WSJ0/hmm38 $TRAIN_WSJ0/mix8.hed $TRAIN_WSJ0/tiedlist >$TRAIN_WSJ0/hhed_mix8.log

#HERest -B -m 0 -A -T 1 -C $TRAIN_COMMON/config -I $TRAIN_WSJ0/wintri.mlf -t 250.0 150.0 1000.0 -S train.scp -H $TRAIN_WSJ0/hmm38/macros -H $TRAIN_WSJ0/hmm38/hmmdefs -M $TRAIN_WSJ0/hmm39 $TRAIN_WSJ0/tiedlist >$TRAIN_WSJ0/hmm39.log

#HERest -B -m 0 -A -T 1 -C $TRAIN_COMMON/config -I $TRAIN_WSJ0/wintri.mlf -t 250.0 150.0 1000.0 -S train.scp -H $TRAIN_WSJ0/hmm39/macros -H $TRAIN_WSJ0/hmm39/hmmdefs -M $TRAIN_WSJ0/hmm40 $TRAIN_WSJ0/tiedlist >$TRAIN_WSJ0/hmm40.log

#HERest -B -m 0 -A -T 1 -C $TRAIN_COMMON/config -I $TRAIN_WSJ0/wintri.mlf -t 250.0 150.0 1000.0 -S train.scp -H $TRAIN_WSJ0/hmm40/macros -H $TRAIN_WSJ0/hmm40/hmmdefs -M $TRAIN_WSJ0/hmm41 $TRAIN_WSJ0/tiedlist >$TRAIN_WSJ0/hmm41.log

#HERest -B -m 0 -A -T 1 -C $TRAIN_COMMON/config -I $TRAIN_WSJ0/wintri.mlf -t 250.0 150.0 1000.0 -S train.scp -H $TRAIN_WSJ0/hmm41/macros -H $TRAIN_WSJ0/hmm41/hmmdefs -M $TRAIN_WSJ0/hmm42 $TRAIN_WSJ0/tiedlist >$TRAIN_WSJ0/hmm42.log

$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ0 hmm38 hmm39 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ0 hmm39 hmm40 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ0 hmm40 hmm41 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ0 hmm41 hmm42 tiedlist wintri.mlf 0

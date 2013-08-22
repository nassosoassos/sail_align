
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

cd $TRAIN_WSJ1

# Prepare new directories for all our model files
rm -f -r hmm18 hmm19 hmm20 hmm21 hmm22 hmm23 hmm24 hmm25 hmm26 hmm27 hmm28 hmm29 hmm30 hmm31 hmm32 hmm33 hmm34 hmm35 hmm36 hmm37 hmm38 hmm39 hmm40 hmm41 hmm42
mkdir hmm18 hmm19 hmm20 hmm21 hmm22 hmm23 hmm24 hmm25 hmm26 hmm27 hmm28 hmm29 hmm30 hmm31 hmm32 hmm33 hmm34 hmm35 hmm36 hmm37 hmm38 hmm39 hmm40 hmm41 hmm42
rm -f hmm18.log hmm19.log hmm20.log hmm21.log hmm22.log hmm23.log hmm24.log hmm25.log hmm26.log hmm27.log hmm28.log hmm29.log hmm30.log hmm31.log hmm32.log hmm33.log hmm34.log hmm35.log hmm36.log hmm37.log hmm38.log hmm39.log hmm40.log hmm41.log hmm42.log hhed_mixup2.log hhed_mixup3.log hhed_mixup4.log hhed_mixup5.log hhed_mixup8.log hhed_mixup12.log hhed_mixup16.log stats_hmm*

cd $WSJ_ROOT

#######################################################
# Mixup sil from 1->2
HHEd -B -H $TRAIN_WSJ1/hmm17/macros -H $TRAIN_WSJ1/hmm17/hmmdefs -M $TRAIN_WSJ1/hmm18 $TRAIN_WSJ0/mix1.hed $TRAIN_WSJ1/tiedlist >$TRAIN_WSJ1/hhed_mix1.log

$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm18 hmm19 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm19 hmm20 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm20 hmm21 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm21 hmm22 tiedlist wintri.mlf 0

#######################################################
# Mixup 1->2, sil 2->4
HHEd -B -H $TRAIN_WSJ1/hmm22/macros -H $TRAIN_WSJ1/hmm22/hmmdefs -M $TRAIN_WSJ1/hmm23 $TRAIN_WSJ0/mix2.hed $TRAIN_WSJ1/tiedlist >$TRAIN_WSJ1/hhed_mix2.log

$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm23 hmm24 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm24 hmm25 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm25 hmm26 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm26 hmm27 tiedlist wintri.mlf 0

#######################################################
# Mixup 2->4, sil from 4->8
HHEd -B -H $TRAIN_WSJ1/hmm27/macros -H $TRAIN_WSJ1/hmm27/hmmdefs -M $TRAIN_WSJ1/hmm28 $TRAIN_WSJ0/mix4.hed $TRAIN_WSJ1/tiedlist >$TRAIN_WSJ1/hhed_mix4.log

$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm28 hmm29 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm29 hmm30 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm30 hmm31 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm31 hmm32 tiedlist wintri.mlf 0

#######################################################
# Mixup 4->6, sil 8->12
HHEd -B -H $TRAIN_WSJ1/hmm32/macros -H $TRAIN_WSJ1/hmm32/hmmdefs -M $TRAIN_WSJ1/hmm33 $TRAIN_WSJ0/mix6.hed $TRAIN_WSJ1/tiedlist >$TRAIN_WSJ1/hhed_mix6.log

$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm33 hmm34 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm34 hmm35 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm35 hmm36 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm36 hmm37 tiedlist wintri.mlf 0

#######################################################
# Mixup 6->8, sil 12->16
HHEd -B -H $TRAIN_WSJ1/hmm37/macros -H $TRAIN_WSJ1/hmm37/hmmdefs -M $TRAIN_WSJ1/hmm38 $TRAIN_WSJ0/mix8.hed $TRAIN_WSJ1/tiedlist >$TRAIN_WSJ1/hhed_mix8.log

$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm38 hmm39 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm39 hmm40 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm40 hmm41 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm41 hmm42 tiedlist wintri.mlf 0


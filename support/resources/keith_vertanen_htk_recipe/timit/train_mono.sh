# Init the HMM models based on TIMIT phonetic transcriptions.
# Then train up the monophone models.

cd $TIMIT_DIR
find -iname *.mfc >train.scp

cd $TRAIN_TIMIT
# Create monophones0 from monophones1, eliminating the sp model
grep -v "^sp" monophones1 > monophones0

# Clean out any old directories or log files
rm -f -r phone0 phone1 hmm1 hmm2 hmm3 hmm4 hmm5 hmm6 hmm7 hmm8
mkdir phone0 phone1 hmm1 hmm2 hmm3 hmm4 hmm5 hmm6 hmm7 hmm8
rm -f hrest.log hinit.log hmm1.log hmm2.log hmm3.log hmm4.log hmm5.log hmm6.log hmm7.log hmm8.log hhed_sil.log

# We need to run HInit for each phone in the monophones0 file
cd $TIMIT_DIR
perl $TRAIN_SCRIPTS/ProcessNums.pl $TRAIN_TIMIT/monophones0 $TRAIN_TIMIT/template_hinit
cd $TRAIN_TIMIT

# Train using HRest
cd $TIMIT_DIR
perl $TRAIN_SCRIPTS/ProcessNums.pl $TRAIN_TIMIT/monophones0 $TRAIN_TIMIT/template_hrest
cd $TRAIN_TIMIT

# At this point, we should have decent set of monophones stored in
# $TRAIN_TIMIT/phone1/hmmdefs, but we'll carry on and do BW
# reestimation using the phone labeled data.

# Figure out the global variance, we do this so we can have a floor
# on the variances in further re-estimation steps.
cd $TIMIT_DIR

# HCompV parameters:
#  -C   Config file to load, gets us the TARGETKIND = MFCC_0_D_A_Z
#  -f   Create variance floor equal to value times global variance
#  -m   Update the means as well (not needed?)
#  -S   File listing all the feature vector files
#  -M   Where to store the output files
#  -I   MLF containg phone labels of feature vector files
HCompV -A -T 1 -C $TRAIN_COMMON/config -f 0.01 -m -S $TIMIT_DIR/train.scp -M $TRAIN_TIMIT/phone1 -I $TRAIN_TIMIT/phone.mlf $TRAIN_TIMIT/proto >$TRAIN_TIMIT/hcompv.log
cd $TRAIN_TIMIT
cp macros phone1
cat phone1/vFloors >> phone1/macros

# We don't actually want to use the global means since we went through
# the trouble of not flat starting.
rm -f ./phone1/proto

# Now do three rounds of Baum-Welch reesimtation of the monophone models
# using the phone-level transcriptions.
cd $TIMIT_DIR

# HERest parameters:
#  -d    Where to look for the monophone defintions in
#  -C    Config file to load
#  -I    MLF containing the phone-level transcriptions
#  -t    Set pruning threshold (3.2.1)
#  -S    List of feature vector files
#  -H    Load this HMM macro definition file
#  -M    Store output in this directory
HERest -A -T 1 -d $TRAIN_TIMIT/phone1 -C $TRAIN_COMMON/config -I $TRAIN_TIMIT/phone.mlf -t 250.0 150.0 1000.0 -S $TIMIT_DIR/train.scp -H $TRAIN_TIMIT/phone1/macros -H $TRAIN_TIMIT/phone1/hmmdefs -M $TRAIN_TIMIT/hmm1 $TRAIN_TIMIT/monophones0 >$TRAIN_TIMIT/hmm1.log

#HERest -A -T 1 -C $TRAIN_COMMON/config -I $TRAIN_TIMIT/phone.mlf -t 250.0 150.0 1000.0 -S $TIMIT_DIR/train.scp -H $TRAIN_TIMIT/hmm1/macros -H $TRAIN_TIMIT/hmm1/hmmdefs -M $TRAIN_TIMIT/hmm2 $TRAIN_TIMIT/monophones0 >$TRAIN_TIMIT/hmm2.log
$TRAIN_TIMIT/train_iter.sh $TRAIN_TIMIT hmm1 hmm2 monophones0 phone.mlf 3

#HERest -A -T 1 -C $TRAIN_COMMON/config -I $TRAIN_TIMIT/phone.mlf -t 250.0 150.0 1000.0 -S $TIMIT_DIR/train.scp -H $TRAIN_TIMIT/hmm2/macros -H $TRAIN_TIMIT/hmm2/hmmdefs -M $TRAIN_TIMIT/hmm3 $TRAIN_TIMIT/monophones0 >$TRAIN_TIMIT/hmm3.log
$TRAIN_TIMIT/train_iter.sh $TRAIN_TIMIT hmm2 hmm3 monophones0 phone.mlf 3 text

cd $TRAIN_TIMIT

# We'll fix the silence model and add in our short pause sp.
# This form of silence is different from the tutorial as sp will
# have three states, all tied to sil.  sp will allow transition
# without any output and both will have transitions from 2 to 4.
perl $TRAIN_SCRIPTS/DuplicateSilence.pl hmm3/hmmdefs >hmm4/hmmdefs
cp hmm3/macros hmm4/macros

HHEd -A -T 1 -H hmm4/macros -H hmm4/hmmdefs -M hmm5 sil.hed monophones1 >hhed_sil.log

cd $TIMIT_DIR

# Now do more training of the new sp model using an MLF that has
# the sp between words and sil just before and after sentences.
#HERest -A -T 1 -C $TRAIN_COMMON/config -I $TRAIN_TIMIT/phone_sp.mlf -t 250.0 150.0 1000.0 -S $TIMIT_DIR/train.scp -H $TRAIN_TIMIT/hmm5/macros -H $TRAIN_TIMIT/hmm5/hmmdefs -M $TRAIN_TIMIT/hmm6 $TRAIN_TIMIT/monophones1 >$TRAIN_TIMIT/hmm6.log
$TRAIN_TIMIT/train_iter.sh $TRAIN_TIMIT hmm5 hmm6 monophones1 phone_sp.mlf 3

#HERest -A -T 1 -C $TRAIN_COMMON/config -I $TRAIN_TIMIT/phone_sp.mlf -t 250.0 150.0 1000.0 -S $TIMIT_DIR/train.scp -H $TRAIN_TIMIT/hmm6/macros -H $TRAIN_TIMIT/hmm6/hmmdefs -M $TRAIN_TIMIT/hmm7 $TRAIN_TIMIT/monophones1 >$TRAIN_TIMIT/hmm7.log
$TRAIN_TIMIT/train_iter.sh $TRAIN_TIMIT hmm6 hmm7 monophones1 phone_sp.mlf 3

#HERest -A -T 1 -C $TRAIN_COMMON/config -I $TRAIN_TIMIT/phone_sp.mlf -t 250.0 150.0 1000.0 -S $TIMIT_DIR/train.scp -H $TRAIN_TIMIT/hmm7/macros -H $TRAIN_TIMIT/hmm7/hmmdefs -M $TRAIN_TIMIT/hmm8 $TRAIN_TIMIT/monophones1 >$TRAIN_TIMIT/hmm8.log
$TRAIN_TIMIT/train_iter.sh $TRAIN_TIMIT hmm7 hmm8 monophones1 phone_sp.mlf 3
 
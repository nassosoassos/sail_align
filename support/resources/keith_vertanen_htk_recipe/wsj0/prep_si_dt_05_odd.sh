# Code the audio for a "subset of the WSJ1 5K development test 
# formed by deleting sentences with out-of-vocabulary (OOV)
# words and choosing every other sentence".
#
# 248 sentences from 10 speakers
#

cd $WSJ1_DIR

# Create a file with the filename with wc1, wav and mfc extensions on it
# Only get the files in the training directory.
find -iname '*.wv1' | grep -i si_dt_05 >si_dt_05_wv1_files.txt

# Create the list file we need to send to HCopy to convert .wv1 files to .mfc
perl $TRAIN_SCRIPTS/CreateMFCList.pl $WSJ1_DIR/si_dt_05_wv1_files.txt wv1 mfc >$WSJ1_DIR/si_dt_05_wv1_mfc.scp

HCopy -T 1 -C $TRAIN_COMMON/configwav -C $TRAIN_COMMON/config -C $TRAIN_COMMON/config_wsj -S si_dt_05_wv1_mfc.scp >$TRAIN_WSJ0/hcopy_si_dt_05.log

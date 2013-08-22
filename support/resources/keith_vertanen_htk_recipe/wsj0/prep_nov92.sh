# This encodes the Nov 1992 ARPA WSJ evaluation,
# 330 sentences from 8 speakers.

cd $WSJ0_DIR

# Create a file with the filename with wc1, wav and mfc extensions on it
# Only get the files in the training directory.
find -iname '*.wv1' | grep -i SI_ET_05 >nov92_wv1_files.txt

# Create the list file we need to send to HCopy to convert .wv1 files to .mfc
perl $TRAIN_SCRIPTS/CreateMFCList.pl $WSJ0_DIR/nov92_wv1_files.txt WV1 mfc >$WSJ0_DIR/nov92_wv1_mfc.scp

HCopy -T 1 -C $TRAIN_COMMON/configwav -C $TRAIN_COMMON/config -C $TRAIN_COMMON/config_wsj -S nov92_wv1_mfc.scp >$TRAIN_WSJ0/hcopy_nov92.log

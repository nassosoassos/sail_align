
cd $WSJ0_DIR

# The WSJ0 data is stored compressed using shorten method.  Using w_decode
# or shorten as the filter to HTK didn't work, but sph2pipe does work but
# if we leave it in sphere format the header is wrong and lists it as 
# still being shortened.  So we'll have sph2pipe convert to WAVE 16-bit
# linear PCM for HCopy to work with.

# Clean up any old files
rm -f wv1_files.txt wv1_mfc.scp $TRAIN_WSJ0/hcopy.log

# Create a file with the filename with wc1, wav and mfc extensions on it
# Only get the files in the training directory.
find -iname '*.WV1' | grep -i SI_TR_S >wv1_files.txt

# Create the list file we need to send to HCopy to convert .wv1 files to .mfc
perl $TRAIN_SCRIPTS/CreateMFCList.pl $WSJ0_DIR/wv1_files.txt WV1 mfc >$WSJ0_DIR/wv1_mfc.scp

HCopy -A -T 1 -C $TRAIN_COMMON/configwav -C $TRAIN_COMMON/config -C $TRAIN_COMMON/config_wsj -S wv1_mfc.scp >$TRAIN_WSJ0/hcopy.log

# Prepare the files needed to train on the TIMIT corpus
# This does the front-end processing on all the speech
# wave form files.
#
# This version only uses the CMU dictionary and uses 
# both the training and test files from TIMIT.
#
# We are using the CMU set of 39 phonemes 

# First we need to generate a file that contains all the 
# filenames of all the TIMIT format phone level
# transcriptions.
cd $TIMIT_DIR
find -iname S*.PHN >phone_files.txt

# Create new phone labels that also have sp between words.  We'll
# use these transcriptions once we add in the sp model after the
# intial training is complete.
perl $TRAIN_SCRIPTS/AddSpToTimit.pl $TIMIT_DIR/phone_files.txt PHN_SP
find -iname S*.PHN_SP >phone_sp_files.txt

# Convert all the TIMIT phone labels to our smaller set and
# put them into a big MLF file.
HLEd -A -T 1 -D -n $TRAIN_TIMIT/tlist -i $TRAIN_TIMIT/phone.mlf -G TIMIT -S phone_files.txt $TRAIN_TIMIT/timit.led >$TRAIN_TIMIT/hhed_convert.log

# Same thing but for the version that has sp in it
HLEd -A -T 1 -D -n $TRAIN_TIMIT/tlist -i $TRAIN_TIMIT/temp.mlf -G TIMIT -S phone_sp_files.txt $TRAIN_TIMIT/timit.led >$TRAIN_TIMIT/hhed_convert_sp.log

# We could get several sp's in a row in the above due to sp being added
# between words and deletion of epi symbol in TIMIT transcription.
# We'll merge them back into a single sp phone.
HLEd -A -T 1 -i $TRAIN_TIMIT/phone_sp.mlf $TRAIN_TIMIT/merge_sp.led $TRAIN_TIMIT/temp.mlf >$TRAIN_TIMIT/hled_sp.log
rm -f $TRAIN_TIMIT/temp.mlf

# Process the WAV audio into MFC feature files
find -iname S*.WAV >wav_files.txt
perl $TRAIN_SCRIPTS/CreateMFCList.pl wav_files.txt > wav_mfc.scp

# Note the config files specify BYTEORDER of VAX, the WAV files
# appear to be little endian when loaded into an audio editor. 
HCopy -A -T 1 -C $TRAIN_COMMON/confignist -C $TRAIN_COMMON/config -S wav_mfc.scp >$TRAIN_TIMIT/hcopy.log

cd $TRAIN_TIMIT

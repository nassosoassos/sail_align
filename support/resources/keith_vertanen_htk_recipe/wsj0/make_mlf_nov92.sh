# Make the Nov92 test MLF
#
# After we do prep.sh, we want to create a word level MLF for all 
# the files that were succefully converted to MFC files.

cd $WSJ0_DIR

# Cleanup old files
rm -f nov92_mfc_files.txt nov92_dot_files.txt $TRAIN_WSJ0/nov92_prune.log nov92_mfc_files_pruned.txt $TRAIN_WSJ0/nov92_missing.log $TRAIN_WSJ0/nov92_missing.txt $WSJ0_DIR/nov92_test.scp $TRAIN_WSJ0/nov92_words.mlf

# Create a file listing all the MFC files in the training directory
find -iname '*.mfc' | grep -i SI_ET_05 >nov92_mfc_files.txt

# Create a file that contains the filename of all the transcription files
find -iname '*.dot' | grep -i SI_ET_05 >nov92_dot_files.txt

# Make sure we only include files in the index file for this set
perl $TRAIN_SCRIPTS/PruneWithIndex.pl si_et_05 nov92_mfc_files.txt $WSJ0_DIR/WSJ0/DOC/INDICES/TEST/NVP/SI_ET_05.NDX nov92_mfc_files_pruned.txt >$TRAIN_WSJ0/nov92_prune.log

# Now create the MLF file using a script, we prune out anything that
# has words that aren't in our dictionary, producing a MLF with only
# these files and a cooresponding script file.
perl $TRAIN_SCRIPTS/CreateWSJMLF.pl $WSJ0_DIR/nov92_mfc_files_pruned.txt $WSJ0_DIR/nov92_dot_files.txt $TRAIN_TIMIT/cmu6 $TRAIN_WSJ0/nov92_words.mlf $WSJ0_DIR/nov92_test.scp $TRAIN_WSJ0/nov92_missing.txt >$TRAIN_WSJ0/nov92_missing.log

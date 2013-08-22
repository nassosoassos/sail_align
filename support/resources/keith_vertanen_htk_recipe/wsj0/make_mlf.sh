
# After we do prep.sh, we want to create a word level MLF for all 
# the files that were succefully converted to MFC files.

cd $WSJ0_DIR

# Cleanup old files
rm -f mfc_files.txt mfc_files_si84.txt $TRAIN_WSJ0/prune.log $TRAIN_WSJ0/missing.log $TRAIN_WSJ0/train_missing.txt train.scp $TRAIN_WSJ0/words.mlf dot_files.txt $TRAIN_WSJ0/hvite_align.log $TRAIN_WSJ0/hled_sp_sil.log

# Create a file listing all the MFC files in the training directory
find -iname '*.mfc' | grep -i SI_TR_S >mfc_files.txt

# There appears to be more in the SI_TR_S directory than is in the
# index file for the SI-84 training set.  We'll limit to just the
# SI-84 set for comparison purposes.
perl $TRAIN_SCRIPTS/PruneWithIndex.pl si_tr_s mfc_files.txt $WSJ0_DIR/WSJ0/DOC/INDICES/TRAIN/TR_S_WV1.NDX mfc_files_si84.txt >$TRAIN_WSJ0/prune.log

# Create a file that contains the filename of all the transcription files
find -iname '*.dot' | grep -i SI_TR_S >dot_files.txt

# Now create the MLF file using a script, we prune out anything that
# has words that aren't in our dictionary, producing a MLF with only
# these files and a cooresponding script file.
perl $TRAIN_SCRIPTS/CreateWSJMLF.pl $WSJ0_DIR/mfc_files_si84.txt $WSJ0_DIR/dot_files.txt $TRAIN_TIMIT/cmu6 $TRAIN_WSJ0/words.mlf train.scp 1 $TRAIN_WSJ0/train_missing.txt >$TRAIN_WSJ0/missing.log



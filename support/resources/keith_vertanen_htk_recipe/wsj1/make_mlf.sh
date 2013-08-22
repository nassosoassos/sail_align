
# After we do prep.sh, we want to create a word level MLF for all 
# the files that were succefully converted to MFC files.

cd $WSJ_ROOT

# Cleanup old files
rm -f mfc_files.txt mfc_files_si284.txt $TRAIN_WSJ1/prune.log $TRAIN_WSJ1/missing.log $TRAIN_WSJ1/train_missing.txt train.scp $TRAIN_WSJ1/words.mlf dot_files.txt $TRAIN_WSJ1/hvite_align.log $TRAIN_WSJ1/hled_sp_sil.log

# Create a file listing all the MFC files in the training directory
find -iname *.mfc | grep -i SI_TR_S >mfc_files.txt

# Create a composite index of SI-84 and SI-200
cat $WSJ0_DIR/WSJ0/DOC/INDICES/TRAIN/TR_S_WV1.NDX >$WSJ_ROOT/si284.ndx
cat $WSJ1_DIR/doc/indices/si_tr_s.ndx >>$WSJ_ROOT/si284.ndx

# There appears to be more in the SI_TR_S directory than is in the
# index file for the SI-84 and SI-200 training sets.  We'll limit to 
# just those sets for comparison purposes.
perl $TRAIN_SCRIPTS/PruneWithIndex.pl si_tr_s mfc_files.txt $WSJ_ROOT/si284.ndx mfc_files_si284.txt >$TRAIN_WSJ1/prune.log

# Create a file that contains the filename of all the transcription files
find -iname *.dot | grep -i SI_TR_S >dot_files.txt

# Now create the MLF file using a script, we prune out anything that
# has words that aren't in our dictionary, producing a MLF with only
# these files and a cooresponding script file.
perl $TRAIN_SCRIPTS/CreateWSJMLF.pl $WSJ_ROOT/mfc_files_si284.txt $WSJ_ROOT/dot_files.txt $TRAIN_TIMIT/cmu6 $TRAIN_WSJ1/words.mlf train.scp 1 0 $TRAIN_WSJ1/train_missing.txt 1 $TRAIN_WSJ1/trans_find_replace.txt >$TRAIN_WSJ1/missing.log



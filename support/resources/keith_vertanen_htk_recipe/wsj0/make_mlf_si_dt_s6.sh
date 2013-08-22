# Make the si_dt_s6 WSJ1 spoke 6 development test MLF file
#
# This requires that you have the WSJ1 corpus.  The following
# transcription files need to be manually fixed to remove
# extraneous symbols:
#   si_dt_s6/at_te/4o2/4o2c0308.dot (4o2c0308)
#   si_dt_s6/at_te/4o9/4o9c0300.dot (4o9c0306)

cd $WSJ1_DIR

# Cleanup old files
rm -f si_dt_s6_mfc_files.txt si_dt_s6_dot_files.txt $TRAIN_WSJ0/si_dt_s6_prune.log si_dt_s6_mfc_files_pruned.txt $TRAIN_WSJ0/si_dt_s6_missing.log $TRAIN_WSJ0/si_dt_s6_missing.txt $WSJ1_DIR/si_dt_s6_test.scp $TRAIN_WSJ0/si_dt_s6_words.mlf

# Create a file listing all the MFC files in the training directory
find -iname '*.mfc' | grep -i si_dt_s6 >si_dt_s6_mfc_files.txt

# Create a file that contains the filename of all the transcription files
find -iname '*.dot' | grep -i si_dt_s6 >si_dt_s6_dot_files.txt

# Make sure we only include files in the index file for this set
perl $TRAIN_SCRIPTS/PruneWithIndex.pl '' si_dt_s6_mfc_files.txt $TRAIN_COMMON/si_dt_s6.ndx si_dt_s6_mfc_files_pruned.txt >$TRAIN_WSJ0/si_dt_s6_prune.log

# Now create the MLF file using a script, we prune out anything that
# has words that aren't in our dictionary, producing a MLF with only
# these files and a cooresponding script file.
perl $TRAIN_SCRIPTS/CreateWSJMLF.pl $WSJ1_DIR/si_dt_s6_mfc_files_pruned.txt $WSJ1_DIR/si_dt_s6_dot_files.txt $TRAIN_TIMIT/cmu6 $TRAIN_WSJ0/si_dt_s6_words.mlf $WSJ1_DIR/si_dt_s6_test.scp $TRAIN_WSJ0/si_dt_s6_missing.txt >$TRAIN_WSJ0/si_dt_s6_missing.log

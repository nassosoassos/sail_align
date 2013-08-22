# Make the si_dt_05_odd WSJ1 test MLF file
#
# Has to manually correct errors in the following transcriptions:
#   si_dt_05/4ka/4kac0200.dot (4kac020m)
#   si_dt_05/4k6/4k6c0200.dot (4k6c0204)
#   si_dt_05/4k6/4k6c0200.dot (4k6c020m)
#   si_dt_05/4k3/4k3c0200.dot (4k3c021d)
#   si_dt_05/4k8/4k8c0200.dot (4k8c021f)
#   si_dt_05/4k0/4k0c0200.dot (4k0c0201)
#   si_dt_05/4k0/4k0c0200.dot (4k0c020j)
#   si_dt_05/4k0/4k0c0200.dot (4k0c020l)
#   si_dt_05/4k0/4k0c0200.dot (4k0c020r)
#   si_dt_05/4k0/4k0c0200.dot (4k0c020z)
#   si_dt_05/4k0/4k0c0200.dot (4k0c0213)
#   si_dt_05/4k0/4k0c0200.dot (4k0c0215)
#   si_dt_05/4k0/4k0c0200.dot (4k0c021b)

cd $WSJ1_DIR

# Cleanup old files
rm -f si_dt_05_odd_mfc_files.txt si_dt_05_odd_dot_files.txt $TRAIN_WSJ0/si_dt_05_odd_prune.log si_dt_05_odd_mfc_files_pruned.txt $TRAIN_WSJ0/si_dt_05_odd_missing.log $TRAIN_WSJ0/si_dt_05_odd_missing.txt $WSJ1_DIR/si_dt_05_odd_test.scp $TRAIN_WSJ0/si_dt_05_odd_words.mlf

# Create a file listing all the MFC files in the training directory
find -iname '*.mfc' | grep -i si_dt_05 >si_dt_05_odd_mfc_files.txt

# Create a file that contains the filename of all the transcription files
find -iname '*.dot' | grep -i si_dt_05 >si_dt_05_odd_dot_files.txt

# Make sure we only include files in the index file for this set
perl $TRAIN_SCRIPTS/PruneWithIndex.pl '' si_dt_05_odd_mfc_files.txt $TRAIN_COMMON/si_dt_05_odd.ndx si_dt_05_odd_mfc_files_pruned.txt >$TRAIN_WSJ0/si_dt_05_odd_prune.log

# Now create the MLF file using a script, we prune out anything that
# has words that aren't in our dictionary, producing a MLF with only
# these files and a cooresponding script file.
perl $TRAIN_SCRIPTS/CreateWSJMLF.pl $WSJ1_DIR/si_dt_05_odd_mfc_files_pruned.txt $WSJ1_DIR/si_dt_05_odd_dot_files.txt $TRAIN_TIMIT/cmu6 $TRAIN_WSJ0/si_dt_05_odd_words.mlf $WSJ1_DIR/si_dt_05_odd_test.scp $TRAIN_WSJ0/si_dt_05_odd_missing.txt >$TRAIN_WSJ0/si_dt_05_odd_missing.log

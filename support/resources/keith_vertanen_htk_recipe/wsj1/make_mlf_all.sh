
# After we do prep.sh, we want to create a word level MLF for all 
# the files that were succefully converted to MFC files.
#
# This version includes more than just SI-284:
#   1) Everything in si_tr_s directories in WSJ0 and WSJ1
#   2) Training and test TIMIT files
#   3) Long and very long WSJ0 training data
#   4) Long and journalist WSJ1 training data

cd $WSJ_ROOT

# Cleanup old files
rm -f mfc_files.txt $TRAIN_WSJ1/missing.log $TRAIN_WSJ1/train_missing.txt train.scp $TRAIN_WSJ1/words.mlf dot_files.txt $TRAIN_WSJ1/hvite_align.log $TRAIN_WSJ1/hled_sp_sil.log

# Create a file listing all the MFC files in the training directory
find -iname *.mfc | grep -i -E "SI_TR_S|SI_TR_J|SI_TR_JD|SD_TR_S|SD_TR_L|SI_TR_L|SD_TR_S" >mfc_files.txt

# Create a file that contains the filename of all the transcription files
find -iname *.dot | grep -i -E "SI_TR_S|SI_TR_J|SI_TR_JD|SD_TR_S|SD_TR_L|SI_TR_L|SD_TR_S" >dot_files.txt

# Now create the MLF file using a script, we prune out anything that
# has words that aren't in our dictionary, producing a MLF with only
# these files and a cooresponding script file.
perl $TRAIN_SCRIPTS/CreateWSJMLF.pl $WSJ_ROOT/mfc_files.txt $WSJ_ROOT/dot_files.txt $TRAIN_TIMIT/cmu6 $TRAIN_WSJ1/words.mlf train.scp 1 0 $TRAIN_WSJ1/train_missing.txt 1 $TRAIN_WSJ1/trans_find_replace.txt >$TRAIN_WSJ1/missing.log








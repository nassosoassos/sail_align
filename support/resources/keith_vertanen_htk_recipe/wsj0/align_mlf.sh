
# Aligns a new MLF based on the best monophone models.
#
# Parameters:
#  1 - "flat" if we are flat starting from monophone models living
#      in hmm5 in this directory.

cd $WSJ0_DIR

# Cleanup old files
rm -f $TRAIN_WSJ0/hvite_align.log $TRAIN_WSJ0/hled_sp_sil.log

# Do alignment using our best monophone models to create a phone-level MLF
# HVite parameters
#  -l       Path to use in the names in the output MLF
#  -o SWT   How to output labels, S remove scores, 
#           W do not include words, T do not include times
#  -b       Use this word as the sentence boundary during alignment
#  -C       Config files
#  -a       Perform alignment
#  -H       HMM macro definition files
#  -i       Output to this MLF file
#  -m       During recognition keep track of model boundaries
#  -t       Enable beam searching
#  -y       Extension for output label files
#  -I       Word level MLF file
#  -S       File contain the list of MFC files

if [[ $1 != "flat" ]]
then
HVite -A -T 1 -o SWT -b silence -C $TRAIN_COMMON/config -a -H $TRAIN_TIMIT/hmm8/macros -H $TRAIN_TIMIT/hmm8/hmmdefs -i $TRAIN_WSJ0/aligned.mlf -m -t 250.0 -I $TRAIN_WSJ0/words.mlf -S train.scp $TRAIN_TIMIT/cmu6spsil $TRAIN_TIMIT/monophones1 >$TRAIN_WSJ0/hvite_align.log
else
HVite -A -T 1 -o SWT -b silence -C $TRAIN_COMMON/config -a -H $TRAIN_WSJ0/hmm5/macros -H $TRAIN_WSJ0/hmm5/hmmdefs -i $TRAIN_WSJ0/aligned.mlf -m -t 250.0 -I $TRAIN_WSJ0/words.mlf -S train.scp $TRAIN_TIMIT/cmu6spsil $TRAIN_TIMIT/monophones1 >$TRAIN_WSJ0/hvite_align.log
fi

# We'll get a "sp sil" sequence at the end of each sentance.  Merge these
# into a single sil phone.  Also might get "sil sil", we'll merge anything
# combination of sp and sil into a single sil.
HLEd -A -T 1 -i $TRAIN_WSJ0/aligned2.mlf $TRAIN_WSJ0/merge_sp_sil.led $TRAIN_WSJ0/aligned.mlf >$TRAIN_WSJ0/hled_sp_sil.log

# Forced alignment might fail for a few files (why?), these will be missing
# from the MLF, so we need to prune these out of the script so we don't try 
# and train on them.
cp $WSJ0_DIR/train.scp $WSJ0_DIR/train_temp.scp
perl $TRAIN_SCRIPTS/RemovePrunedFiles.pl $TRAIN_WSJ0/aligned2.mlf $WSJ0_DIR/train_temp.scp >$WSJ0_DIR/train.scp
rm -f $WSJ0_DIR/train_temp.scp


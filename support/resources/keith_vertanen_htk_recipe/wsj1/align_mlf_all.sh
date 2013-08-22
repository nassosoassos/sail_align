
# Aligns a new MLF based on the best monophone models.
#
# Parameters:
#  1 - "flat" if we are flat starting from monophone models living
#      in hmm5 in this directory.
#
# This version also adds the TIMIT phone level MLF to the training
# aligned.mlf.  Since TIMIT is phoentically transcribed, we might
# as well use it rather than force aligning a word level MLF.

cd $WSJ_ROOT

# Cleanup old files
rm -f $TRAIN_WSJ1/hvite_align.log $TRAIN_WSJ1/hled_sp_sil.log

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
HVite -A -T 1 -o SWT -b silence -C $TRAIN_COMMON/config -a -H $TRAIN_TIMIT/hmm8/macros -H $TRAIN_TIMIT/hmm8/hmmdefs -i $TRAIN_WSJ1/aligned.mlf -m -t 250.0 150.0 2000.0 -I $TRAIN_WSJ1/words.mlf -S train.scp $TRAIN_TIMIT/cmu6spsil $TRAIN_TIMIT/monophones1 >$TRAIN_WSJ1/hvite_align.log
else
HVite -A -T 1 -o SWT -b silence -C $TRAIN_COMMON/config -a -H $TRAIN_WSJ1/hmm5/macros -H $TRAIN_WSJ0/hmm5/hmmdefs -i $TRAIN_WSJ1/aligned.mlf -m -t 250.0 150.0 2000.0 -I $TRAIN_WSJ1/words.mlf -S train.scp $TRAIN_TIMIT/cmu6spsil $TRAIN_TIMIT/monophones1 >$TRAIN_WSJ1/hvite_align.log
fi

# Add the TIMIT files, since we'll be using the phone level MLF, no 
# worries about OOV words or anything.
find -iname *.mfc | grep "TIMIT" >>train.scp

# Create a new phone level MLF with sp between words that is relative
# to our $WSJ_ROOT directory (the version in $TRAIN_TIMIT won't have
# the right path in the MLF).
find -iname S*.PHN_SP | grep "TIMIT" >phone_sp_files.txt
HLEd -A -T 1 -D -n $TRAIN_TIMIT/tlist -i $TRAIN_WSJ1/temp.mlf -G TIMIT -S phone_sp_files.txt $TRAIN_TIMIT/timit.led >$TRAIN_WSJ1/hhed_convert_sp.log
HLEd -A -T 1 -i $TRAIN_WSJ1/phone_sp.mlf $TRAIN_TIMIT/merge_sp.led $TRAIN_WSJ1/temp.mlf >$TRAIN_WSJ1/hled_sp.log
rm -f $TRAIN_WSJ1/temp.mlf

cat $TRAIN_WSJ1/phone_sp.mlf >>$TRAIN_WSJ1/aligned.mlf

# We'll get a "sp sil" sequence at the end of each sentance.  Merge these
# into a single sil phone.  Also might get "sil sil", we'll merge anything
# combination of sp and sil into a single sil.
HLEd -A -T 1 -i $TRAIN_WSJ1/aligned2.mlf $TRAIN_WSJ0/merge_sp_sil.led $TRAIN_WSJ1/aligned.mlf >$TRAIN_WSJ1/hled_sp_sil.log

# Forced alignment might fail for a few files, these will be missing
# from the MLF, so we need to prune these out of the script so we don't try 
# and train on them.
cp $WSJ_ROOT/train.scp $WSJ_ROOT/train_temp.scp
perl $TRAIN_SCRIPTS/RemovePrunedFiles.pl $TRAIN_WSJ1/aligned2.mlf $WSJ_ROOT/train_temp.scp >$WSJ_ROOT/train.scp

# temp!!!
#rm -f $WSJ_ROOT/train_temp.scp


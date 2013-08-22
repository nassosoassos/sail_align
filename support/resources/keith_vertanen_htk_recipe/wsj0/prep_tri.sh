# Convert our monophone models and MLFs into triphones.  If a parameter
# "cross" is passed to script, we'll build cross word triphones, otherwise
# they will be word internal.
#
# Parameters:
#  1 - "cross" for cross word triphones, anything else means word internal

cd $TRAIN_WSJ0

rm -f -r hled_make_tri.log mktri.hed hhed_clone_mono.log hmm10
mkdir hmm10

# Keep a copy of the monophones around in this directory for convience.
cp $TRAIN_TIMIT/monophones0 .
cp $TRAIN_TIMIT/monophones1 .

# Check to see if we are doing cross word triphones or not
if [[ $1 != "cross" ]]
then
# This converts the monophone MLF into a word internal triphone MLF
HLEd -A -T 1 -n triphones1 -i wintri.mlf mktri.led aligned2.mlf >hled_make_tri.log
else
# This version makes it into a cross word triphone MLF, the short pause
# phone will not block context across words.
HLEd -A -T 1 -n triphones1 -i wintri.mlf mktri_cross.led aligned2.mlf >hled_make_tri.log
fi

# Prepare the script that will be used to clone the monophones into
# their cooresponding triphones.  The script will also tie the transition
# matrices of all triphones with the same central phone together.
perl $TRAIN_SCRIPTS/MakeClonedMono.pl monophones1 triphones1 >mktri.hed

# Go go gadget clone monophones and tie transition matricies
HHEd -A -T 1 -B -H hmm9/macros -H hmm9/hmmdefs -M hmm10 mktri.hed monophones1 >hhed_clone_mono.log

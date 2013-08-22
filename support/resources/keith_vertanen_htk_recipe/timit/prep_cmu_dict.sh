# Given the CMU 0.6 pronounciation dictionary, convert it
# into the form we'll be using with the HTK.
#
# Also adds in extra words we discovered we needed for
# coverage in the WSJ1 training data
#

perl $TRAIN_SCRIPTS/FixCMUDict.pl $TRAIN_COMMON/c0.6 >cmu6temp

perl $TRAIN_SCRIPTS/MergeDict.pl cmu6temp wsj1_extra_dict >cmu6

rm -f cmu6temp

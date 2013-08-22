# Builds the word list and network we need for recognition 
# using the WSJ 5K standard language models

# We use the WSJ non-verbalized 5k closed word list. 

cd $TRAIN_WSJ0

# Create a dictionary with a sp short pause after each word, this is
# so when we do the phone alignment from the word level MLF, we get
# the sp phone inbetween the words.  This version duplicates each
# entry and uses a long pause sil after each word as well.  By doing
# this we get about a 0.5% abs increase on Nov92 test set.
perl $TRAIN_SCRIPTS/AddSp.pl $TRAIN_TIMIT/cmu6 1 >$TRAIN_TIMIT/cmu6sp

# We need a dictionary that has the word "silence" with the mapping to the sil phone
cat $TRAIN_TIMIT/cmu6sp >$TRAIN_TIMIT/cmu6temp
echo "silence sil" >>$TRAIN_TIMIT/cmu6temp
sort $TRAIN_TIMIT/cmu6temp >$TRAIN_TIMIT/cmu6spsil
rm -f $TRAIN_TIMIT/cmu6temp

# Get rid of the MIT comment lines from the top
grep -v "#" $WSJ0_DIR/WSJ0/LNG_MODL/VOCAB/WLIST5C.NVP >dict_temp

# We need sentence start and end symbols which match the WSJ
# standard language model and produce no output symbols.
echo "<s> [] sil" >dict_5k
echo "</s> [] sil" >> dict_5k

# Add pronunciations for each word
perl $TRAIN_SCRIPTS/WordsToDictionary.pl dict_temp $TRAIN_TIMIT/cmu6sp dict_temp2
cat dict_temp2 >>dict_5k
rm -f dict_temp dict_temp2

# Decompress the WSJ standard language model and build the word network
gunzip -d -c $WSJ0_DIR/WSJ0/LNG_MODL/BASE_LM/BCB05CNP.Z >lm_temp
HBuild -A -T 1 -C $TRAIN_COMMON/configrawmit -n lm_temp -u '<UNK>' -s '<s>' '</s>' -z dict_5k wdnet_bigram >hbuild.log
rm -f lm_temp



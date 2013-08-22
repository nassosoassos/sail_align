# Prepare things for the tied state triphones
#
# Parameters:
#   1 - RO value for clustering
#   2 - TB value for clustering
#   3 - "cross" if we are doing cross word triphones
#
# We need to create a list of all the triphone contexts we might
# see based on the whole dictionary (not just what we see in 
# the training data).

cd $TRAIN_WSJ1

rm -f -r hmm13 hhed_cluster.log fullist tree.hed
mkdir hmm13

# We have our own script which generate all possible monophone,
# left and right biphones, and triphones.  It will also add
# an entry for sp and sil
if [[ $3 != "cross" ]]
then
perl $TRAIN_SCRIPTS/CreateFullListWI.pl $TRAIN_TIMIT/cmu6 >fulllist
else
perl $TRAIN_SCRIPTS/CreateFullList.pl $TRAIN_TIMIT/monophones0 >fulllist
fi

# Now create the instructions for doing the decision tree clustering

# RO sets the outlier threshold and load the stats file from the
# last round of training
echo "RO $1 stats" >tree.hed

# Add the phoenetic questions used in the decision tree
echo "TR 0" >>tree.hed
cat $TRAIN_WSJ0/tree_ques.hed >>tree.hed

# Now the commands that cluster each output state
echo "TR 12" >>tree.hed
perl $TRAIN_SCRIPTS/MakeClusteredTri.pl TB $2 monophones1 >> tree.hed

echo "TR 1" >>tree.hed
echo "AU \"fulllist\"" >>tree.hed

echo "CO \"tiedlist\"" >>tree.hed
echo "ST \"trees\"" >>tree.hed

# Do the clustering
HHEd -A -T 1 -H hmm12/macros -H hmm12/hmmdefs -M hmm13 tree.hed triphones1 >hhed_cluster.log


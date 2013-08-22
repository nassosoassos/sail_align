
# Train the triphone models

cd $TRAIN_WSJ1

rm -f -r hmm11 hmm12 hmm11.log hmm12.log
mkdir hmm11 hmm12

cd $WSJ_ROOT

$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm10 hmm11 triphones1 wintri.mlf 1

# Second round, also generate stats file we use for state tying
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm11 hmm12 triphones1 wintri.mlf 1

# Copy the stats file off to the main directory for use in state tying
cp $TRAIN_WSJ1/hmm12/stats_hmm12 $TRAIN_WSJ1/stats


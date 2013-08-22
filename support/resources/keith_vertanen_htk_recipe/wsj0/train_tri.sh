
# Train the triphone models

cd $TRAIN_WSJ0

rm -f -r hmm11 hmm12 hmm11.log hmm12.log
mkdir hmm11 hmm12

cd $WSJ0_DIR

# HERest -B -A -T 1 -m 1 -d $TRAIN_WSJ0/hmm10 -C $TRAIN_COMMON/config -I $TRAIN_WSJ0/wintri.mlf -t 250.0 150.0 1500.0 -S train.scp -H $TRAIN_WSJ0/hmm10/macros -H $TRAIN_WSJ0/hmm10/hmmdefs -M $TRAIN_WSJ0/hmm11 $TRAIN_WSJ0/triphones1 >$TRAIN_WSJ0/hmm11.log
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ0 hmm10 hmm11 triphones1 wintri.mlf 1

# Second round, also generate stats file we use for state tying
#HERest -B -A -T 1 -m 1 -d $TRAIN_WSJ0/hmm11 -C $TRAIN_COMMON/config -I $TRAIN_WSJ0/wintri.mlf -t 250.0 150.0 1500.0 -s $TRAIN_WSJ0/stats -S train.scp -H $TRAIN_WSJ0/hmm11/macros -H $TRAIN_WSJ0/hmm11/hmmdefs -M $TRAIN_WSJ0/hmm12 $TRAIN_WSJ0/triphones1 >$TRAIN_WSJ0/hmm12.log
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ0 hmm11 hmm12 triphones1 wintri.mlf 1

# Copy the stats file off to the main directory for use in state tying
cp $TRAIN_WSJ0/hmm12/stats_hmm12 $TRAIN_WSJ0/stats
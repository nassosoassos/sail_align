
# Train the word internal phonetic decision tree state tied models

cd $TRAIN_WSJ1

# Cleanup old files and create new directories for model files
rm -f -r hmm14 hmm15 hmm16 hmm17
mkdir hmm14 hmm15 hmm16 hmm17
rm -f hmm14.log hmm15.log hmm16.log hmm17.log

cd $WSJ_ROOT

$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm13 hmm14 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm14 hmm15 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm15 hmm16 tiedlist wintri.mlf 0
$TRAIN_TIMIT/train_iter.sh $TRAIN_WSJ1 hmm16 hmm17 tiedlist wintri.mlf 0
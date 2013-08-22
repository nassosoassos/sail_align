# This does the data preparation and evaluation of the models
# trained using two WSJ1 test sets.
#
# Parameters:
#  $1  - HMM model directory to use (hmm42, hmm72, etc)
#  $2  - path to training directory ($TRAIN_WSJ0 or $TRAIN_WSJ1)
#  $3  - "cross" if we are evaluating cross word models
#  $4  - optional additional text to add to end of hresults filename

echo "Preparing and evaluating on WSJ1 test sets..."
echo ""
echo "Environment variables:"
echo "TRAIN_TIMIT    = $TRAIN_TIMIT"
echo "TRAIN_WSJ0     = $TRAIN_WSJ0"
echo "TRAIN_COMMON   = $TRAIN_COMMON"
echo "TRAIN_SCRIPTS  = $TRAIN_SCRIPTS"
echo "TIMIT_DIR      = $TIMIT_DIR"
echo "WSJ0_DIR       = $WSJ0_DIR"
echo "WSJ1_DIR       = $WSJ1_DIR"
echo ""

cd $TRAIN_WSJ0

echo "Coding si_dt_s6 audio..."
$TRAIN_WSJ0/prep_si_dt_s6.sh

echo "Building si_dt_s6 MLF..."
$TRAIN_WSJ0/make_mlf_si_dt_s6.sh

echo "Coding si_dt_05_odd audio..."
$TRAIN_WSJ0/prep_si_dt_05_odd.sh

echo "Building si_dt_05_odd MLF..."
$TRAIN_WSJ0/make_mlf_si_dt_05_odd.sh

if [[ $3 != "cross" ]] 
then

# Word internal model evaluation
echo "Evaluating on si_dt_s6 test set..."
$2/eval_si_dt_s6_no_lat.sh $1 _ro200_tb750_prune350_wi$4 350.0 -0.0 15.0
echo "Evaluating on si_dt_05_odd test set..."
$2/eval_si_dt_05_odd_no_lat.sh $1 _ro200_tb750_prune350_wi$4 350.0 -0.0 15.0

else

# Cross word model evaluation
echo "Evaluating on si_dt_s6 test set..."
$2/eval_si_dt_s6_no_lat.sh $1 _ro200_tb750_prune350_cross$4 350.0 -4.0 15.0 cross
echo "Evaluating on si_dt_05_odd test set..."
$2/eval_si_dt_05_odd_no_lat.sh $1 _ro200_tb750_prune350_cross$4 350.0 -4.0 15.0 cross

fi


# This script does everything needed to generate the TIMIT monophone
# models and evaluate them on monophone recognition.

./prep_cmu_dict.sh
./prep_code.sh
./train_mono.sh
./eval_mono.sh

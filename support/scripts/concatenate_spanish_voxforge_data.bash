#!/bin/bash
# Concatenate audio files and corresponding transcriptions from the 
# spanish voxforge database to use as test files for spanish alignment

# Function to get the transcripts of the audio data
utts() {
    for i in `cat $1`;
    do 
        s=`dirname $i | sed "s,/wav,/etc,"`
        grep `basename $i .wav` $s/PROMPTS | awk '{ $1=""; print }' 
    done
}

ROOT_DIR=/rmt/work/audio_asr/spanish
LIST_DIR=${ROOT_DIR}/lists
DATA_DIR=${ROOT_DIR}/data

# Generate list of 60 files (approximately 5 minutes total duration), randomly selected
ls ${ROOT_DIR}/*/wav/*.wav | sort -R | head -n 60 > ${LIST_DIR}/concat_audio.list

# Generate the audio file
sox `cat /rmt/work/audio_asr/spanish/lists/concat_audio.list | xargs echo` ../data/voxforge_spanish.wav

# Generate the transcription
TRANSCRIPTION=../data/voxforge_spanish.txt
utts ${LIST_DIR}/concat_audio.list | xargs echo | perl -e 'print lc <>;' > $TRANSCRIPTION


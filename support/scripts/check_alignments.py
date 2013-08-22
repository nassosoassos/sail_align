#!/usr/bin/python

import sys

alignment_file = sys.argv[1]
transcription_file = sys.argv[2]

alignment = open(alignment_file,'r')
transcription = open(transcription_file, 'r')

pron = []
for ln in alignment:
    ln = ln.rstrip('\r\n')
    ln_info = ln.split()
    lab = ln_info[2:]
    if lab[0] == 'sp' or lab[0] == 'sil':
        continue;
    pron.append(lab[0])
    
alignment.close()
aligned_string = "".join(pron)

ln = transcription.readline()
transcription.close()
ln = ln.rstrip('\r\n')
ln_info = ln.split()
transcribed_string = "".join(ln_info)

if not transcribed_string == aligned_string:
    print "Problematic alignment" 
    print transcribed_string
    print aligned_string

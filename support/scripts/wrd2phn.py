#!/usr/bin/python
import sys

wrd_file = sys.stdin
phn_file = sys.stdout

dictionary = sys.argv[1]

sentence = wrd_file.readline()
sentence = sentence.rstrip('\r\n')

dico = open(dictionary,'r')
word_map = {}
for ln in dico:
    ln = ln.rstrip('\r\n')
    ln_info = ln.split()
    wrd = ln_info.pop(0)
    pron = " ".join(ln_info)
    word_map[wrd] = pron

dico.close()

for w in sentence.split():
    print >> phn_file, word_map[w] + " ",

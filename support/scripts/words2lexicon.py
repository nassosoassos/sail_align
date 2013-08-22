#!/usr/bin/python

import sys
import re

if __name__=='__main__':
    word_list = sys.stdin
    lexicon = sys.stdout

    dico = {}
    for word_ln in word_list:
        word_ln = word_ln.rstrip('\r\n')
        word_info = word_ln.split(':')
        pron = word_info[1]
        pron = pron.strip()
        wrd = re.sub(' ','', pron)
        dico[wrd] = pron

    for wrd in dico.keys():
         print >> lexicon, "{} {}".format(wrd, dico[wrd])





#!/usr/bin/python
'''
Convert a TextGrid transcription to .txt format
'''
import re
import string
import sys

if __name__=="__main__":
   textgrid_file = sys.stdin
   text_file = sys.stdout
   dictionary = sys.argv[1]

   dic = open(dictionary, "r")
   phone_map = {}
   for ln in dic:
       ln = ln.rstrip('\r\n')
       ln_info = ln.split("\t")
       word = ln_info[0]
       pron = ln_info[1]
       phone_map[word] = pron
   dic.close()
   dic_words = phone_map.keys()

   for ln in textgrid_file:
       ln = ln.rstrip('\r\n')
      
       match_info = re.match(r"text\s+=\s+\"\s+([^\"]+)\"", ln)
       if match_info is not None:
           txt = match_info.group(1)
           txt = re.sub("[\'-]", "", txt)
           words = txt.split(" ")
           for w in words:
               u_wrd = string.upper(w)
               if u_wrd in dic_words:
                   print >> text_file, u_wrd+" ",
               else: 
                   print >> text_file, "\n"
                   print >> text_file, u_wrd+" was not found in the dictionary"

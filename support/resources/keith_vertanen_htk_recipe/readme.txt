
HTK TIMIT + WSJ training recipe 
--------------------------------
http://www.keithv.com/software/htk

Here are the scripts I used to train an HTK recognizer using 
the CMU pronunciation dictionary, WSJ0 corpus and optionally 
the TIMIT and WSJ1 corpora.  

The training regimen is mostly based on the tutorial presented 
in the HTKBook.  You'll need a unix system with Perl installed.  
Some of the scripts are happiest using the bash shell.  I only 
tested this on my own system, so I doubt this recipe is 
completely baked.  But hopefully it will provide a good starting
point.  Let me know if you find ways to improve it.

You should be able to get a system that performs similar to the 
gender independent SI-84 systems described in:
	P.C. Woodland, J.J. Odell, V. Valtchev & S.J. Young 
	(1994) "Large Vocabulary Continuous Speech Recognition 
	Using HTK", Proc, ICASSP'94, Adelaide

To evaluate the system, I used the WSJ 5K non-verbalized 
5k closed vocabulary set and the WSJ standard 5K non-verbalized 
closed bigram language model.  Similar to the above paper, I 
used the following test sets:

Nov'92       - November 1992 ARPA WSJ evaluation.
               Non-verbalized 5k closed set.
               330 sentences from 8 speakers.

si_dt_s6     - WSJ1 spoke 6 development test data.
               202 sentences from 8 speakers.

si_dt_05.odd - WSJ1 5k development test data.
               Deleted sentences with OOV words, then choosing
               every other sentence.
               248 sentences from 10 speakers.

I used Nov'92 as development test data (I tuned the system
on this set).  si_dt_s6 and si_dt_05.odd were used as 
evaluation test sets (no tuning was done against these sets).

Results using TIMIT and WSJ0 SI-84 (in % word error rates):
+------------------------------------------------------+
|                   | Nov'92 | si_dt_s6 | si_dt_05.odd |
+------------------------------------------------------+
| Word internal     | 8.44   | 13.93    | 14.46        |
| Cross word        | 7.23   | 12.30    | 13.20        |
+------------------------------------------------------+

Results using TIMIT, WSJ0 and WSJ1:
+------------------------------------------------------+
|                   | Nov'92 | si_dt_s6 | si_dt_05.odd |
+------------------------------------------------------+
| SI-284            | 5.40   |  9.64    |  9.53        |
| All WSJ0 + WSJ1   | 4.86   |  8.79    |  9.76        |
+------------------------------------------------------+

Basic steps:
0) Read and understand the tutorial in the HTKBook
1) Setup the environment variables contained in: add_to_your_env
2) Install HTK, HTK tools should be on your path
3) Install sph2pipe, sph2pipe should be on your path
4) Download the CMU dictionary, copy to $TRAIN_COMMON/c0.6
5) Copy SI_TR_S, SI_ET_05, WSJ0 directories from WSJ0 corpus to 
   $WSJ0_DIR.  If you want to train using all WSJ0 + WSJ1 training
   data, also copy SD_TR_L and SD_TR_S.  See wsj0_files.txt to see
   what I get from 'ls -R' from $WSJ0_DIR.
6) If you are going to non-flat start the monophones, copy 
   TIMIT/TRAIN, TIMIT/TEST  directories from TIMIT corpus to 
   $TIMIT_DIR.  See timit_files.txt to see what I get from
   'ls -R' from $TIMIT_DIR.
7) If you want to train using using SI-284, copy si_tr_s from
   WSJ1 corpus to $WSJ1_DIR.  To train using all WSJ1 training
   data, also copy si_tr_j, si_tr_jd, si_tr_l.  See wsj1_files.txt
   to see what I get from 'ls -R' from $WSJ1_DIR.
8) Run one of:
     go_wi.sh           - word internal triphones using TIMIT + WSJ0
     go_cross.sh        - cross word triphones using TIMIT + WSJ0
     go_flat_wi.sh      - flat start word internal triphones using only WSJ0
     go_flat_cross.sh   - cross word triphones using WSJ0
     go_si284_cross.sh  - cross word triphones using SI-284 training set 
     go_all_cross.sh    - cross word triphones using all WSJ0 + WSJ1 data

If you want to evaluate on the si_dt_s6 or si_dt_05.odd test sets, 
you'll need the WSJ1 corpus.  Set the $WSJ1_DIR environment variable
to be the location of the corpus. You'll need to copy the si_et_s6, 
si_dt_05, and trans/wsj1/si_dt_05 directories and also make some 
manual corrections to the transcriptions (see comments in 
make_mlf_si_dt_05_odd.sh and make_mlf_si_dt_s6.sh).  The go_wsj1_eval.sh 
script does the preparation and evaluation on the WSJ1 test sets.

Have fun!
Keith Vertanen

Revision history:
-----------------
Oct 7th, 2005  - Added calls to prep_nov92.sh to go* scripts
               - Added ICASSP paper reference and details of
                 experimental conditions to readme.txt

Nov 2nd, 2005  - Changed front-end to use _E_D_A_Z instead of _0_D_A_Z
               - Changed silence modeling, sp and sil now share three
                 tied output states, sp can be skipped with no output.
               - Added extra training rounds for TIMIT monophones using 
                 transcriptions which have sp inserted between words.
               - Changed mixing up procedure to first double the 
                 Gaussians in silence models, then mixup 1->2->4->6->8.
               - Added results and scripts to test on WSJ1 test sets.
               - Increased maximum pruning threshold to 1500 in 
                 train_tri.sh to prevent pruning errors on a few files.

May 8th, 2006  - Changed front-end back to _0_D_A_Z 
               - Changed scripts to use parallel mode of HERest to 
                 increase numeric accuracy and avoid failing when 
                 using large amounts of training data.
               - Added scripts for training using WSJ1 data, this 
                 includes just the SI-284 set as well as using all
                 available training data (long term, etc)
               - Added scripts that mix up to 16/32 Gaussians when
                 using WSJ1 training data.
               - Added results for models train on SI-284 and all 
                 of WSJ0 and WSJ1. 

Jan 6th, 2008  - Fixed bug with flat training scripts.  
               - Added support for threaded training in train_iter.sh,
                 this should speed up training on machines with multiple
                 CPU cores and enough memory, thanks to Mikel Peagarikano!
               - Fixed bug with non-quoted 'find -iname' commands 
                 returning blank results.




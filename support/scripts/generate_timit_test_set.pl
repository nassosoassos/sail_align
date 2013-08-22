#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  generate_timit_test_set.pl
#
#        USAGE:  ./generate_timit_test_set.pl  
#
#  DESCRIPTION:  Generate TIMIT test set for phonetic alignment. Concatenate various
#                TIMIT utterances into larger segments. Concatenation is achieved using sox.
#
#      OPTIONS:  -h         Help message
#                -d dir     TIMIT directory [/home/database/TIMIT]
#                -w dir     Out directory [/home/work/speech_text_alignment/timit_corpus]
#                -t int     Desired segment duration in seconds (set to 0 if no segmentation is desired) [0]
#                --fs int   TIMIT sampling frequence [16000]
#                --al file  List of audio files [/home/work/speech_text_alignment/timit_segments_audio.list]
#                --tl file  List of corresponding transcription files [/home/work/speech_text_alignment/timit_segments_text.list]
#                --sox file Sox binary [sox]
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Nassos Katsamanis (NK), nkatsam@sipi.usc.edu
#      COMPANY:  University of Southern California
#      VERSION:  1.0
#      CREATED:  11/15/2010 11:29:34 AM
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

use Getopt::Long;
use File::Basename;
use File::Spec::Functions;
use File::Path;
use File::Copy;
use SailTools::SailComponent;
use SailTools::SailDataSet;

# Default configuration
my $help = 0;
my $timit_dir = "/home/databases/TIMIT";
my $out_dir = "/home/work/speech_text_alignment/timit_corpus";
my $max_duration = 0;
my $f_s = 16000;
my $audio_list = catfile($out_dir,"timit_segments_audio.list");
my $text_list = catfile($out_dir,"timit_segments_text.list");
my $sox_bin = "sox";

GetOptions( 'h' => \$help,
            'd=s' => \$timit_dir,
            'w=s' => \$out_dir,
            't=i' => \$max_duration,
            'fs=i'=> \$f_s,
            'al=s'=> \$audio_list,
            'tl=s'=> \$text_list,
            'sox=s' => \$sox_bin,
        ) or usage();
if ($help) {usage();}

mkpath($out_dir);
my $timit_data_dir = catdir($timit_dir, "timit");
my $audio_suffix = "wav";
my $phon_suffix = "phn";
my $word_suffix = "wrd";
my $trans_suffix = "txt";
my $n_segments_per_sox_command = 50;
$max_duration = int($max_duration*$f_s);

my $audio_files_ref = SailTools::SailDataSet::find_files_with_suffix_in_dir($timit_data_dir, $audio_suffix);
my $n_files = @$audio_files_ref;
print "$n_files audio files have been found\n";
my $i_segment = 1;
my $i_file = 1;
my $seg_duration = 0;
my @seg_words = ();
my @seg_wrd_start_times = ();
my @seg_wrd_end_times = ();
my @seg_phons = ();
my @seg_phon_start_times = ();
my @seg_phon_end_times = ();
my @seg_audio = ();
open(AU, ">$audio_list") or die("Cannot open list of audio segments $audio_list for writing.");
open(TX, ">$text_list") or die("Cannot open list of text transcriptions $text_list for writing.");
my @test_audio_files;
foreach my $file (@$audio_files_ref) {
    my ($b_name, $path, $sfx) = fileparse($file, "\.$audio_suffix");
    my $audio_file = catfile($timit_data_dir, $file);
    my $trans_file = catfile($timit_data_dir,$path, "$b_name.$trans_suffix");
    my $phon_file = catfile($timit_data_dir, $path, "$b_name.$phon_suffix");
    my $word_file = catfile($timit_data_dir, $path, "$b_name.$word_suffix");
  
    my $line_ref = SailTools::SailComponent::read_from_file($trans_file);

    my $len = @$line_ref;
    if ($len==0) {
        print $file."\n";
        exit;
    }

    #print $trans_file."\n";
    my ($start_time, $end_time, @words) = split(/\s+/, $line_ref->[0]);
    my $duration = $end_time - $start_time;
    my ($start_times_ref, $end_times_ref, $words_ref) = read_columns_file($word_file, 3);
    my ($start_phon_times_ref, $end_phon_times_ref, $phons_ref) = read_columns_file($phon_file, 3);
    sum_array_and_scalar($start_times_ref, $seg_duration);
    sum_array_and_scalar($end_times_ref, $seg_duration);
    sum_array_and_scalar($start_phon_times_ref, $seg_duration);
    sum_array_and_scalar($end_phon_times_ref, $seg_duration);

    $seg_duration += $duration;
    push(@seg_words, @$words_ref);
    push(@seg_phons, @$phons_ref);
    push(@seg_wrd_start_times, @$start_times_ref);
    push(@seg_wrd_end_times, @$end_times_ref);
    push(@seg_phon_start_times, @$start_phon_times_ref);
    push(@seg_phon_end_times, @$end_phon_times_ref);
    push(@seg_audio, $audio_file);
 
    if (($i_file<$n_files) && (($max_duration == 0) || ($seg_duration < $max_duration))) {
        $i_file++;
        next;
    }
    else {
        my $seg_audio_file = catfile($out_dir, "timit_${i_segment}.wav");
        my $seg_phon_file = catfile($out_dir, "timit_${i_segment}.phn");
        my $seg_word_file = catfile($out_dir, "timit_${i_segment}.wrd");
        my $seg_txt_file = catfile($out_dir, "timit_${i_segment}.txt");

        open(WRD, ">$seg_word_file") or die("Cannot open $seg_word_file for writing.\n");
        open(TXT, ">$seg_txt_file") or die("Cannot open $seg_txt_file for writing.\n");
        my $n_words = @seg_words;
        for (my $k=0; $k<$n_words; $k++) {
            my $s_time = $seg_wrd_start_times[$k]/$f_s;
            my $e_time = $seg_wrd_end_times[$k]/$f_s;
            my $k_wrd = $seg_words[$k];
            print WRD "$s_time $e_time $k_wrd\n";
            print TXT "$k_wrd ";
        }
        close(WRD);
        close(TXT);
        open(PHN, ">$seg_phon_file") or die("Cannot open $seg_phon_file for writing.\n");
        my $n_phones = @seg_phons;
        for (my $k=0; $k<$n_phones; $k++) {
            my $s_time = $seg_phon_start_times[$k]/$f_s;
            my $e_time = $seg_phon_end_times[$k]/$f_s;
            my $k_phn = $seg_phons[$k];
            print PHN "$s_time $e_time $k_phn\n";
        }
        close(PHN);

        my $audio_segments_string = join(" ", @seg_audio);
        concatenate_audio_files(\@seg_audio, $seg_audio_file, $sox_bin);
        print AU $seg_audio_file."\n";
        print TX $seg_txt_file."\n";

        @seg_words = ();
        @seg_phons = ();
        @seg_audio = ();
        @seg_wrd_start_times = ();
        @seg_wrd_end_times = ();
        @seg_phon_start_times = ();
        @seg_phon_end_times = ();
        $seg_duration = 0;
        $i_segment++; 
        $i_file++;
    }
}
close(AU);
close(TX);


sub concatenate_audio_files {
    my ($audio_files_ref, $audio_file, $sox_bin) = @_;
    my $tmp_file_1 = "tmp1.wav";
    my $tmp_file_2 = "tmp2.wav";

    my $seg_i = 1;
    my $n_files = @$audio_files_ref;
    my @seg_files;
    my $first_segment = 1;
    for (my $k=0; $k<$n_files; $k++) {
       push(@seg_files, $audio_files_ref->[$k]);
       if (($seg_i<100) && ($k<$n_files-1)) {
           $seg_i++;
           next;
       }
       else{
           my $seg_files_string = join(" ", @seg_files);
           if ($first_segment) {
              if ($k==$n_files-1) {
                  $tmp_file_1 = $audio_file;
              }
              $first_segment = 0;
              my $cmd = "$sox_bin $seg_files_string $tmp_file_1";
              system($cmd);
           }
           else {
              if ($k==$n_files-1) {
                  $tmp_file_2 = $audio_file;
              }
              my $cmd = "$sox_bin $tmp_file_1 $seg_files_string $tmp_file_2";
              my $swp = $tmp_file_2;
              $tmp_file_2 = $tmp_file_1;
              $tmp_file_1 = $swp;
              system($cmd);
           }
           @seg_files = ();
           $seg_i = 0;
       }
       $seg_i++;
    }
}

sub read_columns_file {
    my ($file, $n_columns) = @_;
    my @columns;
    open(FI, $file) or die("Cannot open file $file for reading");
    my $first_line = 1;
    while(<FI>) {
        my $line = $_;
        chomp($line);
        my @entries = split(/\s+/, $line);
        for (my $k=0; $k<$n_columns; $k++) {
            if ($first_line) {
                my @k_col = ();
                $k_col[0] = $entries[$k];
                $columns[$k] = \@k_col;
            }
            else {
                my $k_col_ref = $columns[$k];
                push(@$k_col_ref, $entries[$k]);
            }
        }
        $first_line = 0;
    }
    close(FI);
    return @columns;
}

sub divide_array_with_scalar {
    my ($arr_ref, $scalar) = @_;
    
    my $n_elms = @$arr_ref;
    for (my $k=0; $k<$n_elms; $k++) {
       $arr_ref->[$k] /= $scalar;
    }
}

sub sum_array_and_scalar {
    my ($arr_ref, $scalar) = @_;
    
    my $n_elms = @$arr_ref;
    for (my $k=0; $k<$n_elms; $k++) {
       $arr_ref->[$k] += $scalar;
    }
}

sub usage {
    print qq{
#        USAGE:  ./generate_timit_test_set.pl  
#
#  DESCRIPTION:  Generate TIMIT test set for phonetic alignment. Concatenate various
#                TIMIT utterances into larger segments. Concatenation is achieved using sox.
#
#      OPTIONS:  -h         Help message
#                -d dir     TIMIT directory [/home/database/TIMIT]
#                -w dir     Out directory [/home/work/speech_text_alignment/timit_corpus]
#                -t int     Desired segment duration in seconds (set to 0 if no segmentation is desired) [0]
#                --fs int   TIMIT sampling frequence [16000]
#                --al file  List of audio files [/home/work/speech_text_alignment/timit_segments_audio.list]
#                --tl file  List of corresponding transcription files [/home/work/speech_text_alignment/timit_segments_text.list]
#                --sox file Sox binary [sox]
#
   };
    exit;
}

#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  evaluate_alignment.pl
#
#        USAGE:  ./evaluate_alignment.pl  
#
#  DESCRIPTION:  Compare the estimated alignment with the reference one. The 
#                alignments are in the .lab format of HTK with times in seconds.
#                Consider that there are no insertion, deletion or substitution 
#                errors. Find the alignment percentage for a range of tolerances.
#
#      OPTIONS:  -h         Help message
#                -r file    Reference alignment
#                -t file    Hypothetical alignment
#                -s file    File where the temporal differences will be stored
#                -w dir     Working directory
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Nassos Katsamanis (NK), nkatsam@sipi.usc.edu
#      COMPANY:  University of Southern California
#      VERSION:  1.0
#      CREATED:  11/18/2010 06:04:21 PM
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

use Getopt::Long;
use SailTools::SailComponent;
use SailTools::AlignText;
use File::Spec::Functions;
use File::Path;
use File::Basename;
use List::Util qw(max);

my $help = 0;
my $reference = "reference.lab";
my $hypothesis = "hypothesis.lab";
my $working_dir = "../experiments/timit";
my $sclite_bin_path = "/home/work/couples_therapy/bin";
my $dif_data_file = "times.txt";
my @tol_ranges = (0.005, 0.010, 0.020, 0.030, 0.05, 0.06, 0.1, 0.15, 0.2, 0.5, 1, 2);
GetOptions( 'h' => \$help,
            'r=s' => \$reference,
            't=s' => \$hypothesis,
            'w=s' => \$working_dir,
            's=s' => \$dif_data_file,
        ) or usage();
if ($help) {usage();}

# First read reference. Concatenate words in the same line by using 
# underscore.
mkpath($working_dir);
open(REF, $reference) or die("Cannot open reference alignment $reference for reading");
my @ref_start_times;
my @ref_end_times;
my @ref_words;
my ($ref_b_name, $ref_path, $ref_sfx) = fileparse($reference, "\.[^\.]+");
my $sclite_txt_ref_file = catfile($working_dir, $ref_b_name.$ref_sfx.".txt");
while(my $line=<REF>) {
    chomp($line);
    if ($line =~ /([\d\.]+)\s+([\d\.]+)\s+(.+)/) {
      my ($start_time, $end_time, @words) = split(/\s+/, $line);
      my $line_word_string = join("_", @words);
      push(@ref_start_times, $start_time);
      push(@ref_end_times, $end_time);
      push(@ref_words, uc($line_word_string));
    }
}
close(REF);
SailTools::SailComponent::print_into_file(\@ref_words, $sclite_txt_ref_file, " ");

open(HYP, $hypothesis) or die("Cannot open hypothesis alignment $hypothesis for reading");
my @hyp_start_times;
my @hyp_end_times;
my @hyp_words;
my ($hyp_b_name, $hyp_path, $hyp_sfx) = fileparse($hypothesis, "\.[^\.]+");
my $sclite_txt_hyp_file = catfile($working_dir, $hyp_b_name.$hyp_sfx.".txt");
while(my $line=<HYP>) {
    chomp($line);
    if ($line =~ /([\d\.]+)\s+([\d\.]+)\s+(.+)/) {
      my ($start_time, $end_time, @words) = split(/\s+/, $line);
      my $line_word_string = join("_", @words);
      push(@hyp_start_times, $start_time);
      push(@hyp_end_times, $end_time);
      push(@hyp_words, uc($line_word_string));
    }
}
SailTools::SailComponent::print_into_file(\@hyp_words, $sclite_txt_hyp_file, " ");
close(HYP);

my %align_cfg;
$align_cfg{working_dir} = $working_dir;
$align_cfg{bin_path} = $sclite_bin_path;
my $text_aligner = new SailTools::AlignText(\%align_cfg);
my ($alignment_map, $ref_words_ref, $hyp_words_ref) = $text_aligner->align_text_files($sclite_txt_hyp_file, $sclite_txt_ref_file);

my $n_words = @$ref_words_ref;
if ($n_words != @ref_words) {
    die("Problem with sclite alignment?");
}

my $first_element = 1;
my $n_ranges = @tol_ranges;
my @alignment_counts;
my $max_dif = 0;
my $max_dif_start_time;
my $max_dif_word;
my $n_aligned_words = 0;
open(DIFS,">$dif_data_file") or die("Cannot open file to write temporal differences.");
for (my $word_counter=0; $word_counter<$n_words; $word_counter++) {
   
    my $ref_start_time = $ref_start_times[$word_counter];
    my $ref_end_time = $ref_end_times[$word_counter];
    my $ref_word = $ref_words[$word_counter];
    my $hyp_ind = $alignment_map->[$word_counter];

    if ($hyp_ind!= -1) {
        my $hyp_start_time = $hyp_start_times[$hyp_ind];
        my $hyp_end_time = $hyp_end_times[$hyp_ind];
        my $hyp_word = $hyp_words[$hyp_ind];

        if ($ref_word !~ $hyp_word) {
            print "Problematic alignment at this point: $ref_word $hyp_word\n";
            die();
        }


        my $start_bound_dif = abs($hyp_start_time-$ref_start_time);
        my $end_bound_dif = abs($hyp_end_time-$ref_end_time);
        my $max_bound_dif = max($start_bound_dif, $end_bound_dif);
        if ($max_bound_dif>$max_dif) {
            $max_dif = $max_bound_dif;
            $max_dif_start_time = $hyp_start_time;
            $max_dif_word = $hyp_word;
        }
        my $word_duration = $ref_end_time - $ref_start_time;
        print DIFS $max_bound_dif." $word_duration $ref_word\n";

        for (my $r=0; $r<$n_ranges; $r++) {
            if ($max_bound_dif < $tol_ranges[$r]) {
                $alignment_counts[$r]++;
            }
        }
        $n_aligned_words++;
    }
}
close(DIFS);

my @align_percentages;
for (my $r=0; $r<$n_ranges; $r++) {
   $align_percentages[$r] = $alignment_counts[$r]*100/$n_words;
}
print "Results\n-------\n";
print "Ranges:\t".join("\t",@tol_ranges)."\n";
print "Prcnts:\t".join("\t",@align_percentages)."\n";

my $aligned_words_percent = $n_aligned_words*100/$n_words;
print "Aligned words: $n_aligned_words/$n_words. Percentage of aligned words: ".$aligned_words_percent."\n";
print "Word worst aligned: $max_dif_word at $max_dif_start_time secs with $max_dif secs tolerance\n";

sub usage {
    print qq{
#        USAGE:  ./evaluate_alignment.pl  
#
#  DESCRIPTION:  Compare the estimated alignment with the reference one. The 
#                alignments are in the .lab format of HTK with times in seconds.
#                Consider that there are no insertion, deletion or substitution 
#                errors. Find the alignment percentage for a range of tolerances.
#
#      OPTIONS:  -h         Help message
#                -r file    Reference alignment
#                -t file    Hypothetical alignment
#                -s file    File where the temporal differences will be stored
#                -w dir     Working directory
    };
    exit;
}

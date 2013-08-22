#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  corrupt_text.pl
#
#        USAGE:  ./corrupt_text.pl  
#
#  DESCRIPTION:  Random corruption of text, by inserting, deleting or substituting words
#
#      OPTIONS:  -h             Help message
#                -t file        Original text file
#                -o file        Output text file
#                -p float       Percentage of words to be corrupted           
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Nassos Katsamanis (NK), nkatsam@sipi.usc.edu
#      COMPANY:  University of Southern California
#      VERSION:  1.0
#      CREATED:  11/20/2010 06:34:10 PM
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

use Getopt::Long;
use Math::Random;

my $help = 0;
my $text = "original.txt";
my $out = "out.txt";
my $corruption_degree = "0.01";

GetOptions('h'=> \$help,
           't=s' => \$text,
           'o=s' => \$out,
           'p=f' => \$corruption_degree,
       ) or usage();
if ($help) {usage();}
my %word_map;
my $n_words=0;
open(TXT, $text) or die("Cannot open original text file for reading");
while(my $line=<TXT>) {
    chomp($line);
    my @words = split(/\s+/, $line);
    foreach my $w (@words) {
        $word_map{$w}++;
        $n_words++;
    }

}
close(TXT);
my @freq_words = sort keys %word_map;


random_set_seed_from_phrase("Debug");

my $n_errors = $corruption_degree*$n_words;
my @rand_nums = random_uniform_integer($n_errors, 0, $n_words);
my @rand_error_types = random_uniform_integer($n_errors, 0, 2);
my @rand_freq_words = random_uniform_integer($n_errors, 0, 10);
my %error_map;
foreach my $rn (@rand_nums) {
    $error_map{$rn} = $rand_error_types[0];
    shift @rand_error_types;
}
@rand_nums = ();
foreach (sort { $a <=> $b } keys(%error_map) )
{
    push(@rand_nums, $_);
}

$n_errors = @rand_nums;
print "Number of errors: $n_errors, Number of words: $n_words\n";
open(TXT, $text) or die("Cannot open original text file for reading");
open(OUT, ">$out") or die("Cannot open output text file for writing");
my $i_word=0;
while(my $line=<TXT>) {
    chomp($line);
    my @words = split(/\s+/, $line);
    foreach my $w (@words) {
        if (@rand_nums && $i_word == $rand_nums[0]) {
            my $cur_rn = $rand_nums[0];
            shift @rand_nums;
            my $cur_err_type = $error_map{$cur_rn};
            my $freq_word_index = $rand_freq_words[0];
            shift @rand_freq_words;
            if ($cur_err_type==0) {
                # Insertions
                print OUT $w." ".$freq_words[$freq_word_index]." "; 
            }
            elsif ($cur_err_type==1) {
                # Deletions
            }
            else {
                # Substitutions
                print OUT $freq_words[$freq_word_index]." "; 
            }
        }
        else {
            print OUT $w." ";
        }
        $i_word++;
    }
    print OUT "\n";
}

close(TXT);
close(OUT);


sub usage {
    print qq{
#        USAGE:  ./corrupt_text.pl  
#
#  DESCRIPTION:  Random corruption of text, by inserting, deleting or substituting words
#
#      OPTIONS:  -h             Help message
#                -t file        Original text file
#                -o file        Output text file
#                -p float       Percentage of words to be corrupted           
    };
}

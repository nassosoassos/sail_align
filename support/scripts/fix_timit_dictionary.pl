#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  fix_timit_dictionary.pl
#
#        USAGE:  ./fix_timit_dictionary.pl  
#
#  DESCRIPTION:  Fix TIMIT dictionary to be HTK compatible, i.e.,
#                1) Capitalize the words
#                2) Set the phonetic transcriptions into lowercase
#                3) Remove '/ /'
#                4) Remove comments
#                5) Remove stress information, i.e., 1 and 2 numbers 
#
#      OPTIONS:  -h         Help message
#                -i         TIMIT dictionary
#                -o         Output dictionary
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Nassos Katsamanis (NK), nkatsam@sipi.usc.edu
#      COMPANY:  University of Southern California
#      VERSION:  1.0
#      CREATED:  11/17/2010 03:45:10 PM
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

use Getopt::Long;

my $help = 0;
my $in_file = "timitdic.txt";
my $out_file = "timit_dictionary.dic";

GetOptions( 'h' => \$help,
            'i=s' => \$in_file,
            'o=s' => \$out_file,
        ) or usage();
if ($help) {usage();}

open(TIMITDIC, $in_file) or die("Cannot open TIMIT dictionary file $in_file for reading\n");
my %word_map;
while (<TIMITDIC>) {
    my $line = $_;
    chomp($line);

    if ($line =~ /^;\s+/) {
        # Found a comment line. Ignore it.
        next;
    }
    elsif ($line =~ /([^\s]+)\s+\/([^\/]+)\//) {
        my $word = uc($1);
        my $phone_info = $2;
        my $first_char = substr($word, 0, 1);
        if ($first_char !~ /[A-Z|a-z|0-9|\s]/) {
            # Escape first character of the word if necessary
            # i.e., when not alphanumeric
            $word = "\\" . $word; 
        }

        # Remove stress information
        $phone_info =~ s/\d//g;

        $word_map{$word} = $phone_info;
    }
}
close(TIMITDIC);

open(OUTDIC, ">$out_file") or die("Cannot open output dictionary $out_file for writing\n");
foreach my $w (sort keys %word_map) {
    print OUTDIC "$w ".$word_map{$w}."\n";
}
close(OUTDIC);

sub usage {
    print qq{
#        USAGE:  ./fix_timit_dictionary.pl  
#
#  DESCRIPTION:  Fix TIMIT dictionary to be HTK compatible, i.e.,
#                1) Capitalize the words
#                2) Set the phonetic transcriptions into lowercase
#                3) Remove '/ /'
#                4) Remove comments
#                5) Remove stress information, i.e., 1 and 2 numbers 
#
#      OPTIONS:  -h         Help message
#                -i         TIMIT dictionary
#                -o         Output dictionary
    };
    exit;
}


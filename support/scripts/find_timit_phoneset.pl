#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  find_phoneset.pl
#
#        USAGE:  ./find_phoneset.pl  
#
#  DESCRIPTION:  Find the phone set in a phonetic transcription file.
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Nassos Katsamanis (NK), nkatsam@sipi.usc.edu
#      COMPANY:  University of Southern California
#      VERSION:  1.0
#      CREATED:  11/16/2010 08:34:26 PM
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

my $phone_set = "../library/timit_phones.list";
my $phn_file = "../timit_corpus/timit_1.phn";
my %phone_map;
open(PH, $phn_file) or die("Cannot open phonetic transcription for reading");
while(<PH>) {
    my $line = $_;
    chomp($line);
    my ($start_time, $end_time, $phone) = split(/\s/, $line);
    $phone_map{$phone}++;
}
close(PH);

open(PS,">$phone_set") or die("Cannot open phone list for writing");
my @phones = sort keys %phone_map;
my $n_phones = @phones;
foreach my $ph (@phones) {
    print PS $ph."\n";
}
close(PS);

print "$n_phones phones have been found.\n";

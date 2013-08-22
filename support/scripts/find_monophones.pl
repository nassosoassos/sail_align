#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  find_monophones.pl
#
#        USAGE:  ./find_monophones.pl  
#
#  DESCRIPTION:  Find the list of monophone acoustic models from the list of tied 
#                triphone acoustic models.
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Nassos Katsamanis (NK), nkatsam@sipi.usc.edu
#      COMPANY:  University of Southern California
#      VERSION:  1.0
#      CREATED:  11/16/2010 08:02:15 PM
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

my $tied_list = "../models/ac_models/english/htk/wsj_all_10000_32/tiedlist";
my $phone_list = "../library/phones.list";

my %phones_map;
open(TL, "$tied_list") or die("Cannot open list of tied models $tied_list for reading");
while(<TL>) {
    my $line = $_;
    chomp($line);

    my @phones = split(/[-+\s]/, $line);
    foreach my $ph (@phones) {
        $phones_map{$ph}++;
    }
}
close(TL);

open(PL, ">$phone_list") or die("Cannot open phone list $phone_list for writing");
my @phones = sort keys %phones_map;
foreach my $ph (@phones) {
    print PL $ph."\n";
}
close(PL);
my $n_phones = @phones;
print "$n_phones have been found.\n";

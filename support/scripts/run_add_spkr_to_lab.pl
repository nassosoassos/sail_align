#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  run_add_spkr_to_lab.pl
#
#        USAGE:  ./run_add_spkr_to_lab.pl  
#
#  DESCRIPTION:  Add speaker label to multiple lab files by using add_spkr_to_lab.pl
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Nassos Katsamanis (NK), nkatsam@sipi.usc.edu
#      COMPANY:  University of Southern California
#      VERSION:  1.0
#      CREATED:  07/21/2010 03:05:23 PM
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;
use File::Path;
use File::Basename;
use File::Copy;
use File::Spec::Functions;
use SailTools::SailComponent;

my $transcriptions_list = "aligned_transcriptions.list";
my $output_dir = "/home/work/couples_therapy/alignment_results";
my $config_file = "/home/work/speech_text_alignment/config/coup_ther_alignment.cfg";
my $working_dir = "/home/work/speech_text_alignment/experiments";
my $lab_sfx = "iter5.lab";
my $text_sfx = "cond.txt";
my $script_path = "/home/work/speech_text_alignment/src";
my $data_dir = "/home/databases/CoupTher/data/trans";

my $lab_files_ref = SailTools::SailComponent::read_from_file($transcriptions_list);
mkpath($output_dir);
foreach my $lab_file (@$lab_files_ref) {
    my ($bname, $lpath, $lsfx) = fileparse($lab_file, "\.$lab_sfx");
    my $tmp_lab_file = catfile($output_dir, $bname.".$lab_sfx");
    copy($lab_file, $tmp_lab_file);
    my $id = $bname;
    my $experiment_dir = catdir($working_dir, $id); 
    my @id_info = split(/\./,$bname);
    my $couple_id = $id_info[0];
    my $text_file = catfile($data_dir, $couple_id, "$id.cond.txt");
    if (!-e $text_file) {
        $id =~ s/_tape//;
        $text_file = catfile($data_dir, $couple_id, "${id}.cond.txt");
    }
  
    my $cmd = "perl $script_path/add_spkr_to_lab.pl -i $tmp_lab_file -w $experiment_dir -c $config_file -t $text_file -o $output_dir";
    print $cmd."\n";
    system($cmd);
}

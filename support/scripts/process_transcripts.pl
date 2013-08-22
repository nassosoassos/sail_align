#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  process_transcripts.pl
#
#        USAGE:  ./process_transcripts.pl  
#
#  DESCRIPTION: Transcription processing  
#               
#
#      OPTIONS:  -i dir           Input Directory
#                -o dir           Output Directory
#                -l file          Output list of transcription files
#                --is sfx         Input Suffix
#                --os sfx         Output Suffix
#                --if lab/txt     Input Format
#                --strip_time     Strip Timestamps
#                --upper_case     Convert to uppercase
#                --strip_punct    Strip Punctuation
#                --wsj            Extract wsj transcription file
#                --wsj_file file  The name of the wsj transcription file
#                --txt            Extract txt transcription file
#                --txt_file file  The name of the txt transcription file
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Nassos Katsamanis (NK), nkatsam@sipi.usc.edu
#      COMPANY:  University of Southern California
#      VERSION:  1.0
#      CREATED:  08/08/2010 05:27:21 PM
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

use Getopt::Long;
use SailTools::SailDataSet;
use File::Basename;
use File::Path;
use File::Spec::Functions;
use SailTools::SailComponent;


my $in_dir = "/home/databases/TIMIT/timit/train";
my $out_dir = "/home/work/asr/OtoSense/OtoSense09/debug/data/timit/timit/train";
my $in_sfx = "txt";
my $out_sfx = "txt";
my $help = 0;
my $binary = "sox";
my $in_format = "lab";
my $strip_time = 0;
my $upper_case = 1;
my $punct_strip = 0;
my $wsj = 0;
my $txt = 0;
my $wsj_file = catfile($out_dir,"transcripts.wsj");
my $txt_file = catfile($out_dir,"transcripts.txt");
my $out_list = "transcriptions.list";

GetOptions( 'h' => \$help,
            'i=s' => \$in_dir,
            'o=s' => \$out_dir,
            'l=s' => \$out_list,
            'is=s' => \$in_sfx,
            'os=s' => \$out_sfx,
            'if=s' => \$in_format,
            'strip_time' => \$strip_time,
            'upper_case' => \$upper_case,
            'strip_punct' => \$punct_strip,
            'wsj' => \$wsj,
            'wsj_file=s' => \$wsj_file,
            'txt' => \$txt,
            'txt_file=s' => \$txt_file,
        ) or usage();
if ($help) {usage();}
if (!-e $in_dir) { usage();}

my $lab_files_ref = SailTools::SailDataSet::find_files_with_suffix_in_dir($in_dir, $in_sfx);
if ($wsj) {
    open(WSJ, ">$wsj_file") or die("Cannot open wsj file for writing\n");
}
if ($txt) {
    open(TXT, ">$txt_file") or die("Cannot open txt file for writing\n");
}

open(LIST, ">$out_list") or die("Cannot open output list $out_list for writing.\n");
foreach my $file (@$lab_files_ref) {
    my ($f_name, $f_path, $f_sfx) = fileparse($file, "\.$in_sfx");
    my $f_out_dir = catdir($out_dir, $f_path);
    mkpath($f_out_dir);

    my $in_file = catfile($in_dir, $file);
    my $out_file = catfile($f_out_dir, "$f_name.$out_sfx");
    my @out_lines;
    print LIST $out_file."\n";

    if ( $in_format eq 'lab') {
        my $trans_lines_ref = SailTools::SailComponent::read_from_file($in_file);
        foreach my $line (@$trans_lines_ref) {
          my $output = $line;
          if ($line =~ /(\d+)\s+(\d+)\s+(.+)/) {
              if ($strip_time) {
                  $output = $3;
              }
              if ($upper_case) {
                  $output = uc($output);
              }
              if ($punct_strip) {
                  $output =~ s/[\.\?\-!,:,;]/ /g;
              }
          }  
          push(@out_lines, $output);
        }
        SailTools::SailComponent::print_into_file(\@out_lines, $out_file);
    }
    elsif ( $in_format eq 'txt') {
        my $trans_lines_ref = SailTools::SailComponent::read_from_file($in_file);
        foreach my $line (@$trans_lines_ref) {
          my $output = $line;
          if ($upper_case) {
             $output = uc($output);
          }
          if ($punct_strip) {
             $output =~ s/[\.\?\-!,:;)(*\"#\[\]]/ /g;
	     $output =~ s/ \'/ /g;
          }
          push(@out_lines, $output);
        }
        SailTools::SailComponent::print_into_file(\@out_lines, $out_file, " ");
    }
    if ($wsj) {
       my $unique_id = "${f_path}$f_name";
       $unique_id =~ s/\//_/g;
       print WSJ join(" ", @out_lines)." ($unique_id)\n";
    }
    if ($txt) {
       print TXT join(" ", @out_lines)."\n";
    }
}
close(LIST);
if ($wsj) {
  close(WSJ);
}
if ($txt) {
  close(TXT);
}
exit;

sub usage {
    print qq{
#===============================================================================
#
#         FILE:  process_transcripts.pl
#
#        USAGE:  ./process_transcripts.pl  
#
#  DESCRIPTION: Transcription processing  
#               
#
#      OPTIONS:  -i dir           Input Directory
#                -o dir           Output Directory
#                -l file          Output list of transcription files
#                --is sfx         Input Suffix
#                --os sfx         Output Suffix
#                --if lab/txt     Input Format
#                --strip_time     Strip Timestamps
#                --upper_case     Convert to uppercase
#                --strip_punct    Strip Punctuation
#                --wsj            Extract wsj transcription file
#                --wsj_file file  The name of the wsj transcription file
#                --txt            Extract txt transcription file
#                --txt_file file  The name of the txt transcription file
#===============================================================================
};
   exit;
};


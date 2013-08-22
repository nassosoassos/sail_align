#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  process_audio.pl
#
#        USAGE:  ./process_audio.pl  
#
#  DESCRIPTION:  Process all the audio files in a certain directory structure 
#
#      OPTIONS:  -i     Input Directory
#                -o     Output Directory
#                -l     Input List
#                --is   Input Suffix
#                --os   Output Suffix
#                --ir   Input sampling rate
#                --or   Output sampling rate
#                -b     Binary to be used for the conversion
#                --bp    Binary path
#                --ol   Output list of audio files
#                --log  Log file
#                --fl   List of files for which conversion has failed
#                --pathskip Skip first path levels in order to specify the output paths
#                       used when a list is given at the input and the input root directory
#                       is not really known
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


my $in_dir = "/home/naveen/ICT/data/train";
my $out_dir = "/home/naveen/ICT/data/raw";
my $in_list = "in.list";
my $in_sfx = "wav";
my $out_sfx = "raw";
my $help = 0;
my $binary = "sph2pipe";
my $bin_path = "/usr/local/bin";
my $i_rate = 16000;
my $o_rate = 16000;
my $audio_list = "audio.list";
my $fail_list = "fail.list";
my $log_file = "audio.log";
my $min_file_size = 50;
my $pathskip = 0;


GetOptions( 'i=s' => \$in_dir,
            'o=s' => \$out_dir,
            'l=s' => \$in_list,
            'is=s' => \$in_sfx,
            'os=s' => \$out_sfx,
            'b=s' => \$binary,
            'bp=s' => \$bin_path,
            'ir=s' => \$i_rate,
            'or=s' => \$o_rate,
            'ol=s' => \$audio_list,
            'log=s' => \$log_file,
            'fl=s' => \$fail_list, 
            'pathskip=i' => \$pathskip,
            'h' => \$help,
        ) or usage();
if ($help) {usage();}
if ((!-e $in_dir) && (!-e $in_list)) { usage();}

my $wav_files_ref;

if (!-e $in_list) {
   $wav_files_ref = SailTools::SailDataSet::find_files_with_suffix_in_dir($in_dir, $in_sfx);
}
else {
   $wav_files_ref = SailTools::SailComponent::read_from_file($in_list);
}
my $bin_file = catfile($bin_path, $binary);
open(LIST, ">$audio_list") or die("Cannot open audio list for writing");
open(LOG, ">$log_file") or die("Cannot open log file for writing");
open(FAIL, ">$fail_list") or die("Cannot open failures list for writing");
foreach my $wav_file (@$wav_files_ref) {
    my ($f_name, $f_path, $f_sfx) = fileparse($wav_file, "\.$in_sfx");
    if ($f_name =~ /^\./) {
        next;
    }
    if ($pathskip) {
        my @f_path_info = split(/\//, $f_path);
        my $f_path_levels = @f_path_info;
        $f_path = join("/", @f_path_info[$pathskip..$f_path_levels-1]);
    }
    my $f_out_dir = catdir($out_dir, $f_path);
    mkpath($f_out_dir);

    my $in_file;
    if (!-e $in_list) {
      $in_file = catfile($in_dir, $wav_file);
    }
    else {
      $in_file = $wav_file;  
    }
    my $out_file = catfile($f_out_dir, "$f_name.$out_sfx");
    my $cmd;
    if ($binary =~ /mpg123/) {
      $cmd = "$bin_file --mono -r 16000 -w $out_file $in_file";
    }
    if ($binary =~ /sox/) {
      $cmd = "$bin_file -r $i_rate $in_file -c 1 -r $o_rate $out_file";
    }
    elsif ($binary =~ /fea/) {
      $cmd = "$bin_file -f $i_rate -o $o_rate $in_file $out_file";
    }
    elsif ($binary =~ /sph2pipe/) {
      $cmd = "$bin_file $in_file $out_file";
    }
    print $cmd."\n";
    my $output = SailTools::SailComponent::run($cmd);

    print LOG join("\n", @$output);

    if (!-e $out_file) {
	print FAIL $in_file."\n"; 
    }
    else {
	my $file_size = -s $out_file;
	if ($file_size<$min_file_size) {
	   print FAIL $in_file."\n"; 
	}
	else {
    	   print LIST $out_file."\n";
	}
    }
}
close(LIST);
close(LOG);
close(FAIL);
exit;

sub usage {
    print qq{
#===============================================================================
#
#         FILE:  process_audio.pl
#
#        USAGE:  ./process_audio.pl  
#
#  DESCRIPTION:  Process all the audio files in a certain directory structure 
#
#      OPTIONS:  -i     Input Directory
#                -o     Output Directory
#                -l     Input List
#                --is   Input Suffix
#                --os   Output Suffix
#                --ir   Input sampling rate
#                --or   Output sampling rate
#                -b     Binary to be used for the conversion
#                --bp    Binary path
#                --ol   Output list of audio files
#                --log  Log file
#                --fl   List of files for which conversion has failed
#                --pathskip Skip first path levels in order to specify the output paths
#                       used when a list is given at the input and the input root directory
#                       is not really known
#===============================================================================
};
    exit;
}



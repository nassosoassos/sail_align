#!/usr/bin/perl -w -I/home/work/lib/perl
##===============================================================================
#
#         FILE:  parallel_alignment_multiple_files_pbs.pl
#
#        USAGE:  ./parallel_alignment_multiple_files_pbs.pl [-h] -c configuration_file -t text_dir -i audio_dir
#													   -w working_dir [-a audio_suffix] [-s text_suffix]
#													   -l lib_dir -b script_file
#													   --npbs n_pbs --pbs_cmd pbs_command 
#													   --pbs_dir pbs_script_out_dir
#
#  DESCRIPTION: Setup multiple long speech-text alignment experiments in cluster.
#      OPTIONS:  -h							help
#				 -i audio_dir				The directory with the audio files
#				 -t text_dir                The directory with the text files
#				 -s text_suffix             The suffix of the text filenames [cond.txt]
#				 -a audio_suffix            The suffix of the audio filenames [wav]
#				 -c configuration_file	  	Configuration file for the alignment process 
#				 -w working_dir				Working directory
#				 -l lib_dir                 Directory where perl libraries are installed
#				 --npbs                     Number of pbs tasks
#				 --pbs_cmd                  Pbs spawning command
#				 --pbs_dir                  Pbs script output directory
# REQUIREMENTS:  Packages: 
#				 Log4perl
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Nassos Katsamanis (NK), <http://sipi.usc.edu/~nkatsam>
#      COMPANY:  SAIL, University of Southern California
#      VERSION:  1.0
#      CREATED:  02/12/2010 02:05:29 PM EEST
#     REVISION:  ---
#===============================================================================


use File::Basename;
use File::Spec::Functions;
use File::Path;
use POSIX qw(ceil floor);
use Log::Log4perl;
use Getopt::Long;
use SailTools::SailDataSet;

my $conf = qq(
	log4perl.category = DEBUG, ScreenApp
	log4perl.appender.ScreenApp = Log::Log4perl::Appender::Screen
	log4perl.appender.ScreenApp.layout   = Log::Log4perl::Layout::PatternLayout
	log4perl.appender.ScreenApp.layout.ConversionPattern = [%p] (%F line %L) %m%n
	);

Log::Log4perl::init( \$conf);

my $root_logger = Log::Log4perl->get_logger();

# Temporary definitions, to be placed in global configuration file
my $audio_dir = "/home/databases/CoupTher/data/audio";
my $text_dir = "/home/databases/CoupTher/data/trans";
my $configuration_file = "/home/work/speech_text_alignment/config/coup_ther_alignment.cfg";
my $lib_dir = "/home/work/lib/perl";
my $script_file = "/home/work/speech_text_alignment/src/speech_text_align_long_file.pl";
my $working_dir = "/home/work/speech_text_alignment/experiments";
my $audio_suffix = "wav";
my $text_suffix = "cond.txt";
my $pbs_command = "pbsdsh";
my $pbs_dir = "pbs_scripts";
my $n_pbs = 10;
GetOptions( 'h' => \$help,
			't=s' => \$text_dir,
			'i=s' => \$audio_dir,
			'c=s' => \$configuration_file,
			'w=s' => \$working_dir,
			'a=s' => \$audio_suffix,
            's=s' => \$text_suffix,
            'l=s' => \$lib_dir,
            'npbs=s'=> \$n_pbs,
            'pbscmd=s' => \$pbs_command, 
            'pbsdir=s' => \$pbs_dir,
            'b=s' => \$script_file,
		) or usage();			
if ($help) {usage();}

my $audio_files_ref = SailTools::SailDataSet::find_files_with_suffix_in_dir($audio_dir, $audio_suffix);
my $n_audio_files = @$audio_files_ref;
my $n_files_per_pbs = ceil($n_audio_files/$n_pbs);

$root_logger->debug("Number of files: $n_audio_files");

my $audio_filename;
my $text_filename;

mkpath($pbs_dir);
my $file_ind = 0;
for (my $pbs_count=0; $pbs_count<$n_pbs; $pbs_count++) {
  my $pbs_script = catfile($pbs_dir, "$pbs_count.pbs");  
  my $error_file = catfile($working_dir,"error$pbs_count.txt");
  my $output_file = catfile($working_dir,"output$pbs_count.txt");
  open(PBS, ">$pbs_script") || ($root_logger->fatal("Unable to open file $pbs_script for writing.") && die());
  print PBS "#!/bin/bash\n";
  print PBS "# job file for long speech-text alignment\n";
  print PBS "#PBS -l walltime=2:30:00\n";
  print PBS "#PBS -l nodes=$n_files_per_pbs:ppn=1\n";
  print PBS "#PBS -V\n";
  print PBS "#PBS -o $output_file\n";
  print PBS "#PBS -e $error_file\n\n";

  my $file_counter = 0;
  for ($file_counter; $file_counter<$n_files_per_pbs; $file_counter++) {
      if ($file_ind>($n_audio_files-1)) {
          last;
      }
      $audio_filename = $audio_files_ref->[$file_ind];
      my ($audio_bname, $audio_path, $audio_sfx) = fileparse($audio_filename, '\.[^\.]+');
      $audio_filename = catfile($audio_dir, $audio_filename);
      $text_filename = catfile($text_dir, $audio_path, $audio_bname.".$text_suffix");
      $root_logger->debug("audio:$audio_filename text: $text_filename");

      if (-e $text_filename) {
         my $file_working_dir = catdir($working_dir, $audio_bname);
         my $command = "$pbs_command -n $file_counter -u perl -I $lib_dir $script_file ".
                        "-t $text_filename -i $audio_filename -w $file_working_dir ".
                        "-c $configuration_file";
         print PBS "$command &\n\n"; 
      }
      else {
         $root_logger->error("Missing transcription file: $text_filename");
      }
      $file_ind++;
  }
  print PBS "wait";
  close(PBS);
  my $sub_cmd = "qsub $pbs_script";
  system($sub_cmd);
  $root_logger->info($sub_cmd);
}

sub usage {
	print qq{	
#         FILE:  parallel_alignment_multiple_files_pbs.pl
#
#        USAGE:  ./parallel_alignment_multiple_files_pbs.pl [-h] -c configuration_file -t text_dir -i audio_dir
#													   -w working_dir [-a audio_suffix] [-s text_suffix]
#													   -l lib_dir -b script_file
#													   --npbs n_pbs --pbs_cmd pbs_command 
#													   --pbs_dir pbs_script_out_dir
#
#  DESCRIPTION: Setup multiple long speech-text alignment experiments
#      OPTIONS:  -h							help
#				 -i audio_dir				The directory with the audio files
#				 -t text_dir                The directory with the text files
#				 -s text_suffix             The suffix of the text filenames [cond.txt]
#				 -a audio_suffix            The suffix of the audio filenames [wav]
#				 -c configuration_file	  	Configuration file for the alignment process 
#				 -w working_dir				Working directory
#				 -l lib_dir                 Directory where perl libraries are installed
#				 --npbs                     Number of pbs tasks
#				 --pbs_cmd                  Pbs spawning command
#				 --pbs_dir                  Pbs script output directory

};	
	exit;
}

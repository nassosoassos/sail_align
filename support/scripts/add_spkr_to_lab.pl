#!/usr/bin/perl -w 
#===============================================================================
#
#         FILE:  speech_text_align_long_file.pl
#
#        USAGE:  ./speech_text_align_long_file.pl [-h] -c configuration_file -t transcription_file -i audio_file
#													   [-w working_dir] [-e experiment_id]
#
#  DESCRIPTION: Long Speech-Text alignment utility
#      OPTIONS:  -h							help
#				 -i audio_file				The audio file that will be aligned with the text
#				 -c configuration_file	  	Configuration for the alignment process 
#				 -t transcription_file		Transcription file
#				 -w working_dir				Working directory
#				 -e experiment_id			An id for the experiment which is run
# REQUIREMENTS:  Packages: 
#				 SailTools
#				 Log4perl
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Nassos Katsamanis (NK), <http://sipi.usc.edu/~nkatsam>
#      COMPANY:  SAIL, University of Southern California
#      VERSION:  1.0
#      CREATED:  02/12/2010 02:05:29 PM EEST
#     REVISION:  ---
#===============================================================================

# General directives;
use strict;

# Required packages
use File::Basename;
use File::Path;
use File::Spec::Functions;
use SailTools;
use SailTools::SailSignal;
use SailTools::SailTranscription;
use SailTools::AlignSpeech;
use Getopt::Long;
use Log::Log4perl qw(get_logger :levels);

my $conf = qq(
	log4perl.category = INFO, ScreenApp
	log4perl.appender.ScreenApp = Log::Log4perl::Appender::Screen
	log4perl.appender.ScreenApp.layout   = Log::Log4perl::Layout::PatternLayout
	log4perl.appender.ScreenApp.Threshold = DEBUG
	log4perl.appender.ScreenApp.layout.ConversionPattern = [%p] (%F line %L) %m%n
	);

Log::Log4perl::init( \$conf);

my $root_logger = Log::Log4perl->get_logger();
use vars qw( %cfg
            $ROOTPATH
            $WORKINGDIR
            $BINDIR
            $EXPERIMENT_ID
            );

my $lab_file = 'transcription.lab';
my $text_file = 'transcription.txt';
my $log_file = 'alignment.log';
my $help = 0;
my $configuration_file = 'alignment.cfg';
my $working_dir = 'alignment';
my $out_dir = 'out_trans';
my $experiment_id = 'alignment';
GetOptions( 'h' => \$help,
			't=s' => \$text_file,
			'i=s' => \$lab_file,
			'c=s' => \$configuration_file,
			'w=s' => \$working_dir,
			'e=s' => \$experiment_id,
            'o=s' => \$out_dir,
		) or usage();			
if ($help) {usage();}

# Check if input files really exist
if ((!-e $text_file) || (!-e $lab_file) || (!-e $configuration_file))  { 
	$root_logger->debug("Configuration file: $configuration_file");
	$root_logger->debug("Lab file: $lab_file");
	$root_logger->debug("Transcription file: $text_file");
	$root_logger->fatal("Did not find audio file, configuration file or transcription");
	usage(); 
}

# Preparations
$WORKINGDIR = $working_dir;
mkpath($WORKINGDIR); 
if (!-e $WORKINGDIR) {
	$root_logger->fatal("Cannot create working directory $working_dir.");
	usage();
}
$EXPERIMENT_ID = $experiment_id;

# Initialize file logging
$log_file = catfile($working_dir, $log_file);
my $appender = Log::Log4perl::Appender->new(
				"Log::Log4perl::Appender::File",
				filename => "$log_file",
				mode => 'append',
				additivity => 0);
$root_logger->add_appender($appender);
$root_logger->debug("File appender has been added.");
my $saillogger = get_logger("SailTools");
$saillogger->level($root_logger->level());
$saillogger->add_appender($appender);


# Find transcript file's base name
my ($trans_bname, $trans_path, $trans_sfx) = fileparse($lab_file, '\.[^\.]+');
$root_logger->debug("lab:$lab_file text: $text_file");
my $name = $trans_bname;
$name =~ s/\./_/g;

# Load configuration file and initialize the experiment
do($configuration_file);
my $experiment = new SailTools(\%cfg);
$root_logger->debug("Initialized experiment $EXPERIMENT_ID, working dir: ".$cfg{working_dir});

# Initialize the aligned transcription
my $transcription_file = catfile($cfg{working_dir}, "$name.lab");
my %raw_transcription = ();
$raw_transcription{name} = $text_file;
$raw_transcription{format} = 'speaker_per_line_no_times';
my $text = new SailTools::SailTranscription($transcription_file, $experiment);
$text->set_from_file(\%raw_transcription);
$text->correct_typos_from_file($experiment->{cfg}->{text}->{word_corrections_map}); 
$text->delete_words_from_file($experiment->{cfg}->{text}->{word_deletions_list});
my $original_words = $text->{words};
my $n_original_words = @$original_words;

#for (my $k=0; $k<$n_original_words; $k++) {
#   print $text->{words}->[$k]." ".$text->{speakers}->[$k]."\n"; 
#}

$root_logger->debug("Initialized transcription");
# Alignment
# Find the parts that are correctly aligned
# Concatenate transcriptions    
# Remove uncertainties from lab file
my $lab_info = SailTools::SailComponent::read_from_file($lab_file);

my @updated_lab;
my $speaker_exists=1;
my @uncertainties = ();
foreach my $lab_line (@$lab_info) {
    if ($lab_line =~ s/\s(\d)$//)
    {push(@uncertainties, $1);}
    push(@updated_lab, $lab_line);
    if ($lab_line =~ /^\d.*\s\w$/) {
        $speaker_exists++;
    }
    else {
        if ($lab_line =~ /\d/) {
            #print $lab_line."\n";
        }
    }
}
my $n_lines = @updated_lab;
if ($speaker_exists > $n_lines-5) {
    $root_logger->debug("Speaker exists but is deleted");
    for (my $line_counter=0; $line_counter<$n_lines; $line_counter++) {
        my $line = $updated_lab[$line_counter];
        $line =~ s/\s\w$//;
        $updated_lab[$line_counter] = $line;
    }
}
SailTools::SailComponent::print_into_file(\@updated_lab, $lab_file);

my $out_file = catfile($out_dir,"${trans_bname}.lab");

my $global_hypothesis = new SailTools::SailTranscription($lab_file);
$global_hypothesis->{lab_time_constant}=1;
$root_logger->debug("Lab file: $lab_file");
$global_hypothesis->init_from_file($lab_file);
my $word_ref = $global_hypothesis->{words};
my $n_words = @$word_ref;
my $unique_words = $global_hypothesis->get_unique_words;
my $n_unique_words = @$unique_words;
$global_hypothesis->{speakers}= $text->{speakers};
$global_hypothesis->{uncertainties} = \@uncertainties;

my $speakers_ref = $text->{speakers};
my $n_speaker_labels = @$speakers_ref;
my $n_uncertainties = @uncertainties;
$root_logger->debug("Original number of words: $n_original_words final: $n_words unique: $n_unique_words");    
$root_logger->debug("Original number of speakers: $n_speaker_labels");

#open(TEMP, ">tmp.txt");
#for (my $k=0; $k<$n_original_words; $k++) {
#   print TEMP $text->{words}->[$k]." ".$global_hypothesis->{words}->[$k]."\n"; 
#}
#close(TEMP);
mkpath($out_dir);
$root_logger->debug("Out file: $out_file");

$global_hypothesis->write_to_file($out_file, "lab","words_speakers");

# Adding uncertainties back
$lab_info = SailTools::SailComponent::read_from_file($out_file);
my @final_lab;
for (my $k=0; $k<$n_uncertainties; $k++) { 
    my $lab_line = $lab_info->[$k];
    my $line_uncertainty = $uncertainties[$k];
    $lab_line =~ s/$/ $line_uncertainty/;
    push(@final_lab, $lab_line);
}
SailTools::SailComponent::print_into_file(\@final_lab, $out_file);


exit;

sub usage {
	print qq{	
	HELP:	
	Aligning a long speech file with its corresponding transcription.
	usage: $0 [-h]
	-h              : this (help) message
	-w working_dir  : the working directory [default: alignment]
	-i lab_file   : the speech audio file [default: transcriptio.lab]
	-c configuration_file   : configuration file [default: alignment.cfg]
	-t transcription_file : the original transcription file
    -o out_dir : The output directory
	
	example: $0 -i utterance.wav -t utterance_transcription.lab -c config_file.pl
};	
	exit;
}


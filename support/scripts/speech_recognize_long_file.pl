#!/usr/bin/perl -w 
#===============================================================================
#
#         FILE:  speech_recognize_long_file.pl
#
#        USAGE:  ./speech_recognize_long_file.pl [-h] -c configuration_file -i audio_file  [-w working_dir] [-e experiment_id]
#										
#
#  DESCRIPTION: Long Speech Recognition utility
#      OPTIONS:  -h							help
#				 -i audio_file				The audio file that will be aligned with the text
#				 -c configuration_file	  	Configuration for the alignment process 
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
	log4perl.category = DEBUG, ScreenApp
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

my $audio_file = 'speech.wav';
my $log_file = 'alignment.log';
my $help = 0;
my $configuration_file = 'alignment.cfg';
my $working_dir = 'alignment';
my $experiment_id = 'alignment';
GetOptions( 'h' => \$help,
			'i=s' => \$audio_file,
			'c=s' => \$configuration_file,
			'w=s' => \$working_dir,
			'e=s' => \$experiment_id,
		) or usage();			
if ($help) {usage();}

# Check if input files really exist
if ((!-e $audio_file) || (!-e $configuration_file))  { 
	$root_logger->debug("Configuration file: $configuration_file");
	$root_logger->debug("Audio file: $audio_file");
	$root_logger->fatal("Did not find audio file, configuration file");
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


# Find audio file's base name
my ($audio_bname, $audio_path, $audio_sfx) = fileparse($audio_file, '\.[^\.]+');
$root_logger->debug("audio:$audio_file");
my $name = $audio_bname;
$name =~ s/\./_/g;

# Load configuration file and initialize the experiment
do($configuration_file);
my $experiment = new SailTools(\%cfg);
$root_logger->debug("Initialized experiment $EXPERIMENT_ID, working dir: ".$cfg{working_dir});

# Load audio signal
my $signal = new SailTools::SailSignal($audio_file, $experiment);
$root_logger->debug("Successfully initialized a SailSignal instance");

# Run Voice Activity Detection
# voice activity so that segmentation does not occur in the middle of words
my $max_duration = $cfg{'max_utterance_duration'};
my $vad_configuration = $cfg{'vad'};
my $voice_detector = new SailTools::VoiceActivityDetection($vad_configuration, $experiment);
my $vad_transcription = $voice_detector->signal_to_vad($signal);

# Concatenate segments up to a maximum duration.
my ($utterances_start_times_ref, $utterances_end_times_ref) = $vad_transcription->concatenate_segments($max_duration);
    
my $n_segments = @$utterances_end_times_ref;
my $utt_end_time = $utterances_end_times_ref->[$n_segments-1];
    $root_logger->debug("File's duration is: $utt_end_time sec");
    
# Feature extraction
my $feature_extraction_config = $cfg{'feature_extraction'};
my $feature_extractor = new SailTools::FeatureExtractor($feature_extraction_config, $experiment); 
    
my $feature_seq = $feature_extractor->extract_features($signal);
        
$root_logger->debug("Feature extraction finished OK");

# Segmentation is implemented at the feature level since otherwise we would
# have to extract the features multiple times.
my $segmentation_conf = $cfg{'segmentation'};
my $segmentation_output_dir = catfile($cfg{features_directory}, $feature_seq->{name});
mkpath($segmentation_output_dir);
my $segmentation_script = catfile($cfg{working_dir}, $feature_seq->{name}.'.'.$segmentation_conf->{'cut_file_suffix'});
my $segmentation_output_list = catfile($cfg{working_dir}, $feature_seq->{name}.'.'.$segmentation_conf->{'segment_list_suffix'});
$root_logger->debug("Starting feature file segmentation");
my $feature_set = SailTools::SailSegment::segment_features($feature_seq, $segmentation_output_dir, $segmentation_output_list, $segmentation_script, $segmentation_conf, $utterances_start_times_ref, $utterances_end_times_ref);
$root_logger->debug("Feature file segmentation finished OK");
my %seg_config_hash;
$seg_config_hash{segmentation_output_dir} = $segmentation_output_dir;
$seg_config_hash{segmentation_output_list} = $segmentation_output_list;
$seg_config_hash{segmentation_script} = $segmentation_script;
$seg_config_hash{segmentation_conf} = $segmentation_conf;	
	
# Recognition
my $recognition_conf = $cfg{recognition};
my $result_cfg = $recognition_conf->{results};

# Read dictionary
my $phone_dict_conf = $recognition_conf->{dictionary};
my $output_symbols_ref = SailTools::SailLanguage::get_word_output_symbols_from_file($phone_dict_conf->{output_symbols_list});
my $dict_ref = SailTools::SailLanguage::create_dictionary($phone_dict_conf->{reference}, 'htk');
my $word_list = $cfg{word_list};
my $words_ref = SailTools::SailComponent::read_from_file($word_list);
my ($words_pron_ref, $unknown_words_ref) = SailTools::SailLanguage::word_pronounciations_from_dictionary($words_ref, $dict_ref);

my $n_dict_words = keys(%$words_pron_ref);
$root_logger->debug("Number of words in the reference dictionary: $n_dict_words");
my %dict = %$phone_dict_conf;
$dict{words_pron} = $words_pron_ref;
$dict{output_symbols} = $output_symbols_ref;

my $ac_model = $recognition_conf->{acoustic_models};
my $results_set;
my $la_model = $recognition_conf->{language_model};
$results_set = SailTools::SailRecognizeSpeech::recognize_speech_feature_set($feature_set, $ac_model, $la_model,\%dict, $result_cfg, $recognition_conf);
 

exit;

sub usage {
	print qq{	
	HELP:	
	Recognizing a long speech file.
	usage: $0 [-h]
	-h              : this (help) message
	-w working_dir  : the working directory [default: alignment]
	-i audio_file   : the speech audio file [default: speech.wav]
	-c configuration_file   : configuration file [default: alignment.cfg]
	
	example: $0 -i utterance.wav -c config_file.pl
};	
	exit;
}


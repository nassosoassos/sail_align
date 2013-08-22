package SailTools::AlignSpeech;

use warnings;
use strict;

use File::Path;
use File::Basename;
use File::Spec::Functions;
use Data::Dumper;

use SailTools::SailComponent;
use SailTools::SailSignal;
use SailTools::VoiceActivityDetection;
use SailTools::FeatureExtractor;
use SailTools::SailSegment;
use SailTools::SailLanguage;
use SailTools::SailRecognizeSpeech;
use SailTools::SailAdaptation;
use SailTools::AlignText;

use Log::Log4perl qw(:easy);

=head1 NAME

SailTools::AlignSpeech - Basic speech-text alignment functionality

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.10';
our @ISA     = qw(SailTools::SailComponent);

=head1 SYNOPSIS

The module implements align_speech_signal_text function that basically aligns
a long speech file with its corresponding transcription.

=head1 SUBROUTINES/METHODS

=head2 new

Generate a new AlignSpeech object. The object essentially carries all the necessary 
configuration information.

=cut

sub new {
    my ( $class, $experiment ) = @_;
    my $self;

    $self->{experiment} = $experiment;
    my $cfg_ref       = $experiment->{cfg};
    my $configuration = $cfg_ref->{alignment};

    # Paths
    $self->{working_dir}        = $experiment->{working_dir};
    $self->{features_directory} = $experiment->{features_directory};
    $self->{bin_path}           = $experiment->{bin_dir};

    ## Alignment specifics
    # Variables that control the flow of the alignment
    # Adapt acoustic models or not
    $self->{do_adaptation} = $configuration->{do_adaptation};

    # After long speech text alignment, perform Viterbi forced alignment
    # to generate a phonetic transcription
    $self->{do_phon_alignment} = $configuration->{do_phon_alignment};

    # After long speech text alignment perform Viterbi forced alignment
    # to generate a phonetic transcription
    $self->{do_forced_word_alignment} =
      $configuration->{do_forced_word_alignment};

    # This is assumingly the maximum utterance duration that the speech
    # recognition engine can handle
    $self->{max_utterance_duration} = $configuration->{max_utterance_duration};

    # This is the minimum percentage of words that have to be aligned
    $self->{alignment_accuracy} = $configuration->{alignment_accuracy};

    # This is the maximum number of alignment iterations
    $self->{max_n_iterations} = $configuration->{max_n_iterations};

    # Anchor definition. This is the minimum number of consecutive aligned words
    # that a region should include to be considered reliably aligned.
    $self->{min_n_aligned_words} = $configuration->{min_n_aligned_words};

# The mode of the output transcription, i.e., it can contain only times and words,
# speakers and/or uncertainties as well.
    $self->{output_mode} = $configuration->{output_mode};

    ## Subcomponents' configurations
    # Voice activity detection configuration
    $self->{vad} = $configuration->{vad};

    # Audio segmentation configuration
    $self->{segmentation} = $configuration->{segmentation};

    # Language modeling configuration
    $self->{language_modeling} = $configuration->{language_modeling};

    # Use background language model
    $self->{use_back_lm} = $configuration->{use_back_lm};

    # Feature extraction configuration
    $self->{feature_extraction} = $configuration->{feature_extraction};

    # Speech recognition configuration
    $self->{recognition} = $configuration->{recognition};

    # Acoustic model adaptation configuration
    $self->{adaptation} = $configuration->{adaptation};

    # Finite state grammar configuration
    $self->{fsg} = $configuration->{fsg};

    # Viterbi-forced phonetic post-alignment configuration
    $self->{phon_alignment} = $configuration->{phon_alignment};

    # Viterbi-forced word post-alignment configuration
    $self->{word_forced_alignment} = $configuration->{word_forced_alignment};

    # Do not try to align if duration is smaller than this in seconds because
    # probably there is a problem with erroneous transcription
    $self->{min_seg_duration} = 0.08;

    # These probably are not necessary
    $self->{suffix} = $configuration->{suffix};

    bless( $self, $class );
}

=head2 align_speech_text

This function will potentially also support long speech text alignment
of a list of speech files.

=cut

sub align_speech_text {
    my $this = shift;
    my $result;

    if ( $_[0]->isa("SailTools::SailSignal") ) {
        my $signal        = $_[0];
        my $transcription = $_[1];
        $this->align_speech_signal_text( $signal, $transcription );
    }
    else {
        DEBUG("Currently alignment from list of files is not implemented");
    }
}

=head2 align_speech_signal_text

Function to align speech and text (transcription)
The idea is to recognize speech using generic models and then compare
with the transcriptions. The problem with the standard Viterbi forced alignment
is that you cannot really have too long segments and erroneous transcriptions or 
noisy audio. The outline of the algorithm is as follows:

=cut

sub align_speech_signal_text {

    my ( $this, $signal, $transcription ) = @_;
    DEBUG(  "Signal: "
          . $signal->{file}
          . " Number of transcribed words: "
          . $transcription->get_n_words );

    # 1) Voice activity detection so that segmentation does not occur in the middle of words.
    # It is not so crucial however.
    my $max_duration      = $this->{'max_utterance_duration'};
    my $vad_configuration = $this->{'vad'};
    my $voice_detector =
      new SailTools::VoiceActivityDetection( $vad_configuration,
        $this->{'experiment'}, $max_duration );
    my $vad_transcription = $voice_detector->signal_to_vad($signal);

    # Concatenate segments up to a maximum duration. Assumingly, this duration
    # is only limited by computational considerations of the speech recognition
    # engine.
    my ( $utterances_start_times_ref, $utterances_end_times_ref ) =
      $vad_transcription->concatenate_segments($max_duration);

    my $n_segments   = @$utterances_end_times_ref;
    my $utt_end_time = $utterances_end_times_ref->[ $n_segments - 1 ];
    $transcription->{duration} = $utt_end_time;
    DEBUG("File's duration is: $utt_end_time sec");

    # 2) Acoustic Feature extraction
    my $feature_extraction_config = $this->{'feature_extraction'};
    my $feature_extractor =
      new SailTools::FeatureExtractor( $feature_extraction_config,
        $this->{'experiment'} );

    my $feature_seq = $feature_extractor->extract_features($signal);
    DEBUG("Feature extraction finished OK");

  # 3) Segmentation is implemented at the feature level since otherwise we would
  # have to extract the features multiple times.
    my $segmentation_conf = $this->{'segmentation'};
    my $segmentation_output_dir =
      catfile( $this->{features_directory}, $feature_seq->{name} );
    mkpath($segmentation_output_dir);
    my $segmentation_script =
      catfile( $this->{working_dir},
        $feature_seq->{name} . '.' . $segmentation_conf->{'cut_file_suffix'} );
    my $segmentation_output_list = catfile( $this->{working_dir},
            $feature_seq->{name} . '.'
          . $segmentation_conf->{'segment_list_suffix'} );
    DEBUG("Starting feature file segmentation");
    my $feature_set = SailTools::SailSegment::segment_features(
        $feature_seq,              $segmentation_output_dir,
        $segmentation_output_list, $segmentation_script,
        $segmentation_conf,        $utterances_start_times_ref,
        $utterances_end_times_ref
    );

    DEBUG("Feature file segmentation finished OK");
    my %seg_config_hash;
    $seg_config_hash{segmentation_output_dir}  = $segmentation_output_dir;
    $seg_config_hash{segmentation_output_list} = $segmentation_output_list;
    $seg_config_hash{segmentation_script}      = $segmentation_script;
    $seg_config_hash{segmentation_conf}        = $segmentation_conf;

    # 4) Generate the dictionary
    # Dictionary creation for the specific file, given reference dictionaries
    my $ref_dict;
    my $phone_set;
    my $language_conf = $this->{'language_modeling'};
    my $ref_phone_dict  = $language_conf->{ref_phone_dictionary};
    my $phone_dict_conf = $language_conf->{dictionary};

    # Also allow for alternative phonesets, given appropriate phone maps.
    # The TIMIT dictionary is an example of such a case since it uses
    # a different phoneset than the standard CMU dictionary.
    if ( $phone_dict_conf->{apply_phone_map} ) {
        ( $ref_dict, $phone_set ) =
          SailTools::SailLanguage::create_dictionary_apply_phone_map(
            $phone_dict_conf->{reference},
            $phone_dict_conf->{phone_map_direct}
          );
    }
    else {
        ( $ref_dict, $phone_set ) = SailTools::SailLanguage::create_dictionary(
            $phone_dict_conf->{reference} );
    }
    my $words_ref      = $transcription->get_unique_words();
    my $n_unique_words = @$words_ref;
    DEBUG("Number of Unique words in the transcription: $n_unique_words");
    my %word_list;
    $word_list{file} = $language_conf->{wordlist};
    my ( $bname, $wpath ) = fileparse( $word_list{file}, "\.[^\.]+" );
    mkpath($wpath);

    # Add the sentence boundaries to the wordlist
    my $recognition_conf = $this->{recognition};
    $word_list{words} = $words_ref;


    # For sanity, check whether the phone set is a subset of the acoustic model phoneset
    my $ac_model_phoneset = SailTools::SailComponent::read_from_file(
        $recognition_conf->{acoustic_models}->{phone_set} );
    my $compatible_phonesets = SailTools::SailLanguage::compare_phone_sets();
    if ( !$compatible_phonesets ) {
        FATAL("Incompatible dictionary and acoustic model phonesets.") && die();
    }

    # Finally, find the word pronounciations in the dictionary
    my $n_dict_words = keys(%$ref_dict);
    DEBUG("Number of words in the reference dictionary: $n_dict_words");
    my ( $words_pron_ref, $unknown_words_ref ) =
      SailTools::SailLanguage::word_pronounciations_from_dictionary( $words_ref,
        $ref_dict );
    my $n_unknown_words = @$unknown_words_ref;
    DEBUG("Number of unknown words in the transcription: $n_unknown_words");

    # Add short pause to the end of each pronounciation. This is only needed
    # for tools like HVite that do not add a short pause model at the end
    # of the words. HDecode on the other hand does and gets confused if
    # it is provided with a sp enhanced dictionary.
    $transcription->replace_words( $unknown_words_ref,
        $language_conf->{model}->{oov_symbol} );
    my $sent_boundaries_ref =
      $this->{recognition}->{language_model}->{utterance_delimiters};
    foreach my $sb (@$sent_boundaries_ref) {
        $words_pron_ref->{$sb} = $phone_dict_conf->{sil_model};
    }
    my $output_symbols_ref =
      SailTools::SailLanguage::get_word_output_symbols_from_file(
        $phone_dict_conf->{output_symbols_list} );
    SailTools::SailLanguage::print_htk_dictionary_into_file( $words_pron_ref,
        $output_symbols_ref, $phone_dict_conf->{file} );
    SailTools::SailComponent::print_into_file( $unknown_words_ref,
        $language_conf->{unknown_wordlist} );
    push( @$words_ref, @$sent_boundaries_ref );
    SailTools::SailComponent::print_into_file( $words_ref, $word_list{file} );

    # Create the corpus on which the language model is to be built
    my $text_corpus = new SailTools::SailDataSet( $language_conf->{text} );
    my $text_file   = catfile( $text_corpus->{root_path},
        $signal->{name} . '.' . $text_corpus->{suffix} );
    $transcription->write_clean_to_file( $text_file, $text_corpus->{format},
        'words' );
    $text_corpus->push_file($text_file);

    # Name the language model after the name of the transcription.
    $language_conf->{model}->{name} = $signal->{name};
    my $la_model_arpa =
      SailTools::SailLanguage::build_language_model( $text_corpus, \%word_list,
        $language_conf->{model} );

    # Convert the language model to the appropriate format. This step is only
    # needed if the speech recognition engine cannot use the arpa format.
    my $la_model;
    if ( $recognition_conf->{lm_conversion}->{do_convert} ) {
        $la_model = SailTools::SailLanguage::convert_language_model_to_lattice(
            $la_model_arpa,
            $recognition_conf->{language_model},
            $recognition_conf->{lm_conversion}
        );
        DEBUG("Converted language model to lattice.");
    }
    else {
        $la_model = $la_model_arpa;
    }

    my $result_cfg = $recognition_conf->{results};
    my %dict       = %$phone_dict_conf;
    $dict{words_pron}     = $words_pron_ref;
    $dict{output_symbols} = $output_symbols_ref;
    my $ac_model = $recognition_conf->{acoustic_models};
    my $results_set;

    # Just for debugging purposes, set regenerate_results to true
    # so that the recognition steps would be skipped in the case
    # when the results have already been generated at a previous experiment.
    my $regenerate_results = 1;
    $recognition_conf->{alignment}->{use_adapted_models} = 0;
    $recognition_conf->{use_adapted_models} = 0;
    if ($regenerate_results) {

        # Run speech recognition
        $results_set =
          SailTools::SailRecognizeSpeech::recognize_speech_feature_set(
            $feature_set, $ac_model, $la_model, \%dict, $result_cfg,
            $recognition_conf );
    }
    else {

        # Or, simply collect previously generated results
        $result_cfg->{name} = $feature_set->{name};
        $results_set = new SailTools::SailTranscriptionSet($result_cfg);
        my $feature_files_ref = $feature_set->get_files();
        my $abs_files_ref =
          $results_set->get_files_from_parallel_file_array($feature_files_ref);
        $results_set->init_from_files($abs_files_ref);
    }
    my $results_file_ref = $results_set->get_files();

    # Find the parts that are correctly aligned
    # Concatenate transcriptions
    my $global_hypothesis = new SailTools::SailTranscription(
        catfile(
            $this->{working_dir}, $signal->{name} . '.' . $this->{suffix}
        )
    );
    $global_hypothesis->init_from_set( $results_set, $results_file_ref,
        $utterances_start_times_ref, $utterances_end_times_ref );
    my $hyp_words_ref = $global_hypothesis->{words};
    my $n_hyp_words   = @$hyp_words_ref;
    DEBUG("Number of words in the hypothesis file: $n_hyp_words");
    $global_hypothesis->write_to_file(
        catfile( $this->{working_dir}, "hypothesis.lab" ),
        "lab", "words" );

    my %text_aligning_cfg;
    $text_aligning_cfg{working_dir} =
      catdir( $this->{working_dir}, 'text_align' );
    $text_aligning_cfg{bin_path} = $this->{bin_path};
    my $text_aligner = new SailTools::AlignText( \%text_aligning_cfg );
    $text_aligner->{min_n_aligned_words} = $this->{min_n_aligned_words};

    my $n_align_iterations = 1;
    my %trans_align_config;
    $trans_align_config{iteration} = $n_align_iterations;
    my ( $number_of_aligned_words, $total_number_of_words ) =
      $text_aligner->align_transcriptions( $global_hypothesis, $transcription,
        \%trans_align_config );
    my $percentage_of_aligned_words =
      $number_of_aligned_words / $total_number_of_words;
    INFO( "Alignment iteration: $n_align_iterations Alignment percentage: "
          . $percentage_of_aligned_words );
    $transcription->write_to_file(
        catfile(
            $this->{working_dir},
            $signal->{name} . ".iter$n_align_iterations.lab"
        ),
        "lab", "words"
    );

    # Find the start and end times for segments that were correctly aligned
    my (
        $seg_start_times,   $seg_end_times, $seg_start_word_inds,
        $seg_end_word_inds, $timed_flags
    ) = $transcription->find_timed_segments($utt_end_time);

    # Generate regression classes using the original acoustic models
    # These regression classes are then used for adaptation
    my $orig_acoustic_models = $this->{adaptation}->{src_acoustic_models};
    my $regression_cfg       = $this->{adaptation}->{regression_class_tree};
    $this->{adaptation}->{alignment}->{use_adapted_models} = 0;

    # This process takes a while, so it is skipped if no acoustic adaptation is
    # required.
    if ( $this->{do_adaptation} ) {
        SailTools::SailAdaptation::generate_regression_class_tree(
            $orig_acoustic_models, $regression_cfg );
    }

    my $adaptation_success = 0;

    # Iterative adaptation
    while ($percentage_of_aligned_words < $this->{alignment_accuracy}
        && $n_align_iterations < $this->{max_n_iterations} )
    {
        my %align_info;
        $align_info{seg_start_times}     = $seg_start_times;
        $align_info{seg_end_times}       = $seg_end_times;
        $align_info{seg_start_word_inds} = $seg_start_word_inds;
        $align_info{seg_end_word_inds}   = $seg_end_word_inds;
        $align_info{timed_flags}         = $timed_flags;

        # Acoustic model adaptation
        if ( $this->{do_adaptation} && $n_align_iterations < 4 ) {

            # Perform acoustic model adaptation for only the first 3 iterations
            $adaptation_success =
              $this->adapt_to_aligned_segments( $transcription, $feature_seq,
                $ac_model, \%dict, \%align_info, \%seg_config_hash );

          # If adaptation has succeeded at least once, then use adapted acoustic
          # models from then on.
            if ( $adaptation_success
                && !$this->{recognition}->{use_adapted_models} )
            {
                $this->{recognition}->{use_adapted_models}              = 1;
                $this->{adaptation}->{alignment}->{use_adapted_models}  = 1;
                $this->{recognition}->{alignment}->{use_adapted_models} = 1;
                $this->{recognition}->{alignment}->{adaptation} =
                  $this->{adaptation};
                DEBUG("Adapted acoustic models are used from now on");
            }
        }
        $n_align_iterations++;

        my $n_segmented_parts = @$seg_start_times;

        # Collect unaligned regions
        my @unaligned_indices =
          grep { $timed_flags->[$_] == 0 } 0 .. @$timed_flags - 1;
        my ( $bname, $tpath, $sfx ) =
          fileparse( $transcription->{file}, "\.[^\.]+" );
        my %cfg;
        $cfg{suffix}    = $sfx;
        $cfg{root_path} = $tpath;
        $cfg{format}    = $this->{format};
        my $transcription_set = new SailTools::SailTranscriptionSet( \%cfg );

 # From the original transcription get a set of transcriptions for the unaligned
 # regions.
        $transcription->split_into_set_given_word_inds( $seg_start_word_inds,
            $seg_end_word_inds, $transcription_set );

        my $n_unaligned_segs = @unaligned_indices;
        my $index            = 0;

        # Iterate over each unaligned region
        foreach my $unaligned_index (@unaligned_indices) {
            my $current_start_time = $seg_start_times->[$unaligned_index];
            my $current_end_time   = $seg_end_times->[$unaligned_index];
            my $current_duration   = $current_end_time - $current_start_time;
            DEBUG(
"current_unaligned_index=$unaligned_index ind = $index number_of_segs = $n_unaligned_segs"
            );
            DEBUG(
"unaligned_index=$unaligned_index start: $current_start_time end: $current_end_time"
            );

            # If a segment is too short, skip it
            if ( $current_duration < $this->{min_seg_duration} ) {
                DEBUG(
"Skipped segment because of unexpectedly short duration.Probably problematic transcription at this point.\n"
                );
                $index++;
                next;
            }

      # Split the unaligned regions in smaller utterances if necessary, using
      # voice activity information. This is to comply with the maximum utterance
      # duration that can be processed by the speech recognition engine.
            my ( $seg_utt_start_times, $seg_utt_end_times ) =
              $vad_transcription->concatenate_segments( $max_duration,
                $current_start_time, $current_end_time );

            # Segmentation of the feature sequence into smaller sets
            my $seg_feature_set = SailTools::SailSegment::segment_features(
                $feature_seq,              $segmentation_output_dir,
                $segmentation_output_list, $segmentation_script,
                $segmentation_conf,        $seg_utt_start_times,
                $seg_utt_end_times
            );

            my $seg_feature_set_files = $seg_feature_set->get_files;
            my $n_files               = $seg_feature_set->{n_files};

            DEBUG("Number of segment files: $n_files");

            my $current_id = "$current_start_time-$current_end_time";

            my $current_transcription =
              $transcription_set->{transcriptions}->[$unaligned_index];

            my $trans_words_ref = $current_transcription->{words};

            DEBUG( join( " ", @$trans_words_ref ) );

            # Create the segment specific language model
            my $seg_words_ref = $current_transcription->get_unique_words();
            my $language_conf = $this->{'language_modeling'};
            my %seg_word_list;
            $seg_word_list{file} = $language_conf->{wordlist} . ".$current_id";

            # Add the sentence boundaries to the wordlist
            my $seg_recognition_conf = $this->{recognition};
            my $sent_boundaries_ref =
              $this->{recognition}->{language_model}->{utterance_delimiters};
            push( @$seg_words_ref, @$sent_boundaries_ref );
            $seg_word_list{words} = $seg_words_ref;
            SailTools::SailComponent::print_into_file( $seg_words_ref,
                $seg_word_list{file} );

            # Create the corpus on which the language model is to be built
            my $seg_text_corpus =
              new SailTools::SailDataSet( $language_conf->{text} );
            my $seg_text_file = catfile( $seg_text_corpus->{root_path},
                $signal->{name} . "$current_id." . $seg_text_corpus->{suffix} );
            $current_transcription->write_clean_to_file( $seg_text_file,
                $seg_text_corpus->{format}, 'words' );
            $seg_text_corpus->push_file($seg_text_file);

            my ( $seg_number_of_aligned_words, $seg_total_number_of_words );
            $seg_recognition_conf->{do_adaptation} = $this->{do_adaptation};
            if ( $this->{do_adaptation} ) {
                $seg_recognition_conf->{adaptation} = $this->{adaptation};
            }

            # For the last two iterations use finite state grammar and not
            # a language model.
            if ( $n_align_iterations < $this->{max_n_iterations} - 1 ) {

                # Name the language model after the name of the transcription.
                $language_conf->{model}->{name} =
                  $signal->{name} . ".$current_id";
                my $seg_la_model;
                if ( $this->{use_back_lm} ) {
                    $language_conf->{model}->{use_back_lm} = 1;
                    $seg_la_model =
                      SailTools::SailLanguage::build_language_model(
                        $seg_text_corpus,        \%seg_word_list,
                        $language_conf->{model}, $la_model_arpa
                      );
                }
                else {
                    $seg_la_model =
                      SailTools::SailLanguage::build_language_model(
                        $seg_text_corpus, \%seg_word_list,
                        $language_conf->{model} );
                }

                # Recognize the specific segment using the specific LM
                # Convert the language model to the appropriate format
                if ( $recognition_conf->{lm_conversion}->{do_convert} ) {
                    $seg_la_model =
                      SailTools::SailLanguage::convert_language_model_to_lattice(
                        $seg_la_model,
                        $recognition_conf->{language_model},
                        $recognition_conf->{lm_conversion}
                      );
                }
                my $seg_result_cfg = $recognition_conf->{results};
                my $seg_results_set;

        # Just for debugging purposes, set regenerate_results to true
        # so that the recognition steps would be skipped in the case
        # when the results have already been generated at a previous experiment.
                $regenerate_results = 1;
                if ($regenerate_results) {
                    $seg_results_set =
                      SailTools::SailRecognizeSpeech::recognize_speech_feature_set(
                        $seg_feature_set, $ac_model, $seg_la_model, \%dict,
                        $seg_result_cfg, $seg_recognition_conf );
                }
                else {
                    $seg_result_cfg->{name} = $feature_set->{name};
                    $seg_results_set =
                      new SailTools::SailTranscriptionSet($seg_result_cfg);
                    my $seg_feature_files_ref = $seg_feature_set->get_files();
                    my $abs_files_ref =
                      $seg_results_set->get_files_from_parallel_file_array(
                        $seg_feature_files_ref);
                    $seg_results_set->init_from_files($abs_files_ref);
                }

                # Find the parts that are correctly aligned
                my $seg_results_file_ref = $seg_results_set->get_files();

                my $seg_hypothesis = new SailTools::SailTranscription(
                    catfile(
                        $this->{working_dir},
                        $signal->{name} . ".$current_id." . $this->{suffix}
                    )
                );

                # Concatenate all the recognition results into one global
                # transcription hypothesis
                $seg_hypothesis->init_from_set(
                    $seg_results_set,     $seg_results_file_ref,
                    $seg_utt_start_times, $seg_utt_end_times
                );
                my %seg_text_aligning_cfg;
                $seg_text_aligning_cfg{working_dir} =
                  catdir( $this->{working_dir}, 'text_align' );

                $trans_align_config{iteration} = $n_align_iterations;
                ( $seg_number_of_aligned_words, $seg_total_number_of_words ) =
                  $text_aligner->align_transcriptions( $seg_hypothesis,
                    $current_transcription, \%trans_align_config );
            }
            else {

                # Create a proper FSG to allow for insertions and deletions
                my $seg_words_ref = $current_transcription->get_clean_words;

                mkpath( $this->{fsg}->{directory} );
                my $grammar_file = catfile( $this->{fsg}->{directory},
                    $signal->{name} . ".$current_id.grm" );
                my $wd_net_file = catfile( $this->{fsg}->{directory},
                    $signal->{name} . ".$current_id.wdn" );

                # Do not allow deletions in the last iteration. This is
                # the most constricted it can be.
                if ( $n_align_iterations == $this->{max_n_iterations} ) {
                    $this->{fsg}->{allow_deletions} = 0;
                }
                else {
                    $this->{fsg}->{allow_deletions} = 1;
                }
                SailTools::SailLanguage::prepare_align_fsg(
                    $seg_words_ref, $grammar_file,
                    $wd_net_file,   $this->{fsg}
                );

                my $seg_result_cfg = $recognition_conf->{results};
                my $seg_results_set;
                $seg_recognition_conf->{sen_start} = $this->{fsg}->{sen_start};
                $seg_recognition_conf->{sen_end}   = $this->{fsg}->{sen_end};
                $seg_recognition_conf->{sen_boundary_phon} =
                  $this->{fsg}->{sen_boundary_phon};

                $seg_results_set =
                  SailTools::SailRecognizeSpeech::recognize_fsg_speech_feature_set(
                    $seg_feature_set, $ac_model, $wd_net_file, \%dict,
                    $seg_result_cfg, $seg_recognition_conf );

                # Find the parts that are correctly aligned
                my $seg_results_file_ref = $seg_results_set->get_files();

                my $seg_hypothesis = new SailTools::SailTranscription(
                    catfile(
                        $this->{working_dir},
                        $signal->{name} . ".$current_id." . $this->{suffix}
                    )
                );
                $seg_hypothesis->init_from_set(
                    $seg_results_set,     $seg_results_file_ref,
                    $seg_utt_start_times, $seg_utt_end_times
                );
                my %seg_text_aligning_cfg;
                $seg_text_aligning_cfg{working_dir} =
                  catdir( $this->{working_dir}, 'text_align' );

                $trans_align_config{iteration} = $n_align_iterations;
                ( $seg_number_of_aligned_words, $seg_total_number_of_words ) =
                  $text_aligner->align_transcriptions( $seg_hypothesis,
                    $current_transcription, \%trans_align_config );
            }

            $transcription->import_transcription( $current_transcription,
                $seg_start_word_inds->[$unaligned_index] );
            INFO(
"Number of aligned words in the segment/total number of words: $seg_number_of_aligned_words/$seg_total_number_of_words"
            );
            $number_of_aligned_words += $seg_number_of_aligned_words;
            $percentage_of_aligned_words =
              $number_of_aligned_words / $total_number_of_words;

            $index++;
        }
        INFO( "Alignment iteration: $n_align_iterations Alignment percentage: "
              . $percentage_of_aligned_words );
        $transcription->write_to_file(
            catfile(
                $this->{working_dir},
                $signal->{name} . ".iter$n_align_iterations.lab"
            ),
            "lab",
            $this->{output_mode}
        );

        # Identify aligned and unaligned regions to re-iterate
        (
            $seg_start_times,   $seg_end_times, $seg_start_word_inds,
            $seg_end_word_inds, $timed_flags
        ) = $transcription->find_timed_segments($utt_end_time);
    }

    # Write the final transcription file
    $transcription->write_to_file(
        catfile( $this->{working_dir}, $signal->{name} . ".lab" ),
        "lab", "words" );

    # Viterbi-based forced alignment in the end
    if ( $this->{do_forced_word_alignment} ) {

        my $word_align_conf = $this->{word_forced_alignment};
        $word_align_conf->{segmentation_conf}  = $segmentation_conf;
        $word_align_conf->{working_dir}        = $this->{working_dir};
        $word_align_conf->{features_directory} = $this->{features_directory};
        $word_align_conf->{dict_ref}           = \%dict;
        $word_align_conf->{do_adaptation}      = $this->{do_adaptation};
        $word_align_conf->{adaptation}         = $this->{adaptation};
        $word_align_conf->{signal_name}        = $signal->{name};
        $word_align_conf->{n_align_iterations} = $n_align_iterations;
        $word_align_conf->{experiment}         = $this->{experiment};
        $word_align_conf->{format}             = $this->{format};
        $word_align_conf->{adaptation_success} = $adaptation_success;
        $word_align_conf->{ac_model}           = $ac_model;

        forced_alignment( $transcription, $feature_seq, "word",
            $word_align_conf );
    }

    # Viterbi based forced phonetic alignment
    if ( $this->{do_phon_alignment} ) {

        # Phonetic alignment
        my $phon_align_conf = $this->{phon_alignment};
        $phon_align_conf->{segmentation_conf}  = $segmentation_conf;
        $phon_align_conf->{working_dir}        = $this->{working_dir};
        $phon_align_conf->{features_directory} = $this->{features_directory};
        $phon_align_conf->{dict_ref}           = \%dict;
        $phon_align_conf->{do_adaptation}      = $this->{do_adaptation};
        $phon_align_conf->{adaptation}         = $this->{adaptation};
        $phon_align_conf->{signal_name}        = $signal->{name};
        $phon_align_conf->{n_align_iterations} = $n_align_iterations;
        $phon_align_conf->{experiment}         = $this->{experiment};
        $phon_align_conf->{format}             = $this->{format};
        $phon_align_conf->{adaptation_success} = $adaptation_success;
        $phon_align_conf->{ac_model}           = $ac_model;

        forced_alignment( $transcription, $feature_seq, "phone",
            $phon_align_conf );
    }
}

=head2 adapt_to_aligned_segments

Acoustic model adaptation using the aligned regions.

=cut

sub adapt_to_aligned_segments {
    my ( $this, $transcription, $feature_seq, $ac_model, $dict, $align_info,
        $segmentation_configuration )
      = @_;

    # Phonetic alignment to get exact boundaries
    my $timed_flags = $align_info->{timed_flags};
    my @aligned_indices =
      grep { $timed_flags->[$_] > 0 } 0 .. @$timed_flags - 1;

    # Collect the corresponding segments and their transcriptions
    my ( $bname, $tpath, $sfx ) =
      fileparse( $transcription->{file}, "\.[^\.]+" );
    my %align_cfg;
    $align_cfg{suffix}    = $sfx;
    $align_cfg{root_path} = $tpath;
    $align_cfg{format}    = $this->{format};
    my $transcription_set = new SailTools::SailTranscriptionSet( \%align_cfg );

    my $seg_start_times         = $align_info->{seg_start_times};
    my $seg_end_times           = $align_info->{seg_end_times};
    my $seg_start_word_inds     = $align_info->{seg_start_word_inds};
    my $seg_end_word_inds       = $align_info->{seg_end_word_inds};
    my @seg_utt_start_word_inds = @$seg_start_word_inds;
    my @seg_utt_end_word_inds   = @$seg_end_word_inds;
    @seg_utt_start_word_inds = @seg_utt_start_word_inds[@aligned_indices];
    @seg_utt_end_word_inds   = @seg_utt_end_word_inds[@aligned_indices];

    # Transcription is split into a set of transcriptions corresponding to the
    # aligned regions.
    $transcription->split_into_set_given_word_inds( \@seg_utt_start_word_inds,
        \@seg_utt_end_word_inds, $transcription_set );
    my @seg_utt_start_times_arr = @$seg_start_times;
    my @seg_utt_end_times_arr   = @$seg_end_times;
    @seg_utt_start_times_arr = @seg_utt_start_times_arr[@aligned_indices];
    @seg_utt_end_times_arr   = @seg_utt_end_times_arr[@aligned_indices];
    my $segmentation_output_dir =
      $segmentation_configuration->{segmentation_output_dir};
    my $segmentation_output_list =
      $segmentation_configuration->{segmentation_output_list};
    my $segmentation_script =
      $segmentation_configuration->{segmentation_script};

    # The corresponding acoustic features are segmented out from the original
    # acoustic feature sequence
    my $segmentation_conf = $segmentation_configuration->{segmentation_conf};
    my $seg_feature_set   = SailTools::SailSegment::segment_features(
        $feature_seq,              $segmentation_output_dir,
        $segmentation_output_list, $segmentation_script,
        $segmentation_conf,        \@seg_utt_start_times_arr,
        \@seg_utt_end_times_arr
    );

    my $n_aligned_segments = @seg_utt_start_times_arr;
    DEBUG(
        "Number of segments to be checked for adaptation: $n_aligned_segments");

    # Phonetic alignment using hvite
    mkpath( $this->{adaptation}->{path} );
    my $adapt_alignment_cfg = $this->{adaptation}->{alignment};
    $adapt_alignment_cfg->{adaptation} = $this->{adaptation};
    my $phone_alignment_info = $adapt_alignment_cfg->{mlf};
    $transcription_set->{root_path} = $adapt_alignment_cfg->{transcription_dir};
    $seg_feature_set->write_list_of_files_abs_path(
        $this->{adaptation}->{file_list} );
    $seg_feature_set->{list_abs_paths} = $this->{adaptation}->{file_list};

    # Viterbi-based forced alignment
    SailTools::SailAdaptation::align_speech_feature_set( $seg_feature_set,
        $transcription_set, $phone_alignment_info, $ac_model, $dict,
        $adapt_alignment_cfg );

    # Check if all the files have a corresponding alignment. Leave out those
    # for which alignment has failed.
    my $seg_files_ref = SailTools::SailComponent::read_from_file(
        $this->{adaptation}->{file_list} );
    my $mlf_files_ref = SailTools::SailTranscriptionSet::find_files_in_mlf(
        $adapt_alignment_cfg->{mlf} );
    my @correctly_aligned_seg_files = ();
    foreach my $seg_file (@$seg_files_ref) {
        my ( $base_name, $s_path, $sfx ) = fileparse( $seg_file, "\.[^\.]+" );
        if ( grep { /$base_name/ } @$mlf_files_ref ) {
            push( @correctly_aligned_seg_files, $seg_file );
        }
    }
    $n_aligned_segments = @correctly_aligned_seg_files;
    SailTools::SailComponent::print_into_file( \@correctly_aligned_seg_files,
        $this->{adaptation}->{file_list} );

    DEBUG(
        "Number of aligned segments used for adaptation: $n_aligned_segments");

    # Perform two-step adaptation
    my $orig_acoustic_models = $this->{adaptation}->{src_acoustic_models};

    # Two-step MLLR adaptation
    my $adaptation_success =
      SailTools::SailAdaptation::adaptation( $orig_acoustic_models,
        $this->{adaptation} );
    return $adaptation_success;
}

=head2 forced_alignment

Forced alignment
Input: Transcription (word-level)
Output: 

=cut

sub forced_alignment {
    my ( $transcription, $feature_seq, $mode, $align_conf ) = @_;

    DEBUG("Forced $mode alignment started.");

    # Collect the corresponding segments and their transcriptions
    my ( $bname, $tpath, $sfx ) =
      fileparse( $transcription->{file}, "\.[^\.]+" );
    my %align_cfg;
    $align_cfg{suffix}    = $sfx;
    $align_cfg{root_path} = $tpath;
    $align_cfg{format}    = $align_conf->{format};
    my $transcription_set = new SailTools::SailTranscriptionSet( \%align_cfg );

    # First split the original transcription into long segments
    my (
        $utterances_start_times_ref, $utterances_end_times_ref,
        $utt_start_word_inds_ref,    $utt_end_word_inds_ref
    ) = $transcription->split_into_utterances( $align_conf->{utt_duration} );

    my $utt_ids_ref =
      $transcription->split_into_set_given_word_inds_times(
        $utt_start_word_inds_ref, $utt_end_word_inds_ref, $transcription_set );

    # Split the features into segments
    my $segmentation_output_dir =
      catfile( $align_conf->{features_directory}, $feature_seq->{name} );
    mkpath($segmentation_output_dir);
    my $segmentation_script = catfile( $align_conf->{working_dir},
            $feature_seq->{name} . '.'
          . $align_conf->{segmentation_conf}->{'cut_file_suffix'} );
    my $segmentation_output_list = catfile( $align_conf->{working_dir},
            $feature_seq->{name} . '.'
          . $align_conf->{segmentation_conf}->{'segment_list_suffix'} );

    my $utt_feature_set = SailTools::SailSegment::segment_features_given_ids(
        $feature_seq,                     $segmentation_output_dir,
        $segmentation_output_list,        $segmentation_script,
        $align_conf->{segmentation_conf}, $utterances_start_times_ref,
        $utterances_end_times_ref,        $utt_ids_ref
    );

    # Phonetically align the segments
    mkpath( $align_conf->{dir} );
    my $alignment_info = $align_conf->{mlf};
    $transcription_set->{root_path} = $align_conf->{dir};
    $utt_feature_set->write_list_of_files_abs_path( $align_conf->{file_list} );
    $utt_feature_set->{list_abs_paths} = $align_conf->{file_list};
    if ( $align_conf->{do_adaptation} && $align_conf->{adaptation_success} ) {
        $align_conf->{use_adapted_models} = 1;
        DEBUG(
            "Adapted acoustic models are used for the forced $mode alignment");
    }

    SailTools::SailAdaptation::align_speech_feature_set(
        $utt_feature_set, $transcription_set, $alignment_info,
        $align_conf->{ac_model},
        $align_conf->{dict_ref}, $align_conf
    );

    # Check if all the files have a corresponding alignment
    my $utt_files_ref =
      SailTools::SailComponent::read_from_file( $align_conf->{file_list} );
    my $aligned_utts_set =
      SailTools::SailTranscriptionSet::read_mlf( $align_conf->{mlf} );

    my @correctly_aligned_utt_files = ();
    my $align_file;
    if ( $mode =~ "word" ) {
        $align_file = catfile( $align_conf->{working_dir},
            $align_conf->{signal_name} . ".forced.wrd" );

    }
    elsif ( $mode =~ "phone" ) {
        $align_file = catfile( $align_conf->{working_dir},
            $align_conf->{signal_name} . ".forced.phn" );
    }
    my $n_utt_files            = @$utt_files_ref;
    my $aligned_utts_set_files = $aligned_utts_set->{files};
    if ( !defined $aligned_utts_set_files ) {
        INFO("Forced $mode-level alignment has failed");
    }
    else {

        my $n_aligned_files = @$aligned_utts_set_files;
        my @start_offset;

        for (
            my $utt_counter = 0 ;
            $utt_counter < $n_utt_files ;
            $utt_counter++
          )
        {
            my $utt_file =
              $transcription_set->{transcriptions}->[$utt_counter]->{file};
            my ( $base_name, $s_path, $sfx ) =
              fileparse( $utt_file, "\.[^\.]+" );
            my ($index) =
              grep { $aligned_utts_set_files->[$_] =~ /\Q$base_name\E/ }
              0 .. $n_aligned_files - 1;

            if ( defined($index) ) {
                $transcription_set->{transcriptions}->[$utt_counter] =
                  $aligned_utts_set->{transcriptions}->[$index];
            }
            else {
                DEBUG("Unaligned segment found: $utt_file");
            }
            push( @start_offset, $utterances_start_times_ref->[$utt_counter] );
        }

        my $transcription =
          new SailTools::SailTranscription( $align_file,
            $align_conf->{experiment} );
        $transcription->init_from_set( $transcription_set,
            $transcription_set->{files},
            \@start_offset );
        if ( $mode =~ "word" ) {
            $transcription->write_to_file( $align_file, "lab", "words" );
        }
        elsif ( $mode =~ "phone" ) {

            # Convert phonetic transcription from a triphone to a monophone one
            SailTools::SailLanguage::convert_triphone_transcription_to_monophone(
                $transcription);
            DEBUG( $transcription->{words}->[2] );
            if ( $align_conf->{dict_ref}->{apply_phone_map} ) {
                SailTools::SailLanguage::convert_transcription_phoneset(
                    $transcription,
                    $align_conf->{dict_ref}->{phone_map_inverse} );
            }
            $transcription->write_to_file( $align_file, "lab", "words" );
        }
    }
}

=head1 AUTHOR

Athanasios Katsamanis, C<< <nkatsam at sipi.usc.edu> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-sailalign at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=SailAlign>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc SailTools::AlignSpeech


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=SailAlign>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/SailAlign>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/SailAlign>

=item * Search CPAN

L<http://search.cpan.org/dist/SailAlign/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2010 Athanasios Katsamanis.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; version 2 dated June, 1991 or at your option
any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

A copy of the GNU General Public License is available in the source tree;
if not, write to the Free Software Foundation, Inc.,
59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.


=cut

1;    # End of SailTools::AlignSpeech

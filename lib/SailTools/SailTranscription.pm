package SailTools::SailTranscription;

use warnings;
use strict;
use Log::Log4perl qw(:easy);
use File::Path;
use File::Basename;
use File::Spec::Functions;
use Data::Dumper;
use SailTools::SailComponent;

=head1 NAME

SailTools::SailTranscription - The great new SailTools::SailTranscription!

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.10';

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use SailTools::SailTranscription;

    my $foo = SailTools::SailTranscription->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 new

New transcription object.
Usage:
  my $sail_transcription = new SailTools::SailTranscription( $file_name, \%setup );

=cut

sub new {
    my $class = shift;
    my $self;

    # Basic members
    $self->{file}              = '';
    $self->{name}              = '';
    $self->{voice_activity}    = '';
    $self->{words}             = ();
    $self->{original_words}    = ();
    $self->{speakers}          = ();
    $self->{utterances}        = ();
    $self->{n_utterances}      = 0;
    $self->{speaker_labels}    = ();
    $self->{voice_labels}      = ();
    $self->{phonemes}          = ();
    $self->{phoneset}          = ();
    $self->{timing}            = ();
    $self->{start_times}       = ();
    $self->{end_times}         = ();
    $self->{uncertainties}     = ();
    $self->{format}            = '';
    $self->{path}              = '';
    $self->{lab_time_constant} = 10**7;
    $self->{duration}          = 0;

    if ( @_ >= 1 ) {
        my $file_name = $_[0];
        $self->{file} = $file_name;
    }
    else {
        FATAL("Cannot initialize transcription object without filename.");
    }
    my $configuration;
    if ( @_ >= 2 ) {
        my $experiment = $_[1];
        $self->{experiment} = $experiment;
        my $global_cfg = $experiment->{cfg};
        $configuration = $global_cfg->{text};
    }
    elsif ( @_ >= 3 ) {
        $configuration = $_[2];
    }
    if ($configuration) {
        $self->{format}         = $configuration->{format};
        $self->{speaker_labels} = $configuration->{speaker_labels};
        $self->{voice_labels}   = $configuration->{voice_labels};
    }
    bless( $self, $class );

    my ( $name, $path, $sfx ) = fileparse( $self->{file}, '\.[^\.]*' );
    $self->{name} = $name;
    $self->{path} = $path;

    if ( !( $self->{format} ) ) {
        $self->{format} = $self->set_format_from_suffix($sfx);
    }

    return $self;
}

=head2 get_n_words

Get the number of words in the transcription
Usage:
  my $n_words = $sail_transcription->get_n_words;

=cut

sub get_n_words {
    my $this     = shift;
    my $word_ref = $this->{words};
    my $n_words  = @$word_ref;
    return $n_words;
}

=head2 get_clean_words

Get the clean words in the transcription
Usage:
  my $words_ref = $sail_transcription->get_clean_words;

=cut

sub get_clean_words {
    my $this     = shift;
    my $word_ref = $this->{words};
    my $n_words  = @$word_ref;

    for (my $k=0; $k<$n_words; $k++) {
           $word_ref->[$k] =~ s/[\?\;,\.\:]+//;
           $word_ref->[$k] = lc($word_ref->[$k]);
    }

    return $word_ref;
}





=head2 add_offset

Add a temporal offset to each entry of the transcription
Input: The temporal offset to be added
Usage:
  $sail_transcription->add_offset($offset);

=cut

sub add_offset {
    my ( $this, $start_time ) = @_;

    my $start_times_ref = $this->{start_times};
    my $end_times_ref   = $this->{end_times};
    my $n_segments      = @$start_times_ref;

    for (
        my $segment_counter = 0 ;
        $segment_counter < $n_segments ;
        $segment_counter++
      )
    {
        if ( $start_times_ref->[$segment_counter] > -1 ) {
            $start_times_ref->[$segment_counter] += $start_time;
            $end_times_ref->[$segment_counter]   += $start_time;
        }
    }
}

=head2 set_name

Set the name of the transcription object.
Usage:
  $sail_transcription->set_name("test");

=cut

sub set_name {
    my ( $this, $name ) = @_;

    $this->{name} = $name;
}

=head2 set_speaker_labels

Set the speaker labels that are expected for
the specific transcription.
Input: Reference to a list of speaker labels

Usage:
  my @speaker_labels = ['H', 'W'];
  $sail_transcription->set_speaker_labels(\@speaker_labels);

=cut

sub set_speaker_labels {
    my ( $this, $speaker_labels_ref ) = @_;

    $this->{speakers_labels} = $speaker_labels_ref;
}

=head2 import_transcription

Import a segmental transcription at a specific point in the original transcription
Input: The segmental transcription, the index of the word at which it should be added
Usage:
  $sail_transcription->import_transcription( $sail_seg_transcription, $word_index );

=cut

sub import_transcription {
    my ( $this, $seg_transcription, $word_ind ) = @_;

    my $words_ref     = $this->{words};
    my $seg_words_ref = $seg_transcription->{words};
    my $n_seg_words   = @$seg_words_ref;

    for (
        my $seg_word_counter = 0 ;
        $seg_word_counter < $n_seg_words ;
        $seg_word_counter++
      )
    {
        my $orig_trans_counter = $word_ind + $seg_word_counter;
        $words_ref->[$orig_trans_counter] = $seg_words_ref->[$seg_word_counter];
        $this->{start_times}->[$orig_trans_counter] =
          $seg_transcription->{start_times}->[$seg_word_counter];
        $this->{end_times}->[$orig_trans_counter] =
          $seg_transcription->{end_times}->[$seg_word_counter];
        $this->{uncertainties}->[$orig_trans_counter] =
          $seg_transcription->{uncertainties}->[$seg_word_counter];
    }
}

=head2 find_untimed_words

Find all untimed words
Usage:
  ($n_untimed_words, $n_words) = $sail_transcription->find_untimed_words;

=cut

sub find_untimed_words {
    my $this    = shift;
    my $wordref = $this->{words};
    my $n_words = @$wordref;

    my $trans_start_times_ref = $this->{start_times};

    my @untimed_word_inds = grep { $_ == -1 } @$trans_start_times_ref;
    my $n_untimed_words = @untimed_word_inds;

    return ( $n_untimed_words, $n_words );
}

=head2 find_timed_segments 

Look for segments that are untimed, i.e., the corresponding start time is equal to -1
Input: 
Output: Return the start times, the end times, the starting word index, 
  the ending word index, and the indices of the untimed segments.
Usage: 
  ( $segment_start_times_ref, $segment_end_times_ref, $start_word_inds_ref, $end_word_inds_ref, $time_flags_ref) =
              $sail_transcription->find_timed_segments($end_time);
=cut

sub find_timed_segments {
    my ( $this, $end_time ) = @_;
    my @seg_start_times = ();
    my @seg_end_times   = ();
    my @start_word_ind  = ();
    my @end_word_ind    = ();
    my @timed_flags     = ();

    my $wordref = $this->{words};
    my $n_words = @$wordref;

    my $trans_start_times_ref = $this->{start_times};
    my $trans_end_times_ref   = $this->{end_times};

    my $n_starts = @$trans_start_times_ref;
    my $n_ends   = @$trans_end_times_ref;

    my $current_seg_start_time = -1;
    my $current_start_word_ind = -1;
    my $current_seg_end_time   = -1;
    my $current_seg_timed      = 0;
    for ( my $word_counter = 0 ; $word_counter < $n_words ; $word_counter++ ) {
        my $current_start_time = $this->{start_times}->[$word_counter];
        my $current_end_time   = $this->{end_times}->[$word_counter];

        if ( $current_seg_start_time == -1 ) {
            if ( $current_start_time == -1 ) {
                $current_seg_start_time = 0;
                $current_seg_timed      = 0;
                $current_seg_end_time   = 0;
            }
            else {
                $current_seg_start_time = $current_start_time;
                $current_seg_end_time   = $current_end_time;
                $current_seg_timed      = 1;
            }
            $current_start_word_ind = $word_counter;
            push( @seg_start_times, $current_seg_start_time );
            push( @start_word_ind,  $current_start_word_ind );
            push( @end_word_ind,    $current_start_word_ind );
            push( @timed_flags,     $current_seg_timed );
            push( @seg_end_times,   $current_end_time );
        }
        else {
            if ( $current_start_time == -1 ) {
                if ($current_seg_timed) {
                    $current_seg_timed      = 0;
                    $current_seg_start_time = $current_seg_end_time;
                    $current_seg_end_time   = $end_time;
                    $current_start_word_ind = $word_counter;
                    push( @seg_start_times, $current_seg_start_time );
                    push( @seg_end_times,   $current_seg_end_time );
                    push( @start_word_ind,  $current_start_word_ind );
                    push( @end_word_ind,    $current_start_word_ind );
                    push( @timed_flags,     $current_seg_timed );
                }
                else {
                    $end_word_ind[$#end_word_ind] = $word_counter;
                }
            }
            else {
                if ($current_seg_timed) {
                    $end_word_ind[$#end_word_ind]   = $word_counter;
                    $seg_end_times[$#seg_end_times] = $current_end_time;
                    $current_seg_end_time           = $current_end_time;
                }
                else {
                    $current_seg_timed              = 1;
                    $seg_end_times[$#seg_end_times] = $current_start_time;
                    $current_seg_start_time         = $current_start_time;
                    $current_seg_end_time           = $current_end_time;
                    $current_start_word_ind         = $word_counter;
                    push( @seg_start_times, $current_seg_start_time );
                    push( @seg_end_times,   $current_seg_end_time );
                    push( @start_word_ind,  $current_start_word_ind );
                    push( @end_word_ind,    $current_start_word_ind );
                    push( @timed_flags,     $current_seg_timed );
                }
            }
        }

    }
    return (
        \@seg_start_times, \@seg_end_times, \@start_word_ind,
        \@end_word_ind,    \@timed_flags
    );
}

=head2 split_into_set_given_word_inds

Split the transcription into a set of transcriptions at the given word indices
Input: Start word index and end word index
Output: The set of transcriptions.
Usage:
  $segment_ids_ref = $sail_transcription->split_into_set_given_word_inds ( \@seg_start_word_inds,
                                                \@seg_end_word_inds, $transcription_set_object_ref );
=cut

sub split_into_set_given_word_inds {
    my ( $this, $seg_start_word_inds, $seg_end_word_inds, $transcription_set ) =
      @_;

    my $n_segments = @$seg_start_word_inds;
    my ( $bname, $tpath, $sfx ) = fileparse( $this->{file}, "\.[^\.]+" );
    my $word_ref = $this->{words};
    my @words    = @$word_ref;

    for ( my $seg_counter = 0 ; $seg_counter < $n_segments ; $seg_counter++ ) {
        my $current_start_word_ind = $seg_start_word_inds->[$seg_counter];
        my $current_end_word_ind   = $seg_end_word_inds->[$seg_counter];
        my $seg_id     = "$current_start_word_ind-$current_end_word_ind";
        my $trans_file = catfile( $tpath, "$bname.$seg_id.$sfx" );
        my $trans      = new SailTools::SailTranscription($trans_file);

        my @inds        = ( $current_start_word_ind .. $current_end_word_ind );
        my @word_subset = @words[@inds];

        $trans->set_words( \@word_subset );
        $transcription_set->push_trans($trans);
    }
}

=head2 split_into_set_given_word_inds_times 

Split the transcription into a set of transcriptions at the given word indices, 
provide starting and ending times as well.
Input: Start word index and end word index
Output: The set of transcriptions.
Usage:
  $segment_ids_ref = $sail_transcription->split_into_set_given_word_inds_times ( \@seg_start_word_inds,
                                                \@seg_end_word_inds, $transcription_set_object_ref );

=cut

sub split_into_set_given_word_inds_times {
    my ( $this, $seg_start_word_inds, $seg_end_word_inds, $transcription_set ) =
      @_;

    my $n_segments = @$seg_start_word_inds;
    my ( $bname, $tpath, $sfx ) = fileparse( $this->{file}, "\.[^\.]+" );
    my $word_ref        = $this->{words};
    my @words           = @$word_ref;
    my $start_times_ref = $this->{start_times};
    my $end_times_ref   = $this->{end_times};
    my @start_times     = @$start_times_ref;
    my @end_times       = @$end_times_ref;
    my @segment_ids     = ();
    $sfx =~ s/\.//;

    for ( my $seg_counter = 0 ; $seg_counter < $n_segments ; $seg_counter++ ) {
        my $current_start_word_ind = $seg_start_word_inds->[$seg_counter];
        my $current_end_word_ind   = $seg_end_word_inds->[$seg_counter];
        my $seg_id = "$current_start_word_ind-$current_end_word_ind";
        push( @segment_ids, $seg_id );
        my $trans_file = catfile( $tpath, "$bname.$seg_id." . $sfx );
        my $trans = new SailTools::SailTranscription($trans_file);

        my @inds        = ( $current_start_word_ind .. $current_end_word_ind );
        my @word_subset = @words[@inds];
        my @start_times_subset = @start_times[@inds];
        my @end_times_subset   = @end_times[@inds];

        $trans->set_words( \@word_subset );

        my $seg_start_time = $start_times_subset[0];
        if ( $seg_start_time >= 0 ) {
            SailTools::SailComponent::sum_array_and_scalar(
                \@start_times_subset, -$seg_start_time );
            SailTools::SailComponent::sum_array_and_scalar( \@end_times_subset,
                -$seg_start_time );
        }

        # First remove
        $trans->{start_times} = \@start_times_subset;
        $trans->{end_times}   = \@end_times_subset;
        $transcription_set->push_trans($trans);
    }
    return ( \@segment_ids );
}

=head2 init_from_set

Initialize a transcription by concatenating a set of transcriptions
Input: The set of transcriptions, the list of transcription files to be used,
	start times, end times
Usage:
  $sail_transcription ( $transcription_set_object_ref, $file_list, $start_offset_list_ref, $end_offset_list_ref );

=cut

sub init_from_set {
    my ( $this, $set, $files, $start_offset, $end_offset ) = @_;

    my $set_files     = $set->get_files;
    my @set_files_arr = @$set_files;
    my $n_set_files   = @$set_files;
    my @start_times;
    my @end_times;
    my @uncertainties = ();
    my @words;
    my $uncertainties_defined = 1;

    foreach my $ifile (@$files) {

        my @matching_inds =
          grep { $ifile =~ /^\Q$set_files_arr[$_]\E$/ }
          0 .. ( $n_set_files - 1 );
        if ( @matching_inds > 1 ) {
            FATAL("Unexpected number of files found: $ifile");
        }
        else {
            my $file_ind            = $matching_inds[0];
            my $trans               = $set->{transcriptions}->[$file_ind];
            my $trans_words         = $trans->{words};
            my $n_words             = 0;
            my $trans_start_times   = 0;
            my $trans_end_times     = 0;
            my @empty_arr           = ();
            my $trans_uncertainties = \@empty_arr;
            if ( defined $trans_words ) {
                $n_words = @$trans_words;
                push( @words, @$trans_words );
                $trans_start_times   = $trans->{start_times};
                $trans_end_times     = $trans->{end_times};
                $trans_uncertainties = $trans->{uncertainties};
            }

            # Add the offset, given that the segments are not
            # consecutive
            for (
                my $word_counter = 0 ;
                $word_counter < $n_words ;
                $word_counter++
              )
            {
                if ( $trans_start_times->[$word_counter] > -1 ) {
                    push( @start_times,
                        $trans_start_times->[$word_counter] +
                          $start_offset->[$file_ind] );
                    push( @end_times,
                        $trans_end_times->[$word_counter] +
                          $start_offset->[$file_ind] );
                }
                else {
                    push( @start_times, -1 );
                    push( @end_times,   -1 );
                }
                if ( @$trans_uncertainties > $word_counter ) {
                    push( @uncertainties,
                        $trans_uncertainties->[$word_counter] +
                          $start_offset->[$file_ind] );
                }
            }
        }
    }
    $this->{words}         = \@words;
    $this->{start_times}   = \@start_times;
    $this->{end_times}     = \@end_times;
    $this->{uncertainties} = \@uncertainties;

}

=head2 format_from_suffix

Get the transcription file format from the suffix
Usage:
  $format = format_from_suffix ("lab");

=cut

sub format_from_suffix {
    my $suffix = shift;
    my $format;

    if ( $suffix =~ m/(lab|rec)/i ) {
        $format = 'lab';
    }
    elsif ( $suffix =~ m/txt/i ) {
        $format = 'txt_no_times';
    }
    return $format;
}

=head2 set_format_from_suffix

Set the transcription object's format from the suffix of the file name
Usage:
  $sail_transcription->format_from_suffix("lab");

=cut

sub set_format_from_suffix {
    my ( $this, $suffix ) = @_;
    $this->{format} = format_from_suffix($suffix);
}

=head2 split_into_utterances

Split into utterances of a certain duration
Usage:
  ($start_times_ref, $end_times_ref, $start_word_inds_ref, $end_word_inds_ref) = 
      $sail_transcription->split_into_utterances ( $max_duration );
=cut

sub split_into_utterances {
    my ( $this, $max_duration ) = @_;

    my $start_times_ref = $this->{start_times};
    my $end_times_ref   = $this->{end_times};
    my $words_ref       = $this->{words};

    my @utt_start_times     = ();
    my @utt_end_times       = ();
    my @utt_start_word_inds = ();
    my @utt_end_word_inds   = ();
    my $n_words             = @$words_ref;

    my $utt_s_time              = 0;
    my $utt_e_time              = 0;
    my $first_segment           = 1;
    my $last_valid_word_counter = -1;
    for ( my $word_counter = 0 ; $word_counter < $n_words ; $word_counter++ ) {
        my $s_time   = $start_times_ref->[$word_counter];
        my $e_time   = $end_times_ref->[$word_counter];
        my $cur_word = $words_ref->[$word_counter];
        $last_valid_word_counter = $word_counter;

        if ($first_segment) {
            if ( $s_time == -1 ) {
                WARN("Problematic beginning of a segment. Skipping.");
            }
            if ( $s_time == -1 ) {
                if ( $utt_s_time > 0 ) {
                    $utt_s_time = $utt_e_time;
                }
                else {
                    $utt_s_time = 0;
                }
            }
            else {
                $utt_s_time = $s_time;
            }
            push( @utt_start_word_inds, $word_counter );
            $first_segment = 0;
        }
        if ( $e_time == -1 ) {
            $e_time     = $this->{duration};
            $utt_e_time = $e_time;
            next;
        }
        $utt_e_time = $e_time;
        my $duration = $e_time - $utt_s_time;
        if ( $duration < $max_duration ) {
            next;
        }
        else {
            push( @utt_end_word_inds, $word_counter );
            push( @utt_start_times,   $utt_s_time );
            push( @utt_end_times,     $utt_e_time );
            $first_segment = 1;
        }
    }
    if ( $first_segment == 0 ) {
        push( @utt_start_times,   $utt_s_time );
        push( @utt_end_times,     $utt_e_time );
        push( @utt_end_word_inds, $last_valid_word_counter );
    }

    my $n_utterances = @utt_start_times;
    INFO("$n_utterances utterances have been found in split_into_utterances.");
    return (
        \@utt_start_times,     \@utt_end_times,
        \@utt_start_word_inds, \@utt_end_word_inds
    );
}

=head2 concatenate_segments

Concatenate segments of a transcription into larger segments of a maximum duration.
Usage:
  $sail_transcription->concatenate_segments ($max_duration, $start_time, $end_time );

=cut

sub concatenate_segments {
    my ( $this, $max_duration, $start_time, $end_time ) = @_;

    my $start_times_ref = $this->{start_times};
    my $end_times_ref   = $this->{end_times};
    my $voice_ref       = $this->{'voice_activity'};

    if ( @_ < 4 ) {
        my $n_times = @$start_times_ref;
        $start_time = $start_times_ref->[0];
        $end_time   = $end_times_ref->[ $n_times - 1 ];
    }

    my @voice           = @$voice_ref;
    my @utt_start_times = ();
    my @utt_end_times   = ();

    my $n_segments           = @voice;
    my $utterance_duration   = 0;
    my $in_specified_segment = 0;
    for (
        my $segment_counter = 0 ;
        $segment_counter < $n_segments ;
        $segment_counter++
      )
    {
        my $segment_start = $start_times_ref->[$segment_counter];
        my $segment_end   = $end_times_ref->[$segment_counter];

        if (   ( $segment_start >= $start_time )
            && ( $segment_end <= $end_time ) )
        {
            if ( !$in_specified_segment ) {
                $segment_start        = $start_time;
                $in_specified_segment = 1;
            }
            if ( $utterance_duration == 0 ) {
                push( @utt_start_times, $segment_start );
                push( @utt_end_times,   $segment_end );
            }
            my $segment_duration = $segment_end - $segment_start;
            $utterance_duration += $segment_duration;
            $utt_end_times[$#utt_start_times] = $segment_end;
            if ( $utterance_duration > $max_duration ) {
                $utterance_duration = 0;
            }
        }
        elsif ( $segment_end > $end_time ) {
            if (@utt_end_times) {
                $utt_end_times[$#utt_end_times] = $end_time;
            }
            else {
                $utt_start_times[0] = $start_time;
                $utt_end_times[0]   = $end_time;
            }
        }
    }
    return ( \@utt_start_times, \@utt_end_times );
}

=head2 init_from_file

Initialize transcription from file
Input: transcription file, $format
Usage:
  $sail_transcription->init_from_file($transcription_file, $format);
=cut

sub init_from_file {
    my ( $this, $trans_file, $format ) = @_;

    my ( $name, $path, $sfx ) = fileparse( $trans_file, '\.[^\.]*' );

    if ( @_ < 3 ) {
        $format = format_from_suffix($sfx);
    }

    my %trans_file_hash = ();
    $trans_file_hash{'name'}   = $trans_file;
    $trans_file_hash{'format'} = $format;

    $this->set_from_file( \%trans_file_hash );
}

=head2 read_from_file

Read transcription from file.
Input: transcription file hash with name and format as fields
Output: reference to lists of words and speakers (if present)
Usage:
  $sail_transcription->read_from_file( $transcription_file );

=cut

sub read_from_file {
    my ( $this, $trans_file ) = @_;
    my ( $words_ref,       $speakers_ref );
    my ( $start_times_ref, $end_times_ref );
    my $uncertainties_ref;

    my $format = $trans_file->{format};

    if ( !-e $trans_file->{name} ) {
        my $file_name = $trans_file->{name};
        DEBUG("File $file_name not found. Transcription initialized as empty.");
        my @words    = ();
        my @speakers = ();
        $words_ref    = \@words;
        $speakers_ref = \@speakers;
    }
    elsif ( $format eq 'speaker_per_line_no_times' ) { # Speaker per line format
        ( $words_ref, $speakers_ref ) = $this->read_from_spl_file($trans_file);
        my $n_words = @$words_ref;

        my @start_times   = ();
        my @end_times     = ();
        my @uncertainties = ();
        for ( my $k = 0 ; $k < $n_words ; $k++ ) {
            push( @start_times,   -1 );
            push( @end_times,     -1 );
            push( @uncertainties, 0 );
        }
        $start_times_ref   = \@start_times;
        $end_times_ref     = \@end_times;
        $uncertainties_ref = \@uncertainties;
    }
    elsif ( $format eq 'txt_no_times' ) {
        $words_ref = $this->read_from_txt_file($trans_file);
        my @speakers = ();
        $speakers_ref = \@speakers;
        my $n_words       = @$words_ref;
        my @start_times   = ();
        my @end_times     = ();
        my @uncertainties = ();
        for ( my $k = 0 ; $k < $n_words ; $k++ ) {
            push( @start_times,   -1 );
            push( @end_times,     -1 );
            push( @uncertainties, 0 );
        }
        $start_times_ref   = \@start_times;
        $end_times_ref     = \@end_times;
        $uncertainties_ref = \@uncertainties;
    }
    elsif ( $format eq 'lab' ) {
        ( $words_ref, $start_times_ref, $end_times_ref ) =
          $this->read_from_lab_file($trans_file);
        $speakers_ref = 0;
        my $n_words       = @$words_ref;
        my @uncertainties = ();
        for ( my $k = 0 ; $k < $n_words ; $k++ ) {
            push( @uncertainties, 0 );
        }
        $uncertainties_ref = \@uncertainties;
    }
    elsif ( $format eq 'lab_speakers_uncertainties' ) {
        (
            $words_ref,    $start_times_ref, $end_times_ref,
            $speakers_ref, $uncertainties_ref
        ) = $this->read_from_lab_speakers_uncertainties_file($trans_file);
    }
    elsif ( $format eq 'trs' ) {
        ( $words_ref, $start_times_ref, $end_times_ref ) =
          $this->read_from_trs_file($trans_file);
        DEBUG("Have read trs file");
        $speakers_ref = 0;
        my $n_words       = @$words_ref;
        my @uncertainties = ();
        for ( my $k = 0 ; $k < $n_words ; $k++ ) {
            push( @uncertainties, 0 );
        }
    }
    else {
        ERROR("This transcription file format is not supported.\n");
    }
    return (
        $words_ref,     $speakers_ref, $start_times_ref,
        $end_times_ref, $uncertainties_ref
    );
}

=head2 set_from_file

Set object's properties from file
Input: transcription file hash with name and format as fields
Usage: 
  $sail_transcription->set_from_file($transcription_file);

=cut

sub set_from_file {
    my ( $this, $trans_file ) = @_;
    my ( $words_ref, $speakers_ref, $start_times, $end_times, $uncertainties ) =
      $this->read_from_file($trans_file);

    $this->{words}         = $words_ref;
    $this->{speakers}      = $speakers_ref;
    $this->{start_times}   = $start_times;
    $this->{end_times}     = $end_times;
    $this->{uncertainties} = $uncertainties;
}

=head2 read_from_spl_file

Read from file in which each speaker turn is written in a separate line
Input: Hash with filename and format as fields
Output: sequence of words, sequence of speaker_ids, sequence of utterance_ids
Usage:
  ($file_words_ref, $file_speakers_ref, $file_utterances_ref) = $sail_transcription->read_from_spl_file ($transcription_file);

=cut

sub read_from_spl_file {
    my ( $this, $trans_file ) = @_;

    my $file_name       = $trans_file->{name};
    my $format          = $trans_file->{format};
    my @file_words      = ();
    my @file_speakers   = ();
    my @file_utterances = ();

    open( TRANS, $file_name ) || FATAL("Cannot read file $file_name");

    my $utt_index = 0;
    while (<TRANS>) {
        chomp;
        my $line = $_;

        my ( $speaker, $line_words_ref ) = read_spl_line($line);
        my $n_words = @$line_words_ref;
        my @line_speakers = ( ($speaker) x $n_words );
        $utt_index++;
        my @line_utterances = ( ($utt_index) x $n_words );
        push( @file_words,      @$line_words_ref );
        push( @file_speakers,   @line_speakers );
        push( @file_utterances, @line_utterances );
    }
    close(TRANS);

    return ( \@file_words, \@file_speakers, \@file_utterances );
}

=head2 read_from_lab_file

Read from file which is in the well-known HTK lab format
Input: Hash with filename and format as fields
Output: sequence of words, sequence of utterance_ids
Usage:
  $sail_transcription->read_from_lab_file( $transcription_file );

=cut

sub read_from_lab_file {
    my ( $this, $trans_file ) = @_;

    my $file_name        = $trans_file->{name};
    my $format           = $trans_file->{format};
    my @file_words       = ();
    my @file_start_times = ();
    my @file_end_times   = ();
    my @file_speakers    = ();

    open( TRANS, $file_name ) || FATAL("Cannot read file $file_name");

    my $utt_index = 0;
    while (<TRANS>) {
        chomp;
        my $line = $_;

        my ( $line_words_ref, $start_time, $end_time ) =
          read_lab_line( $line, $this->{lab_time_constant} );
        my @line_words = @$line_words_ref;
        my $n_words    = @line_words;

        if ( $n_words > 1 ) {
            foreach my $l_word (@line_words) {
                push( @file_words,       $l_word );
                push( @file_start_times, -1 );
                push( @file_end_times,   -1 );
            }
        }
        else {
            push( @file_words,       @$line_words_ref );
            push( @file_start_times, $start_time );
            push( @file_end_times,   $end_time );
        }
    }
    close(TRANS);

    return ( \@file_words, \@file_start_times, \@file_end_times );
}

=head2 read_from_lab_speakers_uncertainties_file

Read from file which is in the well-known HTK lab format
Input: Hash with filename and format as fields
Output: sequence of words, sequences of start and end times, 
        sequence of speakers, sequences of corresponding alignment uncertainties
Usage:
  $sail_transcription->read_from_lab_speakers_uncertainties_file( $transcription_file );

=cut

sub read_from_lab_speakers_uncertainties_file {
    my ( $this, $trans_file ) = @_;

    my $file_name          = $trans_file->{name};
    my $format             = $trans_file->{format};
    my @file_words         = ();
    my @file_start_times   = ();
    my @file_end_times     = ();
    my @file_speakers      = ();
    my @file_uncertainties = ();

    open( TRANS, $file_name ) || FATAL("Cannot read file $file_name");

    my $utt_index = 0;
    while (<TRANS>) {
        chomp;
        my $line = $_;

        my ( $line_words_ref, $start_time, $end_time, $speaker, $uncertainty ) =
          read_lab_speaker_uncertainty_line( $line,
            $this->{lab_time_constant} );
        my @line_words = @$line_words_ref;
        my $n_words    = @line_words;

        if ( $n_words > 1 ) {
            foreach my $l_word (@line_words) {
                push( @file_words,         $l_word );
                push( @file_start_times,   -1 );
                push( @file_end_times,     -1 );
                push( @file_speakers,      $speaker );
                push( @file_uncertainties, $speaker );
            }
        }
        else {
            push( @file_words,         @$line_words_ref );
            push( @file_start_times,   $start_time );
            push( @file_end_times,     $end_time );
            push( @file_speakers,      $speaker );
            push( @file_uncertainties, 0 );
        }
    }
    close(TRANS);

    return (
        \@file_words,    \@file_start_times, \@file_end_times,
        \@file_speakers, \@file_uncertainties
    );
}

=head2 read_from_trs_file

Read from file in trs format
Usage:
  $sail_transcription->read_from_trs_file ( $trs_file );

=cut

sub read_from_trs_file {
    my ( $this, $trans_file ) = @_;

    my $file_name        = $trans_file->{name};
    my $format           = $trans_file->{format};
    my @file_words       = ();
    my @file_start_times = ();
    my @file_end_times   = ();
    my @file_speakers    = ();

    open( TRANS, $file_name ) || FATAL("Cannot read file $file_name");

    my $start_time    = -1;
    my $end_time      = -1;
    my @words         = ();
    my $start_reading = 0;
    while (<TRANS>) {
        chomp;
        my $line = $_;
        if ( $line =~ /Sync time=\"([\d\.]+)\"/ ) {
            $start_reading = 1;
            if ( $start_time == -1 ) {
                $start_time = $1;
            }
            elsif ( $end_time == -1 ) {
                $end_time = $1;
                my $n_words = @words;
                if ( $n_words > 0 ) {
                    push( @file_words,       @words );
                    push( @file_start_times, $start_time );
                    push( @file_end_times,   $end_time );
                }
                @words      = ();
                $start_time = $end_time;
                $end_time   = -1;
            }
        }
        elsif ( $line =~ /\<\/Turn\>/ ) {
            $start_reading = 1;
        }
        elsif ( $line =~ /^\s+$/ ) {
            next;
        }
        elsif ( $start_reading == 0 ) {
            next;
        }
        else {
            if ( $line =~ /\w+/ ) {
                $line =~ s/^\s+//;
                my @line_elms = split( /\//, $line );    # Find overlaps

                if ( @line_elms > 0 ) {
                    my @s_words = split( /\s+/, $line_elms[0] );
                    my $word = $s_words[0];

                    # Ignore annotation in parentheses
                    if ( $word =~ /[\(\)]/ ) {
                        next;
                    }
                    else {
                        push( @words, $word );
                    }
                }
            }
        }
    }
    close(TRANS);

    return ( \@file_words, \@file_start_times, \@file_end_times );
}

=head2 read_from_txt_file

Read from file in which the transcription is written in one line
Input: Hash with filename and format as fields;
Output: Reference to sequence of words in the file
Usage:
  $sail_transcription->read_from_txt_file( $txt_file );

=cut

sub read_from_txt_file {
    my ( $this, $trans_file ) = @_;

    my $file_name  = $trans_file->{name};
    my $format     = $trans_file->{format};
    my @file_words = ();

    open( TRANS, $file_name ) || FATAL("Cannot read file $file_name");

    while (<TRANS>) {
        chomp;
        my $line = $_;
        $line =~ s/^\s+//;

        # Split the words in the line. Keep the punctuation.
        my @line_words = split( /\s+/, $line );

        foreach my $l_word (@line_words) {
            if ($l_word =~ /([,\.\?\;\:]+)/) {
              my $punctuation_mark = $1;
              my @s_words = split(/[,\.\?\;\:]+/, $l_word);
              my $n_s_words = @s_words;
              if (!$n_s_words) {
                 if (! @file_words) {
                   next;
                 }
                 else {
                   my $p_word = $file_words[-1]."$l_word";
                   $file_words[-1] = $p_word;
                 }
              }
              else {
                if ($n_s_words < 3) {
                  foreach my $s_w (@s_words) {
                     push(@file_words, $s_w.$punctuation_mark);
                   }
                }
                else {
                  ERROR("Unexpected punctuation.");
                }
              }
            }
            else {
              push(@file_words, $l_word);
            }
        }
    }
    close(TRANS);

    return ( \@file_words );
}

=head2 read_spl_line

Read line which at the beginning has as a speaker id followed by ':'
Usage:
  ($speaker_label, $words_ref) = read_spl_line ( $transcription_line );
=cut

sub read_spl_line {
    my $trans_line = shift;

    $trans_line = m/^([\w\W\s]+)\:(.+)/;

    my $speaker_label = $1;
    my $transcription = $2;

    $transcription =~ s/^\s+//;
    $transcription =~ s/([<>])/\\$1/g;
    $transcription =~ s/\s\'/ /g;

    my @words = split( /\s+/, $transcription );

    return ( $speaker_label, \@words );
}

=head2 read_lab_line

Read line from a lab transcription file
Usage:
  ($words_list_ref, $start_time, $end_time) = read_lab_line( $trans_line, 10**7);
=cut

sub read_lab_line {
    my ( $trans_line, $lab_time_constant ) = @_;

    if ( @_ < 2 ) {
        $lab_time_constant = 10**7;
    }
    my $start_time = 0;
    my $end_time   = 0;

    my @words;
    if ( $trans_line =~ /^(\d+\.*\d*)\s+(\d+\.*\d*)\s+(.+)/ ) {
        my @l_words = split( /\s+/, $3 );
        push( @words, @l_words );
        $start_time = $1 / $lab_time_constant;
        $end_time   = $2 / $lab_time_constant;
    }
    else {
        DEBUG("Empty or improperly formatted line found: $trans_line\n");
    }
    return ( \@words, $start_time, $end_time );
}

=head2 read_lab_speaker_uncertainty_line

Read line from a lab transcription file
Usage:
  my @speaker_labels = ['H', 'W'];
  ($words_list_ref, $start_time, $end_time, $speaker, $uncertainty) = read_lab_speaker_uncertainty_line( $trans_line, \@speaker_labels, 1);
=cut

sub read_lab_speaker_uncertainty_line {
    my ( $trans_line, $speaker_labels_ref, $lab_time_constant ) = @_;

    if ( @_ < 3 ) {
        $lab_time_constant = 10**7;
    }
    my $start_time  = 0;
    my $end_time    = 0;
    my $speaker     = '';
    my $uncertainty = 0;

    my @words;

    # Check for uncertainty and speaker label at each line
    # but also account for the fact that these may be optional
    if ( $trans_line =~ /^([\d+\.]+)\s+([\d+\.]+)\s+(.+)/ ) {
        my @l_words = split( /\s+/, $3 );
        $start_time = $1 / $lab_time_constant;
        $end_time   = $2 / $lab_time_constant;

        my $n_words = @l_words;
        if ( $n_words < 2 ) {
            $speaker     = '';
            $uncertainty = 0;
        }
        elsif ( $n_words < 3 ) {
            my $last_token = $l_words[1];
            if ( grep { /^$last_token$/ } @$speaker_labels_ref ) {
                push( @words, $l_words[0] );
                $speaker     = $last_token;
                $uncertainty = 0;
            }
            else {
                $speaker = '';
                if ( $last_token =~ /\d+/ ) {
                    $uncertainty = $last_token;
                    push( @words, $l_words[0] );
                }
                else {
                    $uncertainty = 0;
                    push( @words, @l_words );
                }
            }
        }
        else {
            my $last_token = $l_words[ $n_words - 1 ];
            if ( $last_token =~ /\d+/ ) {
                $uncertainty = pop(@l_words);
                $last_token  = $l_words[ $n_words - 1 ];
                if ( grep { /^$last_token$/ } @$speaker_labels_ref ) {
                    $speaker = pop(@l_words);
                }
            }
            elsif ( grep { /^$last_token$/ } @$speaker_labels_ref ) {
                $uncertainty = 0;
                $speaker     = pop(@l_words);
            }
            push( @words, @l_words );
        }
    }
    else {
        DEBUG("Empty or improperly formatted line found: $trans_line\n");
    }
    return ( \@words, $start_time, $end_time, $speaker, $uncertainty );
}

=head2 set_words

Set words from an array reference
Input: Reference to an array of words.
Usage:
  $sail_transcription->set_words( \@words );
=cut

sub set_words {
    my ( $this, $word_array_ref ) = @_;

    my $n_words = @$word_array_ref;
    $this->{words} = $word_array_ref;

    my @start_times   = ();
    my @end_times     = ();
    my @uncertainties = ();
    foreach my $word (@$word_array_ref) {
        push( @start_times,   -1 );
        push( @end_times,     -1 );
        push( @uncertainties, 0 );
    }
    $this->{start_times}   = \@start_times;
    $this->{end_times}     = \@end_times;
    $this->{uncertainties} = \@uncertainties;
}

=head2 correct_typos

Correct possible typos, by providing an appropriate correction mapping
Input: corrections mapping in the form of a hash
Usage:
  $sail_transcription->correct_typos(\%corrections);
=cut

sub correct_typos {
    my ( $this, $corrections_ref ) = @_;

    my $word_ref          = $this->{words};
    my @words             = @$word_ref;
    my $n_words           = @words;
    my $start_times_ref   = $this->{start_times};
    my $end_times_ref     = $this->{end_times};
    my $uncertainties_ref = $this->{uncertainties};
    my $speakers_ref      = $this->{speakers};
    my @start_times       = @$start_times_ref;
    my @end_times         = @$end_times_ref;
    my @uncertainties     = @$uncertainties_ref;
    my @speakers          = @$speakers_ref;

    foreach my $corr ( keys(%$corrections_ref) ) {
        my @matching_inds =
          grep { $corr =~ /^\Q$words[$_]\E$/ } 0 .. ( $n_words - 1 );
        my $offset = 0;
        foreach my $ind (@matching_inds) {
            $ind -= $offset;
            my $corr_arr_ref = $corrections_ref->{$corr};
            my $n_corr_items = @$corr_arr_ref;
            @words = (
                @words[ 0 .. ( $ind - 1 ) ],
                @$corr_arr_ref, @words[ $ind + 1 .. ( $n_words - 1 ) ]
            );
            @start_times = (
                @start_times[ 0 .. ( $ind - 1 ) ],
                ( (-1) x $n_corr_items ),
                @start_times[ ( $ind + 1 ) .. ( $n_words - 1 ) ]
            );
            @end_times = (
                @end_times[ 0 .. ( $ind - 1 ) ],
                ( (-1) x $n_corr_items ),
                @end_times[ ( $ind + 1 ) .. ( $n_words - 1 ) ]
            );
            @uncertainties = (
                @uncertainties[ 0 .. ( $ind - 1 ) ],
                ( ( $uncertainties[$ind] ) x $n_corr_items ),
                @uncertainties[ ( $ind + 1 ) .. ( $n_words - 1 ) ]
            );
            @speakers = (
                @speakers[ 0 .. ( $ind - 1 ) ],
                ( ( $speakers[$ind] ) x $n_corr_items ),
                @speakers[ ( $ind + 1 ) .. ( $n_words - 1 ) ]
            );
            my $n_l_words = @words;

            if ( $n_l_words != $n_words ) {
                $offset  = $n_l_words - $n_words;
                $n_words = $n_l_words;
            }
        }
    }
    $this->{words}         = \@words;
    $this->{start_times}   = \@start_times;
    $this->{end_times}     = \@end_times;
    $this->{uncertainties} = \@uncertainties;
    $this->{speakers}      = \@speakers;
}

=head2 correct_typos_from_file

Correct possible typos, by providing an appropriate correction mapping
Input: corrections mapping file (two column file)
Usage:
  $sail_transcription->correct_typos_from_file( $corrections_file );
=cut

sub correct_typos_from_file {
    my ( $this, $corrections_file ) = @_;
    my $corrections_ref = $this->read_corrections_from_file($corrections_file);

    $this->correct_typos($corrections_ref);
}

=head2 delete_words

Delete the given words from the transcription
Input: reference to list of words 
Usage:
  $sail_transcription->delete_words( \@deletions );
=cut

sub delete_words {
    my ( $this, $deletions_ref ) = @_;

    my $word_ref          = $this->{words};
    my $start_times_ref   = $this->{start_times};
    my $end_times_ref     = $this->{end_times};
    my $uncertainties_ref = $this->{uncertainties};
    my $speakers_ref      = $this->{speakers};
    my @words             = @$word_ref;
    my @start_times       = @$start_times_ref;
    my @end_times         = @$end_times_ref;
    my @uncertainties     = @$uncertainties_ref;
    my @speakers          = @$speakers_ref;
    my $n_words           = @words;

    foreach my $del (@$deletions_ref) {

        #Handle tags
        $del =~ s/([<>])/\\$1/g;
        my @matching_inds =
          grep { $del =~ /^\Q$words[$_]\E$/ } 0 .. ( $n_words - 1 );
        my $offset = 0;
        foreach my $ind (@matching_inds) {
            $ind -= $offset;
            @words = (
                @words[ 0 .. ( $ind - 1 ) ],
                @words[ ( $ind + 1 ) .. ( $n_words - 1 ) ]
            );
            @start_times = (
                @start_times[ 0 .. ( $ind - 1 ) ],
                @start_times[ ( $ind + 1 ) .. ( $n_words - 1 ) ]
            );
            @end_times = (
                @end_times[ 0 .. ( $ind - 1 ) ],
                @end_times[ ( $ind + 1 ) .. ( $n_words - 1 ) ]
            );
            @uncertainties = (
                @uncertainties[ 0 .. ( $ind - 1 ) ],
                @uncertainties[ ( $ind + 1 ) .. ( $n_words - 1 ) ]
            );
            @speakers = (
                @speakers[ 0 .. ( $ind - 1 ) ],
                @speakers[ ( $ind + 1 ) .. ( $n_words - 1 ) ]
            );
            $n_words = @words;
            $offset += 1;
        }
    }
    $this->{words}         = \@words;
    $this->{start_times}   = \@start_times;
    $this->{end_times}     = \@end_times;
    $this->{uncertainties} = \@uncertainties;
    $this->{speakers}      = \@speakers;
}

=head2 delete_words_from_file 

Delete from the transcription the words found in file ,
  e.g., when these words are to be excluded from the alignment
Input: file containing the list of deletions
Usage:
  $sail_transcription->delete_words_from_file( $deletions_file );
=cut

sub delete_words_from_file {
    my ( $this, $deletion_file ) = @_;
    my $deletions_ref =
      SailTools::SailComponent::read_from_file($deletion_file);
    chomp(@$deletions_ref);
    $this->delete_words($deletions_ref);
}

=head2 read_corrections_from_file

Read the suggested correction mappings from file (two column file, i.e., original_entry corrected_entry)
Input: corrections mapping file
Output: Reference to hash with the corrections (%corr{entry} = corrected entry)
Usage:
  my $corr_map_hash = $sail_transcription->read_corrections_from_file( $correction_file );
=cut

sub read_corrections_from_file {
    my ( $this, $corrections_file ) = @_;

    my %corrections = ();

    # Read corrections from file
    open( COR, $corrections_file )
      || FATAL("Cannot open file $corrections_file for reading");
    while (<COR>) {
        my $line = $_;
        chomp($line);

        $line =~ s/^\s+//;
        my ( $entry, @corr_arr ) = split( /\s+/, $line );

        # Corrections might correspond to more than one words
        # Handle Tags, e.g., <SIL>, <THROAT>
        $entry =~ s/([<>])/\\$1/g;
        $corrections{$entry} = \@corr_arr;
    }
    close(COR);

    return \%corrections;
}

=head2 replace_words

Replace certain words with a given symbol (e.g., unknown words)
Input: reference to array of words to be replaced
Usage:
  $sail_transcription->replace_words( \@word_ref, $replacement_string );

=cut

sub replace_words {
    my ( $this, $word_ref, $replacement_string ) = @_;
    my %replacement_hash;
    my @replacement_arr;
    push( @replacement_arr, $replacement_string );
    foreach my $word (@$word_ref) {
        DEBUG("Replacement: $word $replacement_string");
        $replacement_hash{$word} = \@replacement_arr;
    }
    $this->correct_typos( \%replacement_hash );
}

=head2 split_into_turns 

Split a set of words given the corresponding speaker ids in a set of 
turns. 
Input: Reference to speaker ids
Usage:
  ( $turns_ref, $speakers_ref ) =split_into_turns( \@words, \@speaker_ids);

=cut

sub split_into_turns {
    my ( $words_ref, $spkr_ref ) = @_;

    my @turns   = ();
    my @spkrs   = ();
    my $n_words = @$words_ref;

    my $turn_index = 0;
    my $current_speaker;
    $turns[0] = "";
    for ( my $word_counter = 0 ; $word_counter < $n_words ; $word_counter++ ) {
        my $word_speaker = $spkr_ref->[$word_counter];
        if ( $word_counter == 0 ) {
            $current_speaker = $word_speaker;
        }
        if ( $current_speaker =~ /^$word_speaker$/ ) {
            $turns[$turn_index] .= " " . $words_ref->[$word_counter];
        }
        else {
            $turn_index++;
            $turns[$turn_index] = $words_ref->[$word_counter];
            $current_speaker = $word_speaker;
        }
        $spkrs[$turn_index] = $word_speaker;
    }
    return ( \@turns, \@spkrs );
}

=head2 write_clean_to_file

Write the transcription information to file
Input: file to be written, format, mode (one of 'words','speakers', 'utterances' currently)
Usage:
  $sail_transcription->write_clean_to_file ( $file_name, $format, $mode, $speaker_id );
=cut

sub write_clean_to_file {
    my ( $this, $file_name, $format, $mode, $spkr ) = @_;

    my $words_ref = $this->{words};
    my @words = @$words_ref;
    my $n_words = @words;
    for (my $k=0; $k<$n_words; $k++) {
           $words[$k] =~ s/[\?\;,\.\:]+//;
           $words[$k] = lc($words[$k]);
    }
    if ( $format eq 'txt' ) {
        if ( $mode eq 'words' ) {
            SailTools::SailComponent::print_into_file( \@words,
                $file_name, " " );
        }
        elsif ( $mode eq 'turns' ) {
            my $spkr_ref  = $this->{speakers};

            my ( $turns_ref, $spk_id_ref ) =
              split_into_turns( \@words, $spkr_ref );

            if ( $spkr =~ /^all$/ ) {
                SailTools::SailComponent::print_into_file( $turns_ref,
                    $file_name, "\n" );
            }
            else {
                my $n_turns = @$spk_id_ref;
                my @turn_inds =
                  grep( $spkr =~ $spk_id_ref->[$_], 0 .. ( $n_turns - 1 ) );
                my @spkr_turns = @$turns_ref[@turn_inds];
                SailTools::SailComponent::print_into_file( \@spkr_turns,
                    $file_name, "\n" );
            }

        }
    }
    elsif ( $format eq 'lab' ) {
        if ( $mode eq 'words' ) {
            $this->print_into_lab_file( $file_name, $this->{start_times},
                $this->{end_times}, \@words );
        }
        elsif ( $mode eq 'words_uncertainties' ) {
            $this->print_into_lab_file( $file_name, $this->{start_times},
                $this->{end_times}, \@words, $this->{uncertainties} );
        }
        elsif ( $mode eq 'words_speakers' ) {
            $this->print_into_lab_file( $file_name, $this->{start_times},
                $this->{end_times}, \@words, $this->{speakers} );
        }
        elsif ( $mode eq 'words_speakers_uncertainties' ) {
            if ( ( $this->{speakers} ) && ( $this->{uncertainties} ) ) {
                $this->print_into_lab_file(
                    $file_name,         $this->{start_times},
                    $this->{end_times}, \@words,
                    $this->{speakers},  $this->{uncertainties}
                );
            }
            elsif ( $this->{uncertainties} ) {
                $this->print_into_lab_file( $file_name, $this->{start_times},
                    $this->{end_times}, \@words,
                    $this->{uncertainties} );
            }
            elsif ( $this->{speakers} ) {
                $this->print_into_lab_file( $file_name, $this->{start_times},
                    $this->{end_times}, \@words, $this->{speakers} );
            }
        }
        else {
            SailTools::SailComponent::print_into_file( \@words,
                $file_name, "\n" );
        }
    }
    else {
        FATAL(
"Currently no other formats have been specified for the transcription to be saved in"
        );
    }
}



=head2 write_to_file

Write the transcription information to file
Input: file to be written, format, mode (one of 'words','speakers', 'utterances' currently)
Usage:
  $sail_transcription->write_to_file ( $file_name, $format, $mode, $speaker_id );
=cut

sub write_to_file {
    my ( $this, $file_name, $format, $mode, $spkr ) = @_;

    if ( $format eq 'txt' ) {
        if ( $mode eq 'words' ) {
            my $words_ref = $this->{words};
            SailTools::SailComponent::print_into_file( $words_ref,
                $file_name, " " );
        }
        elsif ( $mode eq 'turns' ) {
            my $words_ref = $this->{words};
            my $spkr_ref  = $this->{speakers};

            my ( $turns_ref, $spk_id_ref ) =
              split_into_turns( $words_ref, $spkr_ref );

            if ( $spkr =~ /^all$/ ) {
                SailTools::SailComponent::print_into_file( $turns_ref,
                    $file_name, "\n" );
            }
            else {
                my $n_turns = @$spk_id_ref;
                my @turn_inds =
                  grep( $spkr =~ $spk_id_ref->[$_], 0 .. ( $n_turns - 1 ) );
                my @spkr_turns = @$turns_ref[@turn_inds];
                SailTools::SailComponent::print_into_file( \@spkr_turns,
                    $file_name, "\n" );
            }

        }
    }
    elsif ( $format eq 'lab' ) {
        if ( $mode eq 'words' ) {
            $this->print_into_lab_file( $file_name, $this->{start_times},
                $this->{end_times}, $this->{words} );
        }
        elsif ( $mode eq 'words_uncertainties' ) {
            $this->print_into_lab_file( $file_name, $this->{start_times},
                $this->{end_times}, $this->{words}, $this->{uncertainties} );
        }
        elsif ( $mode eq 'words_speakers' ) {
            $this->print_into_lab_file( $file_name, $this->{start_times},
                $this->{end_times}, $this->{words}, $this->{speakers} );
        }
        elsif ( $mode eq 'words_speakers_uncertainties' ) {
            if ( ( $this->{speakers} ) && ( $this->{uncertainties} ) ) {
                $this->print_into_lab_file(
                    $file_name,         $this->{start_times},
                    $this->{end_times}, $this->{words},
                    $this->{speakers},  $this->{uncertainties}
                );
            }
            elsif ( $this->{uncertainties} ) {
                $this->print_into_lab_file( $file_name, $this->{start_times},
                    $this->{end_times}, $this->{words},
                    $this->{uncertainties} );
            }
            elsif ( $this->{speakers} ) {
                $this->print_into_lab_file( $file_name, $this->{start_times},
                    $this->{end_times}, $this->{words}, $this->{speakers} );
            }
        }
        else {
            SailTools::SailComponent::print_into_file( $this->{words},
                $file_name, "\n" );
        }
    }
    else {
        FATAL(
"Currently no other formats have been specified for the transcription to be saved in"
        );
    }
}

=head2 get_unique_words

Get unique words of the transcription.
Usage:
 $unique_words_list_ref = $sail_transcription->get_unique_words;

=cut

sub get_unique_words {
    my $this = shift;
    my %saw;
    my @unique_words = ();
    my $words_ref    = $this->{words};

    my @all_words = @$words_ref;
    my $n_words = @all_words;
    for (my $k=0; $k<$n_words; $k++) {
      $all_words[$k] =~ s/[\?\.,;:]+//;
      $all_words[$k] = lc($all_words[$k]);
    }

    undef %saw;
    @saw{@all_words} = ();
    @unique_words = sort keys %saw;    # remove sort if undesired

    return \@unique_words;
}

=head2 find_unique_words

Get unique words of the transcription.
Usage:
 $unique_words_list_ref = find_unique_words( \@words );

=cut

sub find_unique_words {
    my $words_ref = shift;
    my %saw;
    my @unique_words = ();

    undef %saw;
    @saw{@$words_ref} = ();
    @unique_words = sort keys %saw;

    return \@unique_words;
}

=head2 get_unique_words_from_file

Get unique words from a file.
Usage:
  my $words_arr_ref = get_unique_words_from_file ( $file ); 

=cut

sub get_unique_words_from_file {
    my $file = shift;
    open( FILE, $file ) || die("Cannot open file $file\n");
    my %words;
    while (<FILE>) {
        my $line = $_;
        chomp($line);
        $line =~ s/^\s+//;
        my @l_words = split( /\s+/, $line );
        for my $i_word (@l_words) {
            $words{$i_word}++;
        }
    }
    close(FILE);
    my @word_arr = sort keys %words;
    return \@word_arr;
}

=head2 update_unique_words_from_file

Update a map of words from a file.
Usage:
  update_unique_words_from_file( $file, \%word_map );

=cut

sub update_unique_words_from_file {
    my ( $file, $word_hash_ref ) = @_;
    open( FILE, $file ) || die("Cannot open file $file\n");
    while (<FILE>) {
        my $line = $_;
        chomp($line);
        $line =~ s/^\s+//;
        my @l_words = split( /\s+/, $line );
        for my $i_word (@l_words) {
            $word_hash_ref->{$i_word}++;
        }
    }
    close(FILE);
}

=head2 print_into_lab_file

Print the words with their start and end times into a lab file
Input: The name of the file, references to the lists of start times, end times and words
Usage:
  print_into_lab_file ( $file_name, \@start_times, \@ent_times, \@words, \@info, \@optional );

=cut

sub print_into_lab_file {
    my ( $this, $file_name, $start_times_ref, $end_times_ref, $words_ref,
        $info_arr, $opt_arr )
      = @_;

    my $info = "";
    my $opt  = "";
    my $info_given;
    my $opt_given;
    if ( @_ < 6 ) {
        $info = "";
        $opt  = "";
    }
    else {
        $info_given = 1;
        $opt        = "";
        if ( @_ == 7 ) {
            $opt_given = 1;
        }
    }
    open( FILE, ">$file_name" )
      || FATAL("Cannot open file $file_name for writing");
    my $n_words = @$words_ref;

    my $untimed_start     = 0;
    my $untimed_end       = 0;
    my $untimed_string    = "";
    my $n_untimed_entries = 0;
    for ( my $word_counter = 0 ; $word_counter < $n_words ; $word_counter++ ) {
        my $word  = $words_ref->[$word_counter];
        my $start = $start_times_ref->[$word_counter];
        my $end   = $end_times_ref->[$word_counter];
        if ( $start > -1 ) {
            if ($n_untimed_entries) {
                $n_untimed_entries = 0;
                print FILE "$untimed_start $start $untimed_string $info $opt\n";
                $untimed_string = "";
                $info           = "";
                $opt            = "";
            }
            if ($info_given) {
                if ( ( !@$info_arr ) || ( @$info_arr < $word_counter - 1 ) ) {
                    $info = "";
                }
                else {
                    $info = $info_arr->[$word_counter];
                }
            }
            if ($opt_given) {
                if ( @$opt_arr < $word_counter + 1 ) {
                    $opt = "";
                }
                else {
                    $opt = $opt_arr->[$word_counter];
                }
            }
            print FILE "$start $end $word $info $opt\n";
            $untimed_start = $end;
        }
        else {
            $untimed_string .= " $word";
            if ($info_given) {
                if ( ( !@$info_arr ) || ( @$info_arr < $word_counter ) ) {
                    $info = "";
                }
                else {
                    $info = $info_arr->[$word_counter];
                }
            }
            if ($opt_given) {
                if ( @$opt_arr < $word_counter + 1 ) {
                    $opt = "";
                }
                else {
                    $opt = $opt_arr->[$word_counter];
                }
            }
            $n_untimed_entries++;
        }
    }
    if ($n_untimed_entries) {
        if ( $this->{duration} > 0 ) {
            $untimed_end = $this->{duration};
        }
        else {
            $untimed_end = $untimed_start + 10;
        }
        print FILE "$untimed_start $untimed_end $untimed_string $info $opt\n";
    }
    print FILE "\n";
    close(FILE);
}

=head2 get_text

Return a string of the transcription
Output: The transcription text
Usage:
  $text = $sail_transcription->get_text;

=cut

sub get_text {
    my $this = shift;

    my $words_ref = $this->{words};
    my $text = join( " ", @$words_ref );
    return $text;
}

=head1 AUTHOR

Athanasios Katsamanis, C<< <nkatsam at sipi.usc.edu> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-sailalign at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=SailAlign>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc SailTools::SailTranscription


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

1;    # End of SailTools::SailTranscription

package SailTools::VoiceActivityDetection;

use warnings;
use strict;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use File::Spec::Functions;
use File::Path;
use Audio::Wav;

=head1 NAME

SailTools::VoiceActivityDetection - Package for voice activity detection

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use SailTools::VoiceActivityDetection;

    my $foo = SailTools::VoiceActivityDetection->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 new

New VoiceActivityDetection object.
Usage:
  my $vad = new SailTools::VoiceActivityDetection( \%cfg, \%setup );

=cut

sub new {
    my ($class, $configuration, $experiment, $max_duration) = @_;
    my $self;

    $self->{working_dir} = $experiment->{'working_dir'};
    $self->{vad_output_dir} = $experiment->{'vad_output_dir'};
    $self->{bin_dir} = $experiment->{'bin_dir'};
    $self->{tool} = $configuration->{tool};
    $self->{method} = $configuration->{method};
    $self->{model} = $configuration->{model};
    $self->{frame_rate} = $configuration->{frame_rate};
    $self->{frame_size} = $configuration->{frame_size};
    $self->{lab_file} = $configuration->{lab_file};
    $self->{output} = $configuration->{output};
    $self->{voice_labels} = $configuration->{voice_labels};
    $self->{format} = $configuration->{format};
    $self->{experiment} = $experiment;
    $self->{max_duration} = $max_duration;

    bless($self, $class);
    my $vad_dir = File::Spec->catdir($self->{working_dir}, $self->{vad_output_dir});
    $self->{vad_dir} = $vad_dir;

    return $self;
}

=head2 signal_to_vad

Detect voice activity in a signal.
Usage:
  my $vad_trans_ref = $vad->signal_to_vad ( $sail_signal_ref );

=cut
sub signal_to_vad {
    my ($this, $signal) = @_;

    mkpath($this->{vad_dir});
    my $vad_trans_file = File::Spec->catfile($this->{vad_dir}, $this->{lab_file});

    my $vad_trans = new SailTools::SailTranscription($vad_trans_file, $this->{experiment}, $this);
    $this->detect_voice($signal, $vad_trans);

    return $vad_trans;
}

=head2 detect_voice

Detect voice in a signal.

=cut
sub detect_voice {
    my ($this, $signal, $voice_activity) = @_;

    my $vad_method = $this->{method};
    if ($vad_method eq "SAIL") {
        $this->sail_detect_voice($signal, $voice_activity);
    }
    elsif ($vad_method eq "None") {
        $this->dummy_detect_voice($signal, $voice_activity);
    }
    else {
        FATAL("Unidentified VAD method");
    }
}

=head2 dummy_detect_voice

Without a proper voice activity detection just consider that you have voiced
segments of fixed duration. 
Usage:
  $vad->dummy_detect_voice( $signal, $voice_activity);
=cut
sub dummy_detect_voice {
    my ($this, $signal, $voice_activity) = @_;
    my %voice_active_segments;

    my $wav = new Audio::Wav;
    my $sig_info = $wav->read($signal->{file});
    my $sig_duration = $sig_info->length_seconds();
    my $max_duration = $this->{max_duration};
    my @segment_time = (0);
    my @segment_voice = ();
    my $segment_end = 0;
    my $i_segment = 0;
    while ($segment_end<=$sig_duration) {
      if ($i_segment % 2) {
        $segment_end += 1;
        push(@segment_voice, 0);
      }
      else {
        $segment_end += $max_duration;
        push(@segment_voice, 1);
      }
      if ($segment_end > $sig_duration) {
        push(@segment_time, $sig_duration);
      }
      else {
        push(@segment_time, $segment_end);
      }
      $i_segment += 1;
    }
    $voice_active_segments{'time'} = \@segment_time;
    $voice_active_segments{'voice'} = \@segment_voice;
    vad_to_transcription(\%voice_active_segments, $voice_activity, $this->{'voice_labels'});
}


=head2 sail_detect_voice

Detect voice activity using SAIL VAD (Ghosh et al., 2010).
Usage:
  $vad->sail_detect_voice( $signal, $voice_activity ) ;
=cut

sub sail_detect_voice {
    my ($this, $signal, $voice_activity) = @_;

    my $vad_bin_name = $this->{'tool'};
    my $vad_model = $this->{'model'}; 
    my $vad_frame_rate = $this->{'frame_rate'};
    my $vad_frame_size = $this->{'frame_size'};
    my $vad_output = catfile($this->{vad_dir},$this->{output});
    my $vad_bin_path = catfile($this->{bin_dir},$vad_bin_name);
    my $sail_voice_activity_ref;

    run_sail_vad($signal->{file}, $vad_output, $vad_model, $vad_frame_rate, $vad_frame_size, $vad_bin_path);
    $sail_voice_activity_ref = read_frame_vad($vad_output, $vad_frame_rate);
    my $voice_active_segments_ref = frame_vad_to_segment_vad($sail_voice_activity_ref);

    vad_to_transcription($voice_active_segments_ref, $voice_activity, $this->{'voice_labels'});
}

=head2 run_sail_vad

Run SAIL's vad.
Usage:
  run_sail_vad ( $audio_filename, $vad_output, $model, $frame_rate, $frame_size, $vad_bin );

=cut
sub run_sail_vad {
    my ($audio_filename, $vad_output, $model, $frame_rate, $frame_size, $vad_bin) = @_;

    my $cmd_args = "-m $model -i $audio_filename -o $vad_output ".
                  "--ST-window-size $frame_size --ST-window-shift $frame_rate";
    my $cmd_str = "$vad_bin $cmd_args"; 
    DEBUG($cmd_str);
    system($cmd_str);
}

=head2 read_frame_vad

Read VAD output per frame.
Usage:
  $voice_activity_hash_ref = read_frame_vad( $vad_output_file, $sampling_rate );

=cut
sub read_frame_vad {
    my ($vad_output_filename, $sampling_rate) = @_; 

    open(VAD_OUTPUT,$vad_output_filename) || die("Cannot open $vad_output_filename");
    my %voice_activity;
    my @time = (0);
    my @voice = ();
    while (<VAD_OUTPUT>) {
        chomp;
        my $line = $_;
        if ($line =~ /(\d+)\s+(\d+)/) 
        {
           my $frame_index = $1;
           my $voice_flag = $2;
           push(@time, $frame_index*$sampling_rate);
           push(@voice, $voice_flag);
        }
   }
   close(VAD_OUTPUT);
   $voice_activity{'time'} = \@time;
   $voice_activity{'voice'} = \@voice;
   return \%voice_activity;
}

=head2 frame_vad_to_segment_vad

Concatenate frame-based decisions when possible to get segment-based decisions.
Usage:
  my $segment_vad_hash_ref = frame_vad_to_segment_vad ( \%frame_vad );
  

=cut
sub frame_vad_to_segment_vad {
   my $sail_voice_activity_ref = shift;
   my $frame_time_ref = $sail_voice_activity_ref->{'time'};
   my $frame_voice_ref = $sail_voice_activity_ref->{'voice'};
   my @segment_time = (0);
   my @segment_voice = ();
   my %segment_voice_activity=();
   my @frame_time = @$frame_time_ref;
   my @frame_voice = @$frame_voice_ref;

   my $segment_end_time = $frame_time[1];
   my $n_frames = @frame_voice;
   my $current_state = $frame_voice[0];

   for (my $frame_counter=1; $frame_counter<$n_frames; $frame_counter++) {
      if ($current_state ne $frame_voice[$frame_counter]) {
        push(@segment_time, $segment_end_time);
        push(@segment_voice, $current_state);
      }
      $segment_end_time = $frame_time[$frame_counter+1];
      $current_state = $frame_voice[$frame_counter];
   }
   push(@segment_time, $frame_time[$n_frames-1]);
   push(@segment_voice, $frame_voice[$n_frames-1]);
   $segment_voice_activity{"time"}=\@segment_time;
   $segment_voice_activity{"voice"}=\@segment_voice;

   return \%segment_voice_activity;
}

=head2 vad_to_transcription

Voice activity detection information as a transcription.
Usage:
  vad_to_transcription ( \%vad_info, $transcription_object_ref, \@voice_labels );

=cut

sub vad_to_transcription {
    my ($vad_info_ref, $transcription, $voice_labels_ref) = @_;

    my @voice_labels = @$voice_labels_ref;
     
    my $segments_time_ref = $vad_info_ref->{'time'};
    my $segments_voice_ref = $vad_info_ref->{'voice'};
    my @segments_time = @$segments_time_ref;
    my @segments_voice = @$segments_voice_ref;

    my $n_segments = @$segments_voice_ref;
    my $n_segment_stamps = @$segments_time_ref;
    my @vad_label_set= ();
	my @segments_start_times = ();
	my @segments_end_times = ();
	
    for (my $segment_counter=0; $segment_counter<$n_segments; $segment_counter++) {
       $segments_start_times[$segment_counter] = $segments_time[$segment_counter];
       $segments_end_times[$segment_counter] = $segments_time[$segment_counter+1];

       my $vad_label;
       if ($segments_voice[$segment_counter] eq 1) {
          $vad_label = $voice_labels[0];
       }
       else { 
          $vad_label = $voice_labels[1];
       }
       push(@vad_label_set, $vad_label);
    }
    $transcription->{voice_activity} = \@vad_label_set;
    $transcription->{timing} = \@segments_time;
    $transcription->{start_times} = \@segments_start_times;
    $transcription->{end_times} = \@segments_end_times;
}


=head1 AUTHOR

Athanasios Katsamanis, C<< <nkatsam at sipi.usc.edu> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-sailalign at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=SailAlign>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc SailTools::VoiceActivityDetection


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

1; # End of SailTools::VoiceActivityDetection

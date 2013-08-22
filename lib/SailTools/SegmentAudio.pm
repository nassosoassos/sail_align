package SailTools::SegmentAudio;

use warnings;
use strict;
use File::Basename;
use POSIX qw(ceil floor);

=head1 NAME

SailTools::SegmentAudio - Audio Segmentation Utilities

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';
our @ISA = qw(SailTools::SailComponent);


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use SailTools::SegmentAudio;

    my $foo = SailTools::SegmentAudio->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 audio_recognition_engine

Run julian as an audio recognition engine.
$audio_segmentor->audio_recognition_engine;

=cut

sub audio_recognition_engine {
  my $this = shift;
  my $audio_dictionary = $this->{audio_dictionary};
  my $scp_file = $this->{audio_recognize_scp_file};
  my $wdnet = $this->{audio_class_net};
  my $models = $this->{audio_models};
  my $julian_results = $this->{audio_recognition_results_file};
  my $bin_dir = $this->{bin_dir};

  my $output = $this->execute("julian","-dfa $wdnet -h $models -filelist $scp_file -v $audio_dictionary -walign > $julian_results", $bin_dir);
  
  my @audio_rec_result = @$output;
  my @error_indicators = grep { /Error|Fatal/i } @audio_rec_result;  
  if (@error_indicators) {
     $this->fatal("@audio_rec_result","SoundSplit");
  } 
  else {
     $this->debug("julian ran successfully");  
  }
}

=head2

Feature extraction from audio. Segment non-silent segments.

=cut
sub code_audio_cut_silences {
  my $this = shift;

  $this->print_code_config("audio");
  $this->print_code_scp_single_audio_file;
  
  $this->frontend_cut_silences;

  $this->transcribe_silence_separated_segments;

  $this->debug("Silence Detection and MFCC Generation has been completed");
}

=head2

Acoustic feature extraction from speech.

=cut
sub code_speech_segments {
  my $this = shift;
  my $useSnack = 1;
  my $useHCopy = 0;
  my $useFrontend = 1;
  my $labelPattern = "SPEECH";
  my $source_path = $this->{audio_source_wav_dir};
  my $audioFileName = $this->{fileName};
  my $configurationFile = $this->{speech_code_config_file};
  my $audioExt = $this->{audio_file_ext};
  my $speech_segments_handle = $this->open_file($this->{audio_classes_refined_transcription_file},"read");
  my $speech_segments_list_handle = $this->open_file($this->{speech_segments_list},"write");
  my $speech_segments_cut_times = $this->{speech_segments_cut_times_file};
  my $speech_segments_cut_times_handle = $this->open_file($speech_segments_cut_times, "write");
  my $speech_segments_transcription_file = $this->{speech_segments_transcription_file};
  my $speech_segments_transcription_handle = $this->open_file($speech_segments_transcription_file,"write");
  my $bin_dir = $this->{bin_dir};

  my @segments = <$speech_segments_handle>;

  $this->print_code_config("speech");

  my ($audioBasename, $audioPath) = fileparse($audioFileName, '\.[^\.]*');

  if (($this->{speech_code_config}{SOURCEFORMAT}) && ($this->{speech_code_config}{SOURCEFORMAT} eq 'WAV')) {
    $useSnack = 1;
  }

  my $stargetDirName = $this->{speech_wav_segments_dir};
  my $targetDirName = $this->{speech_mfcc_segments_dir};

  # In case wav segmentation is requested or, in general, the source format is
  # wav then use snack via python. This is
  # because HCopy wav segmentation cannot produce proper wav files that can be
  # further processed.      
  if ($useSnack == 1) {
    $useHCopy=0;
    $useFrontend=1;
    
    my $snack_scp_handle = $this->open_file($this->{cut_audio_scp_file},"write");
    my $kLabelIndex = 1; 
    my @targetFiles;
    my @timeLims;
    foreach my $kSegment (@segments) {
      my @kSInfo = split(" ", $kSegment);
      my $kStart = $kSInfo[0];
      my $kEnd = $kSInfo[1];
      my $kLabel = $kSInfo[2];

      if ($kLabel =~ /$labelPattern/) {
        my $sourceFile = "$source_path/$audioFileName";
        my $targetFile = "$stargetDirName/$audioBasename.$kLabelIndex.$audioExt";
        print $snack_scp_handle "$sourceFile $targetFile $kStart $kEnd\n";
        push(@targetFiles, $targetFile);
        push(@timeLims, "$kStart $kEnd");
        print $speech_segments_transcription_handle "$kStart $kEnd $audioBasename.$kLabelIndex\n";
        $kLabelIndex++; 
      }
      else {
        print $speech_segments_transcription_handle $kSegment;
      }
    }
    $this->close_file($speech_segments_transcription_handle);
    my $commandStr = "python $bin_dir/cropWavs.py ".$this->{cut_audio_scp_file};
    my $crop_wavs_output = $this->execute_python('cropWavs.py',$this->{cut_audio_scp_file},$bin_dir);

    my @crop_result = @$crop_wavs_output;
    my @error_indicators = grep { /Error|Fatal/i } @crop_result;  
    if (@error_indicators) {
      $this->fatal("@crop_result","FileSplit");
    } 
    else {
      $this->debug("cropWavs.py ran successfully.");  
    }
    
    # Generate a list of the output Files 
    if (($useHCopy==0)&&($useFrontend==0)) {
      my $kIndex = 0;
      foreach my $kTargetFile (@targetFiles) {
        if (-e $kTargetFile) {
          print $speech_segments_list_handle $kTargetFile."\n";
          print $speech_segments_cut_times_handle $timeLims[$kIndex]."\n";
        }
        $kIndex++;
      }
    }
    $source_path= $stargetDirName;
  }
  
  # Convert the wav files to another format using HCopy
  if ($useHCopy==1) {
    my $kLabelIndex=1;
    foreach my $kSegment (@segments) {
      my @kSInfo = split(" ", $kSegment);
      my $kStart = $kSInfo[0];
      my $kEnd = $kSInfo[1];
      my $kLabel = $kSInfo[2];
      my $commandStr;
      my $sourceFile;
      my $targetFile;
  
      if ($kLabel =~ /$labelPattern/) {
        if ($useSnack==0) {
          $sourceFile = "$source_path/$audioFileName";
          $targetFile = "$targetDirName/$audioBasename.$kLabelIndex$audioExt";
          $commandStr = "HCopy -T 1 -C $configurationFile -s $kStart -e $kEnd $sourceFile $targetFile"; 
        }
        else {
          $sourceFile = "$source_path/$audioBasename.$kLabelIndex$audioExt";
          $targetFile = "$targetDirName/$audioBasename.$kLabelIndex.mfc";
          $commandStr = "HCopy -T 1 -C $configurationFile $sourceFile $targetFile"; 
        }
        if (-e $targetFile) {
          print $speech_segments_list_handle $targetFile."\n";
          print $speech_segments_cut_times_handle "$kStart $kEnd\n"; 
        }
        $kLabelIndex++; 
      }
    }
  }
  if ($useFrontend==1) {
    $this->debug("Extracting  features for recognition...");
    my $kLabelIndex=1;
  
    my $tmpScp= $this->{speech_code_scp_file};
  
    foreach my $kSegment (@segments) {
      my @kSInfo = split(" ", $kSegment);
      my $kStart = $kSInfo[0];
      my $kEnd = $kSInfo[1];
      my $kLabel = $kSInfo[2];
      my $commandStr;
      my $sourceFile;
      my $targetFile;
  
      if ($kLabel =~ /$labelPattern/) {
        my $speech_code_scp_handle = $this->open_file($tmpScp,"write");
        $sourceFile = "$source_path/$audioBasename.$kLabelIndex.$audioExt";
        $targetFile = "$targetDirName/$audioBasename.$kLabelIndex.mfc";

        print $speech_code_scp_handle "$sourceFile $targetFile";
        $commandStr = "$bin_dir/frontend -confFile $configurationFile -scpFile $tmpScp";

        my $output = $this->execute('frontend',"-confFile $configurationFile -scpFile $tmpScp",$bin_dir);
        my @code_output = @$output;
        $this->debug('frontend output:'."@code_output");
        $this->close_file($speech_code_scp_handle);
        if (-e $targetFile) {
          print $speech_segments_list_handle $targetFile."\n";
          print $speech_segments_cut_times_handle "$kStart $kEnd\n"; 
        }
          $kLabelIndex++; 
        }
    }
  }
  $this->close_file($speech_segments_list_handle);
  $this->close_file($speech_segments_cut_times_handle);

  $this->debug("Speech segments have been coded.");
}

=head2 recognize_audio
  
  Run audio recognition.
  
=cut

sub recognize_audio {
  my $this = shift;

  my $config = $this->{audio_recognize_conf_file};
  my $scp = $this->{audio_recognize_scp_file};

  $this->print_recognize_config("audio");

  my $silence_separated_segments_list = $this->{silence_separated_segments_list}; 
  my $silence_separated_segments_mfc_path = $this->{audio_mfcc_dir};
  my $mfcc_file_ext = $this->{mfcc_file_ext};

  $this->print_recognize_scp($silence_separated_segments_list, $scp, $silence_separated_segments_mfc_path, $mfcc_file_ext);
  $this->audio_recognition_engine;
  $this->transcribe_audio_classes;
  $this->debug("Audio Recognition has been completed.");
}

=head2 refineLabels

  Smoothening labels. This function is outdated.

=cut
sub refineLabels {
  my $this = shift;
  my $TIMEUNITS = 10000000;
  my $TOLERANCE = 0;
  
  my $transcription_handle = $this->open_file($this->{audio_classes_transcription_file}, "read"); 
  my $new_transcription_handle = $this->open_file($this->{audio_classes_refined_transcription_file}, "write");

  my @transcription = <$transcription_handle>;

  $this->close_file($transcription_handle);

  my $sStart = 0;
  my $nextSStart = 0;
  my $nextSEnd = 0;
  my $sEnd = 0;
  my $sDuration = 0;
  my $sLabel="SILENCE";

  my $nLabels = @transcription;

  for (my $k=0; $k<$nLabels; $k++) {
    my $kLine = $transcription[$k];
    chomp($kLine);
    my @labelInfo = split(" ", $kLine); 
    my $kStart = $labelInfo[0];
    my $kEnd = $labelInfo[1];
    my $kDuration = $kEnd - $kStart; 

    # Ignore very short segments. Probably the best strategy would be to
    # concatenate such segments with both the previous and the next ones.
    if ($kDuration < 1*$TIMEUNITS) {
      $sDuration += $kDuration;
      $sEnd = $kEnd;
  
      # To apply the strategy commented above just uncomment the following line 
      $nextSStart = -$kDuration;
      next; 
    }  
    my $kLabel = $labelInfo[2]; 

    if ($kLabel =~ /SPEECH/) {
      if (($sDuration > 5*$TIMEUNITS) || !($sLabel =~ /SPEECH/)) {
      # Write the previous segment to file 
      # The if block has been commented out to write all kinds of segments and
      # not only Speech
      #if ($sLabel =~ /SPEECH/ ) {
          if ($sEnd > 0) {
            # For speech segments, allow them to be a bit longer so that they may
            # incorporate useful acoustic context
            if ($sStart > 0) { 
              $sStart = $sStart - $TOLERANCE;
              $sEnd = $sEnd + $TOLERANCE;
            }
            if ($sDuration>=$TIMEUNITS) {
              print $new_transcription_handle "$sStart $sEnd $sLabel\n";
            }
        #  }
          # ... and begin the new segment  
        }
        
        $sStart = $nextSStart + $kStart;
        $sEnd = $kEnd;
        $sLabel = $kLabel;
        $sDuration = $kDuration;
        $nextSStart = 0;
    }
    else {
        $sEnd = $kEnd;
        $sDuration += $kDuration;
        $nextSStart = 0;
      }
    }
    else {
      #if ($sLabel =~ /SPEECH/) {
        if ($sEnd>0) {
          if ($sStart > 0) { 
            $sStart = $sStart - $TOLERANCE;
            $sEnd = $sEnd + $TOLERANCE;
          }
        print $new_transcription_handle "$sStart $sEnd $sLabel\n";
        }
    #}
      $sLabel = $kLabel;
      $sStart = $kStart;
      $sEnd = $kEnd;
      $sDuration = $kDuration;
      $nextSStart = 0;
    }
  }
  print $new_transcription_handle "$sStart $sEnd $sLabel\n";

  $this->close_file($new_transcription_handle);
  $this->debug("Audio Class Label Transciption Refinement has been completed.");
}

=head2 segment_audio

Audio segmentation

=cut

sub segment_audio {
  my $this = shift;

  $this->code_audio_cut_silences;
  $this->recognize_audio;
  $this->refineLabels;
  $this->code_speech_segments;

  $this->debug("Audio Segmentation has been completed successfully");
}

=head2 transcribe_audio_classes

Read julian audio segmentation output.

=cut

sub transcribe_audio_classes {
  my $this = shift;
  my $old_transcription = $this->{silence_separated_segments_transcription_file};
  my $new_transcription = $this->{audio_classes_transcription_file}; 

  my $sourceRate = $this->{audio_code_config}{SOURCERATE};
  my $targetRate = $this->{audio_code_config}{TARGETRATE};
  my $frameRate = floor($targetRate/$sourceRate)*$sourceRate;
  
  my $firstFile=1;
  my $rootName = '';
  my $old_transcription_handle = $this->open_file($old_transcription,"read");
  my @transcription = <$old_transcription_handle>;
  $this->close_file($old_transcription_handle);
  my $new_transcription_handle = $this->open_file($new_transcription,"write");

  foreach my $kLine (@transcription) {
    chomp($kLine);
    my @sInfo = split(" ", $kLine);
    my $segment_startTime = $sInfo[0];
    my $segment_endTime = $sInfo[1];
    my $baseName = $sInfo[2];
    my $startReading = 0;
    my $fileFound = 0;
    my $julian_results_handle = $this->open_file($this->{audio_recognition_results_file},"read"); 

    while (<$julian_results_handle>) {
      if(/input MFCC file:(.*)/) {
        if ($fileFound==1) {
          last;
        }
        my $inpPath = $1;
        my $fileName = fileparse($inpPath,'\.[^\.]*');
        if ($fileName =~ /$baseName/) {
          $startReading = 1;
        }
        else {
          $startReading=0;
        }
      }
      if((/=== word alignment begin ===/../=== word alignment end ===/)&&($startReading==1)) {
        if(/\d+:/../\d+:/){
          my $line = $_;
          chomp($line);
          $line =~ s/^\s+//;
          my @labelInfo = split(/\s+/, $line);
          my $sIndex = $labelInfo[0];
          my $startFrame = $labelInfo[1];
          my $endFrame = $labelInfo[2];
          my $score = $labelInfo[3];
          my $label = $labelInfo[4]; 

          my $startTime = $segment_startTime + $startFrame * $frameRate;   
          my $endTime = $segment_startTime + ($endFrame+1) * $frameRate;
          #print HF "$line\n";
          print $new_transcription_handle "$startTime $endTime $label $score\n";

        # The transcription of this particular file has been found
          $fileFound = 1;
        }
      }
    }
    $this->close_file($julian_results_handle);
    if ($fileFound == 0) {
      print $new_transcription_handle $kLine."\n";
    }
  }
  close($new_transcription_handle);

  $this->debug("Mlf from res has been created.");
  
}

=head2 transcribe_silence_separated_segments

Transcribe voiced segments.

=cut
  
sub transcribe_silence_separated_segments {
  my $this=shift;
  my $silence_separated_segments_times_list = $this->{silence_separated_segments_times_list};
  my $silence_separated_segments_list = $this->{silence_separated_segments_list};
  my $transcription_file = $this->{silence_separated_segments_transcription_file};

  my $sourceRate = $this->{audio_code_config}{SOURCERATE};
  my $targetRate = $this->{audio_code_config}{TARGETRATE};
  my $realRate = floor($targetRate/$sourceRate)*$sourceRate;

  my $transcription_fhandle = $this->open_file($transcription_file, "write");
  my $segments_list_fhandle = $this->open_file($silence_separated_segments_list,"write");
  my $segments_times_list_fhandle = $this->open_file($silence_separated_segments_times_list,"read");

  while (<$segments_times_list_fhandle>) {
      chomp;
      my $kLine = $_;
      my @sInfo = split(" ", $kLine);
      my $segmentName = $sInfo[1];
      my $segmentStart_htkunits = $sInfo[2] || 0;
      my $segmentEnd_htkunits = $sInfo[3] || 0;
      my ($segment_basename, $dir, $ext) = fileparse($segmentName,'\.[^\.]*');
      my $segmentStart = $realRate*$segmentStart_htkunits;
      my $segmentEnd = $realRate*$segmentEnd_htkunits;
      print $transcription_fhandle "$segmentStart $segmentEnd $segment_basename\n";
      print $segments_list_fhandle $segmentName."\n";
  }
  $this->close_file($transcription_fhandle);
  $this->close_file($segments_list_fhandle);
  $this->close_file($segments_times_list_fhandle);

  #print $this->{fileName}."\n";
  $this->debug("The transcription of the silence separated segments has been completed");
}

=head1 AUTHOR

Athanasios Katsamanis, C<< <nkatsam at sipi.usc.edu> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-sailalign at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=SailAlign>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc SailTools::SegmentAudio


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

1; # End of SailTools::SegmentAudio

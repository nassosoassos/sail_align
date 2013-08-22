package SailTools::SailRecognizeSpeech;

use warnings;
use strict;
use File::Basename;
use POSIX qw(ceil floor);
use SailTools::SailComponent;
use SailTools::SailTranscriptionSet;
use SailTools::SailHtkWrapper;
use SailTools::SailAdaptation;
use File::Spec::Functions;
use Log::Log4perl qw(:easy);

=head1 NAME

SailTools::SailRecognizeSpeech - Utilities for speech recognition

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.06';
our @ISA = qw(SailTools::SailComponent);


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use SailTools::SailRecognizeSpeech;

    my $foo = SailTools::SailRecognizeSpeech->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 decode

Speech recognition using julius.
Usage: 
  $speech_recognizer->decode;

=cut
sub decode {
  my $this = shift;
  my $configurationFile = $this->{speech_recognize_config_file};
  my $scp_file      = $this->{speech_recognize_scp_file};
  my $speech_model_list = $this->{speech_model_list};
  my $speech_segment_list = $this->{speech_segments_list};
  my $speech_mfc_path = $this->{speech_mfcc_dir};
  my $mfcc_file_ext = $this->{mfcc_file_ext};
  my $language_model = $this->{language_model};
  my $dictionary = $this->{dictionary};
  my $models = $this->{speech_models};
  my $bin_dir = $this->{bin_dir};
  my $julius_results = $this->{decode_results_file};

  $this->print_recognize_scp($speech_segment_list, $scp_file, $speech_mfc_path, $mfcc_file_ext);

  my $julius_arguments = "-d $language_model -walign -v $dictionary -h $models -hlist $speech_model_list ".
                  "-siltail \"</S>\" -silhead \"<S>\" ".
                  "-filelist $scp_file > $julius_results ";

  my $output = $this->execute("julius",$julius_arguments, $bin_dir);                
  my @julius_output = @$output;

  my @error_indicators = grep { /Error|Fatal/i } @julius_output;  
  if (@error_indicators) {
     $this->fatal("@julius_output", "VoiceRec");
  } 
  else {
     $this->debug("Speech recognition ran successfully");  
  }
}

=head2 process_results

Process Julius results.
Usage:
  $speech_recognizer->process_results();

=cut
sub process_results {
  my $this = shift;

  my $firstFile=1;
  my $speech_segments_transcription_file = $this->{speech_segments_transcription_file};
  my $speech_segments_transcription_handle = $this->open_file($speech_segments_transcription_file,"read");
  my @transcription = <$speech_segments_transcription_handle>;
  $this->close_file($speech_segments_transcription_handle);

  my $word_transcription_file = $this->{word_transcription_file};
  my $word_transcription_handle = $this->open_file($word_transcription_file,"write");

  my $sourceRate = $this->{audio_code_config}{SOURCERATE};
  my $targetRate = $this->{audio_code_config}{TARGETRATE};
  my $frameRate = floor($targetRate/$sourceRate)*$sourceRate;
  
  foreach my $kLine (@transcription) {
    chomp($kLine);
    my @sInfo = split(" ", $kLine);
    my $segment_startTime = $sInfo[0];
    my $segment_endTime = $sInfo[1];
    my $baseName = $sInfo[2];
    my $startReading = 0;
    my $fileFound = 0;
    my $sentence;
    my @words;
    my $kWord=0;
    my $decode_results_file = $this->{decode_results_file};
    my $decode_results_handle = $this->open_file($decode_results_file, "read");
    while (<$decode_results_handle>) {
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
      if((/sentence1:(.*)/)&&($startReading==1)) {
        $sentence = $1;
        $sentence =~ s/^\s+//;
        @words = split(/\s+/, $sentence);
        $kWord = 0;
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
          if ($label =~/^sil$/) {
            print $word_transcription_handle "$startTime $endTime $label $score\n";
          }
          else {
            print $word_transcription_handle "$startTime $endTime ".$words[$kWord]." $score\n";
            $kWord++;
          }
  
          # The transcription of this particular file has been found
          $fileFound = 1;
        }
      }
    }
    $this->close_file($decode_results_handle);
    if ($fileFound == 0) {
      print $word_transcription_handle $kLine."\n";
    }
  }
  $this->close_file($word_transcription_handle);
  $this->debug("Word transcription file has been generated.");
}

=head2 align_speech_feature_set

Align transcriptions with audio for small segments
Input: the feature files, corresponding transcriptions, the output mlf filename, acoustic models
	 dictionary, alignment configuration
Usage:
  align_speech_feature_set( $feature_set_object_ref, $transcription_set_ref, $phone_alignment_filename
                              \%ac_model, \%dict_info, \%cfg );
=cut
sub align_speech_feature_set {
	    my ($seg_feature_set, $transcription_set, $phone_alignment_filename, $ac_model, $dict, $alignment_conf) = @_;	
	
		my $seg_feature_set_files = $seg_feature_set->get_files;
		my $n_aligned_segments = $seg_feature_set->{n_files};
		
		my $trans_dir = $transcription_set->{root_path};
		mkpath($trans_dir);
		for (my $segment_counter=0; $segment_counter<$n_aligned_segments; $segment_counter++) {
			my $seg_file = $seg_feature_set_files->[$segment_counter];
			my $s_bname = fileparse($seg_file,"\.[^\.]+");
			my $trans_file = catfile($trans_dir,$s_bname.".lab");
			$transcription_set->[$segment_counter]->write_clean_to_file($trans_file,'lab','words'); 	
		}
		my $dict_file = $dict->{file};
		my $file_list = $seg_feature_set->{list_abs_paths};
		SailTools::SailHtkWrapper::run_hvite_align($ac_model, $trans_dir, $phone_alignment_filename, $dict_file, $seg_feature_set->{list_abs_paths}, $alignment_conf);
}

=head2 recognize_fsg_speech_feature_set

Speech recognition using fsg
Input: the feature files, the acoustic models, the wordnet, the dictionary 
Usage:
  my $results_set_object_ref = recognize_fsg_speech_feature_set ( $feature_set_obect_ref, \%ac_model, $wd_net_file, \%dict_info, 
                                                                  $results_cfg_ref, \%cfg );

=cut
sub recognize_fsg_speech_feature_set {
	my ($feature_set, $ac_model, $wd_net_file, $dictionary, $results_cfg, $recognition_conf) = @_;
	
	$results_cfg->{name} = $feature_set->{name};
	my $result_set = new SailTools::SailTranscriptionSet($results_cfg);
	my $feature_files_ref = $feature_set->get_files();
	my $abs_files_ref = $result_set->get_files_from_parallel_file_array($feature_files_ref);

	my $file_list;

	DEBUG("Results set initialized OK!");
	if ($recognition_conf->{tool} eq 'htk') {
		$file_list = $feature_set->{list_abs_paths};
		my $dict_file = $dictionary->{file};
		my $output_directory = $results_cfg->{root_path};
		my $word_pron_ref = $dictionary->{words_pron};
		my %words_pron = %$word_pron_ref;
		my $sen_start = $recognition_conf->{sen_start};
		my $sen_end = $recognition_conf->{sen_end};
		my $sen_boundary_phon = $recognition_conf->{sen_boundary_phon};
		$words_pron{$sen_start} = $sen_boundary_phon;
		$words_pron{$sen_end} = $sen_boundary_phon;				
		SailTools::SailLanguage::add_short_pause_to_word_pronunciations(\%words_pron, $dictionary->{sp_model}, 'sil');
		SailTools::SailLanguage::print_htk_dictionary_into_file(\%words_pron, $dictionary->{output_symbols}, $dict_file);		
		SailTools::SailHtkWrapper::run_hvite_recognize_fsg($ac_model, $wd_net_file, $dict_file, $file_list, $output_directory, $recognition_conf);
		if ($recognition_conf->{filter_transcriptions}) {
			filter_transcriptions($file_list, $output_directory, $recognition_conf);
		}		
	}
	$result_set->init_from_files($abs_files_ref);

	return $result_set;
		
}

=head2 recognize_speech_feature_set 

Speech recognition given the features
Input: the set of features, the acoustic models, the language model, the configuration of the results, tool configuration
Output: The set of the results
Usage:
  my $results_set_object_ref = recognize_speech_feature_set ( $feature_set_obect_ref, \%ac_model, $la_model_info_ref, 
                                                              \%dict_info, \%results_cfg, \%cfg );

=cut
sub recognize_speech_feature_set {
	my ($feature_set, $ac_model, $la_model, $dictionary, $results_cfg, $configuration) = @_;
	$results_cfg->{name} = $feature_set->{name};
	my $result_set = new SailTools::SailTranscriptionSet($results_cfg);
	my $feature_files_ref = $feature_set->get_files();
	my $abs_files_ref = $result_set->get_files_from_parallel_file_array($feature_files_ref);
	
	my $file_list;
	
	DEBUG("Results set initialized OK!");
	if ($configuration->{tool} eq 'htk') {
		$file_list = $feature_set->{list_abs_paths};
		my $dict_file = $dictionary->{file};
		my $output_directory = $results_cfg->{root_path};
		if ($configuration->{binary} eq 'HVite') {
			my $word_pron_ref = $dictionary->{words_pron};
			my %words_pron = %$word_pron_ref;					
			SailTools::SailLanguage::add_short_pause_to_word_pronunciations(\%words_pron, $dictionary->{sp_model}, 'sil');
			SailTools::SailLanguage::print_htk_dictionary_into_file(\%words_pron, $dictionary->{output_symbols}, $dict_file);		
			SailTools::SailHtkWrapper::run_hvite_recognize_lm($ac_model, $la_model, $dict_file, $file_list, $output_directory, $configuration);
		}
		elsif ($configuration->{binary} eq 'HDecode') {
			SailTools::SailLanguage::print_htk_dictionary_into_file($dictionary->{words_pron}, $dictionary->{output_symbols}, $dict_file);		
			SailTools::SailHtkWrapper::run_hdecode_recognize_lm($ac_model, $la_model, $dict_file, $file_list, $output_directory, $configuration);
			if ($configuration->{filter_transcriptions}) {
				my $word_pron_ref = $dictionary->{words_pron};
				my %words_pron = %$word_pron_ref;		
				SailTools::SailLanguage::add_short_pause_to_word_pronunciations(\%words_pron, $dictionary->{sp_model}, 'sil');
				SailTools::SailLanguage::print_htk_dictionary_into_file(\%words_pron, $dictionary->{output_symbols}, $dict_file);
				my $align_conf = $configuration->{alignment};
				$align_conf->{output_words} = 1;
				$align_conf->{output_dir} = $output_directory;
				$align_conf->{out_suffix} = 'rec';
				$align_conf->{in_suffix} = 'rec';
				
				SailTools::SailHtkWrapper::run_hvite_align($ac_model, $output_directory, "", $dict_file, $file_list, $align_conf);				
			}		
		}
		if ($configuration->{filter_transcriptions}) {
			filter_transcriptions($file_list, $output_directory, $configuration);
		}		
	}
	$result_set->init_from_files($abs_files_ref);
	
	return $result_set;
}

=head2 

Fileter short pauses from the transcriptions.
Input: List of transcription files, Transcription directory, Configuration hash
Output: None
Usage:
  filter_transcriptions( $file_list, $transcription_dir, \%cfg);

=cut
sub filter_transcriptions {
	my ( $file_list, $trans_dir, $configuration) = @_;
    # Filter short pauses from the transcriptions
	my $filtered_models = $configuration->{filtered_models};
	my @filtered_models_arr = @$filtered_models;
		
	my $feature_files_ref = SailTools::SailComponent::read_from_file($file_list);
		
	foreach my $f_file (@$feature_files_ref) {
		my ($f_bname, $f_path, $f_sfx) = fileparse($f_file,'\.[^\.]+');
		my $lab_file = catfile($trans_dir, $f_bname.'.rec');
		my $sav_file = catfile($trans_dir, $f_bname.'.rec.bak');
			
		if (-e $lab_file) {					
			open(LAB, $lab_file);
            open(SAV, ">$sav_file");
			my @transcription;
			my $start_time = 0;
			my $end_time = 0;
			my $label = "";
			while(<LAB>) {
				my $line = $_;
                print SAV $line;
				chomp($line);	
				my @elements = split(/\s+/,$line);
				my $n_elements = @elements;
                if ($n_elements < 2) {
                    next;
                }
				my $model = $elements[2];
                if (defined($model)) {
    				if (grep(/$model/,@filtered_models_arr)) {
	    				if ($end_time>0) {
		    				push(@transcription, "$start_time $end_time $label");										
			    		}
				    	$end_time = 0; 
				    	next;
			    	}
                }
				if ($n_elements>3) {
					if ($end_time>0) {
						push(@transcription, "$start_time $end_time $label");										
					}
					$start_time = $elements[0]; 
					$end_time = $elements[1];
					$label = $elements[3];
				}
				else {				
					$end_time = $elements[1];					
				}				
			}
			close(LAB);
            close(SAV);
			SailTools::SailComponent::print_into_file(\@transcription, $lab_file);
		}
	}	
}

=head2 recognize_speech

Recognizing speech using julius and processing the results.

=cut
sub recognize_speech {
  my $this = shift;

  $this->decode;
  $this->process_results;
  $this->debug("Speech Recognition has been completed");
}

=head2 write_xml_results 

Write the recognition results in XML format.
Usage:
  $speech_recognizer->write_xml_results;

=cut
sub write_xml_results {
  my $this = shift;
  my $fileName = $this->{fileName};
  my $results_dir = $this->{results_dir};

  my @files;
  my @ASR_files;
  my $input_type = "";
  my $input_type2 = "";
  my $silent = 0;		# silent mode
  my $input_debug = 1;
  my $ASRResultsDir = "../results";
  
  my $segment_count = 0;
  my $seg_start = "";
  my $seg_end = "";
  my $word_string;
  my $flag =0;

  my $speech_segments_times_file = $this->{speech_segments_cut_times_file};
  my $speech_segments_times_handle = $this->open_file($speech_segments_times_file,"read");

  my $decode_results_file = $this->{decode_results_file};
  my $decode_results_handle = $this->open_file($decode_results_file,"read");

  
  ###########################
  # MAIN PROCESSING ROUTINE #
  ###########################
  my $basename = fileparse($fileName, '\.[^\.]*');
  my $xml_fileName = "$basename.xml";
  my $word_transcription_xml_handle = new IO::File("> $results_dir/$xml_fileName");
  
  print $word_transcription_xml_handle "<?xml version=\"1.0\" encoding=\"ISO-8859-1\" ?>\n"; 
  print $word_transcription_xml_handle "\n"; 
  print $word_transcription_xml_handle "<SpeechAnnotation project=\"SAIL\">\n";  
  print $word_transcription_xml_handle "<Header type=\"SpeechRecognition\">\n"; 
  print $word_transcription_xml_handle "\n\n";
    
  my $creation_time = localtime(time);    

  print $word_transcription_xml_handle "\t<CreationTime>$creation_time<\/CreationTime>\n";
  print $word_transcription_xml_handle "\t<LastUpdate>$creation_time<\/LastUpdate>\n";
  print $word_transcription_xml_handle "\t<Comment>Speech Processing word_transcription_xml_handle<\/Comment>\n";
  print $word_transcription_xml_handle "\t<Creator>SAIL<\/Creator>\n";
  print $word_transcription_xml_handle "\t<Tool version=\"1.0\"> SAIL Speech Subsystem<\/Tool>\n";
  print $word_transcription_xml_handle "\n\n";
  print $word_transcription_xml_handle "<\/Header>\n";
  print $word_transcription_xml_handle "<ASR>\n";
  print $word_transcription_xml_handle "<NewDataSet>\n";
  print $word_transcription_xml_handle  "<Source>\n";

  my ($channel_name, $date, $time, $other) = split(/_/, $xml_fileName);
  print $word_transcription_xml_handle "<Name>$channel_name<\/Name>\n";
  my $day = substr($date,0,2);
  my $month = substr($date,2,2);
  my $year = substr($date,4,4);
  my ($hours, $mins) = split(/h/, $time);

  my $secs = "00";
  print $word_transcription_xml_handle "\t<Speech Language=\"EN\" StartingDT=\"$year-$month-$day $hours:$mins:$secs\">\n";
    
   while (<$speech_segments_times_handle>) {
        $segment_count++;
        my @seg_timestamps = split(/\s+/);
        $seg_start = ( $seg_timestamps[0] / 10000000);
        $seg_end = ( $seg_timestamps[1] / 10000000);
        my $segment_duration = $seg_end - $seg_start;
    
        ### update XML file
        my $seg_id = join('',"p",$segment_count);
        $secs += $segment_duration;
       
        if ($secs>=60) {	
	       my $seg_mins = int(($secs-($secs%60))/60);
               $mins += $seg_mins;
               $secs = $secs%60;
	       if ($mins>=60) {
		  my $seg_hours = ($mins-($mins%60))/60;
		  $hours += $seg_hours;
		  $mins = $mins%60;
	       } 
        }
  	my $dhours = $hours;
 	my $dmins = $mins;
	my $dsecs = $secs;
        if (($hours<10) && ($hours>0)) {
	 $dhours = '0'.$hours;
        }
        if (($mins<10) && ($mins>0)) {
          $dmins = '0'.$mins;
        } 
	if (($secs<10) && ($secs>0)) {
	  $dsecs = '0'.$secs;
	}
       
        my $segment_transcription_string = "\t\t<SpeechPassage StartingDT=\"$year-$month-$day $dhours:$dmins:$dsecs\" PassageDuration=\"$segment_duration\">\n";
        $flag =0;
        while (<$decode_results_handle>) {
          if  (/sentence1/) {
            $word_string = $_;
              $flag =1;
          } if ($flag == 1) {last; }
        }
        $flag =0;
        $word_string =~ s/(sentence1\:)//;
        $word_string =~ s/^\s+//;
        my @word_list = split(/\s+/,$word_string);
	my $nwords = @word_list;
        foreach my $word_element ( @word_list) {
          $segment_transcription_string .= "\t\t\t<Word>\n";  
          $segment_transcription_string .= "\t\t\t\t<WordTXT>".$word_element."<\/WordTXT>\n";
          $segment_transcription_string .= "\t\t\t\t<WordNorm>"."<\/WordNorm>\n";
	  $segment_transcription_string .= "\t\t\t\t<SpeechWord WordDuration=\"0\"\/>\n";
          $segment_transcription_string .= "\t\t\t<\/Word>\n";
        }
        $segment_transcription_string .= "\t\t<\/SpeechPassage>\n";
	if ($nwords > 0) {
		print $word_transcription_xml_handle $segment_transcription_string;
	}
  

      }
  
      print $word_transcription_xml_handle "\t<\/Speech>\n";
      print $word_transcription_xml_handle "<\/Source>\n";
      print $word_transcription_xml_handle "<\/NewDataSet>\n\n\n";
      my $log_string = $this->dump_log;
      print $word_transcription_xml_handle $log_string."\n";
      print $word_transcription_xml_handle "<\/ASR>\n";
      $word_transcription_xml_handle->close; 
      $this->close_file($speech_segments_times_handle);
      $this->close_file($decode_results_handle);
      $this->debug("Xml file has been written.");  

}

=head1 AUTHOR

Athanasios Katsamanis, C<< <nkatsam at sipi.usc.edu> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-sailalign at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=SailAlign>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc SailTools::SailRecognizeSpeech


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

1; # End of SailTools::SailRecognizeSpeech

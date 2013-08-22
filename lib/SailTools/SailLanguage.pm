package SailTools::SailLanguage;

use warnings;
use strict;
use Log::Log4perl qw(:easy);
use File::Path;
use File::Basename;
use Data::Dumper;
use SailTools::SailDataSet;
use File::Spec::Functions;

=head1 NAME

SailTools::SailLanguage - Various utilities for language specifics for speech recognition and alignment

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';
our @ISA = qw(SailTools::SailComponent SailTools::SailHtkWrapper);


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use SailTools::SailLanguage;

    my $foo = SailTools::SailLanguage->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=cut

=head2 create_dictionary

Create a dictionary as a hash, given dictionary files in the HTK/CMU format. 
Input: Reference to array of filenames (all reference dictionaries), format (generic/htk)
Output: Reference to the dictionary hash $dictionary{$word} = $pronunciation.

Usage:
  my $dict_hash_ref = create_dictionary ( \@reference_dict_ref_array, $format );

=cut
sub create_dictionary {
	my ($dict_list_ref, $format) = @_;
	if (@_<2) {
	   $format = 'generic';
	}
	my %dictionary=();

    my %phon_map;
	foreach my $dict_file (@$dict_list_ref) {
		# Parse generic dictionary and save all words/pronunciations
		open(IN,$dict_file) || FATAL("Cannot open file $dict_file for reading");
		my $line;
		while ($line = <IN>){
    		chomp($line);
    		my ($word, @pron_arr) = split(/\s+/,$line);
            foreach my $ph (@pron_arr) {
                $phon_map{$ph}++;
            }
    		my $pron = join(" ", @pron_arr);
		
		# Pronunciation needs to be "lower-case". 
        # No it doesn't (I think).
        #	$pron = lc($pron);

		if ($format eq 'htk') {
		   $word =~ s/[^\\]\'/\\'/g;
		   $word =~ s/[^\\]\"/\\"/g;
		}

		    # Save list of words and corresponding pronunciations
		    $dictionary{$word} = $pron;
		}
		close(IN);
	}
    my @phon_array = sort keys %phon_map;
	return (\%dictionary, \@phon_array);
}

=head2 create_dictionary_apply_phone_map

Create a dictionary as a hash, given dictionary files in the HTK/CMU format. 
Input: Reference to array of filenames (all reference dictionaries), file mapping original
       phonemes to new ones 
Output: Reference to the dictionary hash $dictionary{$word} = $pronunciation.

Usage:
  my $dict_hash_ref = create_dictionary_apply_phone_map( \@reference_dict_ref_array, $phone_map_file, $format );

=cut
sub create_dictionary_apply_phone_map {
	my ($dict_list_ref, $phone_map_file, $format) = @_;
	if (@_<3) {
	   $format = 'generic';
	}
	my %dictionary=();

    open(PMAP, "$phone_map_file") || FATAL("Cannot open phone map file: $phone_map_file for reading");
    my %phone_map;
    while(<PMAP>) {
        my $line = $_;
        chomp($line);
        my ($orig_ph, $target_ph) = split(/\s+/, $line);
        $phone_map{$orig_ph} = $target_ph;
    }
    close(PMAP);
    my %phone_set;
	foreach my $dict_file (@$dict_list_ref) {
		# Parse generic dictionary and save all words/pronunciations
		open(IN,$dict_file) || FATAL("Cannot open file $dict_file for reading");
		my $line;
		while ($line = <IN>){
    		chomp($line);
    		my ($word, @pron_arr) = split(/\s+/,$line);
            my $n_phones = @pron_arr;
            
            for (my $phone_counter=0; $phone_counter<$n_phones; $phone_counter++) {
                my $ph = $pron_arr[$phone_counter];
                if (exists $phone_map{$ph}) {
                  $ph = $phone_map{$ph};
                }
                else {
                    FATAL("Phoneme $ph not found in the phonemap.") and die();
                }
                $pron_arr[$phone_counter] = $ph;
                $phone_set{$ph}++;
            }
    		my $pron = join(" ", @pron_arr);
		
		# Pronunciation needs to be "lower-case"
    		$pron = lc($pron);

		if ($format eq 'htk') {
		   $word =~ s/[^\\]\'/\\'/g;
		   $word =~ s/[^\\]\"/\\"/g;
		}

		    # Save list of words and corresponding pronunciations
		    $dictionary{$word} = $pron;
		}
		close(IN);
	}
    my @phon_array = sort keys %phone_set;
	return (\%dictionary, \@phon_array);
}

=head2 compare_phone_sets

Compare two phonesets to see whether the second is a subset of the
first.
Input: Reference to the reference phoneset, reference to the target phoneset
Output: Boolean saying whether the phonesets are compatible or not.
Usage:
  my $same_phonesets = compare_phone_sets( \@phone_set, \@target_phone_set);
=cut
sub compare_phone_sets {
    my ($ref_set, $target_set) = @_;

    my $compatible_phonesets = 1;
    my %phone_set;
    foreach my $ph (@$ref_set, @$target_set) {
        $phone_set{$ph}++;
    }
    foreach my $ph (@$target_set) {
        if ($phone_set{$ph}<2) {
            $compatible_phonesets = 0;
            last;
        }
    }
    return $compatible_phonesets;
}

=head2 convert_triphone_transcription_to_monophone

Convert triphones of a transcription to the corresponding monophones
Input: The transcription to be converted (SailTranscription object)
Usage:
  convert_triphone_transcription_to_monophone ( $transcription_object_ref );
=cut
sub convert_triphone_transcription_to_monophone {
    my $transcription_ref = shift;

    my $words_ref = $transcription_ref->{words};
    my $n_words = @$words_ref;
    for (my $word_counter=0; $word_counter<$n_words; $word_counter++) {
        my $cur_triphone = $transcription_ref->{words}->[$word_counter];
        my $cur_monophone = $cur_triphone;

        if ($cur_triphone =~ /([^-]+)-([^+]+)\+(.+)/) {
            $cur_monophone = $2;
        }
        elsif ($cur_triphone =~ /([^-]+)-([^+]+)/) {
            $cur_monophone = $2;
        }
        elsif ($cur_triphone =~ /([^+]+)\+(.+)/) {
            $cur_monophone = $1;
        }
        else {
            $cur_monophone = $cur_triphone;
        }
        $transcription_ref->{words}->[$word_counter] = $cur_monophone;
    }

}

=head2 convert_transcription_phoneset

Convert transcription phoneset
Input: The transcription whose phoneset will be converted
Usage:
  convert_transcription_phoneset ( $transcription_object_ref, $phone_map_file ); 

=cut
sub convert_transcription_phoneset {
    my ($transcription_ref, $phone_map) = @_;

    my %p_map;
    open(PM, "$phone_map") or die("Cannot open phone map $phone_map for reading");
    while(<PM>) {
        my $line = $_;
        chomp($line);
        my ($orig, $target) = split(/\s+/, $line);
        $p_map{$orig} = $target;
    }
    close(PM);

    my $phones_ref = $transcription_ref->{words};
    my $n_phones = @$phones_ref;

    for (my $phone_counter=0; $phone_counter<$n_phones; $phone_counter++) {
        my $cur_ph = $transcription_ref->{words}->[$phone_counter];
        if (exists $p_map{$cur_ph}) { 
            $transcription_ref->{words}->[$phone_counter] = $p_map{$cur_ph};
        }
        else {
            if ($transcription_ref->{start_times}->[$phone_counter] > -1) { 
              WARN("Problematic inverse phone mapping. Some phonemes may be missing: $cur_ph");
            }
        }
    }
}

=head2 word_pronounciations_from_dictionary

Get specific word pronounciations for the given list of words. 
Assume that there might be entrances for multiple pronounciations, in which case
there are multiple word entries tailed by an identifying number.
Input: Reference to array of words, reference to dictionary hash
Output: Reference to resulting dictionary hash, reference to list of words not found in the dictionary
Usage: 
  ($dict_hash_ref, $unknown_word_list_ref) = word_pronounciations_from_dictionary( \@words, \%dictionary);

=cut
sub word_pronounciations_from_dictionary{
	my ($word_list_ref, $dictionary_ref) = @_;
	my %word_dict=();
	my @unknown_words = ();
	
	my @dict_entries = keys %$dictionary_ref;
	
	foreach my $word (@$word_list_ref) {
		# Take care of multiple pronunciations
		my @matching_entries = grep {/^[\\]*(\Q$word\E|\Q$word\E\(\d*\))$/i} @dict_entries;
				
		my $n_matching_entries = @matching_entries;
		if (@matching_entries) {
			foreach my $matching_entry (@matching_entries) {
				$word_dict{lc($matching_entry)} = $dictionary_ref->{$matching_entry};
			}
		}
		else {
			push(@unknown_words, $word);
		}
	}
	return (\%word_dict,\@unknown_words);
} 

=head2 print_dictionary_into_file 

Dictionary printing into file. The dictionary is represented by a hash of 
the form: $dict{$word} = $pronounciation. Two columns are plotted, i.e.,
word pronounciation. The words are sorted.
Input: Reference of the dictionary hash, the name of the file

Usage:
  print_dictionary_into_file( $dict_hash_ref, $filename ); 

=cut
sub print_dictionary_into_file {
	my ($dict_ref, $file_name) = @_;
	
	open(FILE,">$file_name") || FATAL("Cannot open file $file_name for writing");
	foreach my $word (sort (keys %$dict_ref)) {
		my $pronounciation = $dict_ref->{$word};
		$word =~ s/\(\d+\)//;
		print FILE "$word $pronounciation\n"
	}
	close(FILE);
}

=head2 print_htk_dictionary_into_file

HTK Dictionary printing into file. The dictionary is represented by a hash of 
the form: $dict{$word} = $pronounciation. Two columns are plotted, i.e.,
word pronounciation. The words are sorted. HTK allows for different output symbols 
than the words themselves.
Input: Reference of the dictionary hash, reference of the output symbol hash, the name of the file
Usage:
  print_htk_dictionary_into_file( \%dictionary, \%output_symbols_map, $file_name );

=cut
sub print_htk_dictionary_into_file {
	my ($dict_ref, $output_symbols_ref, $file_name) = @_;
	
	open(FILE,">$file_name") || FATAL("Cannot open file $file_name for writing");
	foreach my $word (sort (keys %$dict_ref)) {
		my $pronounciation = $dict_ref->{$word};
		$word =~ s/\(\d+\)//;
		if (exists $output_symbols_ref->{$word}) {
			my $output_symbol = $output_symbols_ref->{$word};
			print FILE "$word $output_symbol $pronounciation\n";
		}
		else {
			print FILE "$word $pronounciation\n";					
		}
	}
	close(FILE);
}

=head2 add_short_pause_to_word_pronunciations

Add short pause to the end of each word in the pronunciation dictionary
Input: The dictionary hash and the short pause model symbol
Usage:
  add_short_pause_to_word_pronunciations ( \%dictionary, $short_pause_symbol, $silence_symbol );

=cut
sub add_short_pause_to_word_pronunciations {
	my ($dict_ref, $short_pause, $silence) = @_;
	
	foreach my $word (keys %$dict_ref) {
		my $pron = $dict_ref->{$word};
		
		if ($pron =~ /$silence\s*$/) {
			next;
		}
		else{
		 	$dict_ref->{$word} .= " $short_pause";
		}
	}
}

=head2 build_language_model

Build a language model given a text corpus. 
Input: a saildataset object to represent the text corpus, list of words, configuration hash for the modeling
(e.g. which tool is to be used, where are the binaries)
Output: reference to a hash with language model information
Usage:
  my $lang_model_hash_ref = build_languuage_model( \%text_corpus, \%word_list_info, \%cfg, \%background_lm_model );

=cut
sub build_language_model {
	my ($text_corpus, $word_list_ref, $cfg, $back_model) = @_;
	
	my $language_model_ref;
	if ($cfg->{tool} eq 'srilm') {
		$language_model_ref = build_sri_language_model($text_corpus, $word_list_ref, $cfg, $back_model);
	}
	return $language_model_ref;	
}

=head2 build_sri_language_model

Build a language model using srilm
Input: a saildataset object to represent the text corpus, configuration hash for the modeling
(e.g. which tool is to be used, where are the binaries)
Output: reference to a hash with language model information
Usage:
  my $language_model_ref = build_sri_language_model ( \%text_corpus, \%word_info, \%cfg, \%backgroun_lm_model );
=cut
sub build_sri_language_model {
	my ($text_corpus, $word_list_ref, $cfg, $b_model) = @_;
	
	my %language_model = ();
	# Tool properties
	my $tool_options = $cfg->{options};
	my $order = $cfg->{order};
	my $sri_binary = catfile($cfg->{bin_path}, $cfg->{binary});
	my $lm_file = catfile($cfg->{path}, $cfg->{name}.'.'.$cfg->{suffix});
	mkpath($cfg->{path});
	my $oov_symbol = $cfg->{oov_symbol};
	$oov_symbol =~ s/([<>])/\\$1/g;
	my @error_indicators;
	
	# Special case if there is only one file in the dataset
	if ($text_corpus->{n_files}==1) {
		my $file = $text_corpus->get_next_file_abs_path; 
		my $vocab_file = $word_list_ref->{file};

		my $cmd = $sri_binary." -".join(" -",@$tool_options)." -unk -map-unk $oov_symbol".
						" -limit-vocab $vocab_file -text $file -order $order -lm $lm_file ";
		my $cmd_out = SailTools::SailComponent::run($cmd);		
		@error_indicators = grep {/Error|USAGE/i} @$cmd_out;		
		if ($cfg->{use_back_lm}) {
			my $back_weight = $cfg->{back_lm_weight};
			my $back_lm_file = $b_model->{file};
			my $merge_binary = catfile($cfg->{bin_path}, $cfg->{merge_binary});
			$cmd = $merge_binary." -lm $back_lm_file -lambda $back_weight -mix-lm $lm_file".
						" -write-lm $lm_file -order $order";
			$cmd_out = SailTools::SailComponent::run($cmd);		
			@error_indicators = grep {/Error|USAGE/i} @$cmd_out;					
		}
	} 
	else {
		FATAL("LM from multiple files is not yet implemented.");
	}
	if (!@error_indicators) {
		$language_model{file} = $lm_file;
		$language_model{format} = $cfg->{format};
		$language_model{order} = $cfg->{order};
		$language_model{word_list} = $word_list_ref;
		$language_model{oov_symbol} = $cfg->{oov_symbol};
		return \%language_model;
	}
	else {
		FATAL("Unsuccessful language model building.");
	} 
}

=head2 prepare_align_fsg

Generate a restrictive finite state grammar that can at most generate 
the given word sequence.
Input: The word sequence, the dictionary, the filenames of the grammar, the wordnet
		and the new dictionary, the configuration 
Usage:
  prepare_align_fsg( \@segment_words, $grammar_file, $wd_net_file, \%cfg );

=cut
sub prepare_align_fsg {
	my ($seg_words, $grammar_file, $wd_net_file, $config) = @_;
	
	open(GRAM, ">$grammar_file") || (FATAL("Cannot open grammar file $grammar_file for writing.") && die());
	my $sent_start_symbol = $config->{sen_start};
	my $sent_end_symbol = $config->{sen_end};
	print GRAM "(\n $sent_start_symbol ";
	foreach my $word (@$seg_words) {
		if ($word ne $config->{oov_symbol}) {
			if ($config->{allow_deletions}) {
				print GRAM "[$word] ";
			}
			else {
				print GRAM "$word ";				
			}
		}
	}
	print GRAM "$sent_end_symbol\n)";	
	close(GRAM);
	SailTools::SailHtkWrapper::run_hparse($grammar_file, $wd_net_file, $config);		
}

=head2 convert_language_model_to_lattice 

Convert a language model to a different format
Input: the original language model cell, the target language model configuration (both containing information
like path, format etc.), the tool configuration
Output: the converted language model
Usage:
  my $lattice_ref = convert_language_model_to_lattice (\%language_model, \%target_model, \%cfg);

=cut
sub convert_language_model_to_lattice {
	my ($source_model_ref, $target_model_ref, $tool_conf_ref) = @_;
	my $language_model;
	
	if ($target_model_ref->{format} eq 'htk') {
		$language_model = hbuild_convert_lm_to_lattice($source_model_ref, $target_model_ref, $tool_conf_ref);
	} 
	return $language_model;
}

=head2 hbuild_convert_lm_to_lattice

Wrapper to the tool HBuild of htk to convert language model to htk lattice
Input: the original language model cell, the target lattice configuration, the tool configuration
Output: the resulting lattice
Usage:
  my $target_lattice_ref = hbuild_convert_lm_to_lattice ( \%source_lm, \%target_lm, \%cfg );

=cut
sub hbuild_convert_lm_to_lattice {
	my ($source_model_ref, $target_model_ref, $tool_conf_ref) = @_;
	
	my $source_file_name = $source_model_ref->{file};
	my $word_list_file = $source_model_ref->{word_list}->{file};
	my $utterance_delimiters = $target_model_ref->{utterance_delimiters};
	my $oov_symbol = $source_model_ref->{oov_symbol};
	my $target_file_name;
	my %target_lattice;
	if ($target_model_ref->{file}) {
		$target_file_name = $target_model_ref->{file};
	}
	else {
		my $bname = fileparse($source_file_name, "\.[^\.]*");
		$target_file_name = catfile($target_model_ref->{path}, $bname.".".$target_model_ref->{suffix});
	}
	SailTools::SailHtkWrapper::run_hbuild($source_file_name, $target_file_name, $word_list_file, $utterance_delimiters, $oov_symbol, $tool_conf_ref);
	
	$target_lattice{file} = $target_file_name;
	$target_lattice{word_list} = $source_model_ref->{word_list};
	$target_lattice{utterance_delimiters} = $utterance_delimiters;
	$target_lattice{oov_symbol} = $oov_symbol;
	
	return \%target_lattice; 
} 

=head2 get_word_output_symbols_from_file 

There are cases in recognition where we should have different output symbols than
the words that are being recognized. These output symbols can be given in a two column
file. 
Input: The path to the two-column file
Output: A reference to a hash that gives the output symbol for each word
Usage: 
  $map_hash_ref = get_word_output_symbols_from_file ( $filename );

=cut
sub get_word_output_symbols_from_file {
	my $output_symbol_file = shift;
	my %output_symbol_hash;
	open(OSYMFILE,"$output_symbol_file") || die("Cannot open file $output_symbol_file\n");
	while (<OSYMFILE>) {
		my $line = $_;
		chomp($line);
		if ($line =~ /^([^\s]+)\s+(.*)/) {
                        my $w = $1;
                        $w = lc($w);
			$output_symbol_hash{$w} = $2;
		}
	}
	close(OSYMFILE);
	return \%output_symbol_hash; 
}


=head1 AUTHOR

Athanasios Katsamanis, C<< <nkatsam at sipi.usc.edu> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-sailalign at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=SailAlign>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc SailTools::SailLanguage


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

1; # End of SailTools::SailLanguage

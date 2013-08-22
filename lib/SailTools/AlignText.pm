package SailTools::AlignText;

use warnings;
use strict;
use File::Path;
use File::Spec::Functions;
use Data::Dumper;
use File::Basename;
use List::Util qw[min max sum];
use SailTools::SailComponent;
use SailTools::SailSignal;
use SailTools::VoiceActivityDetection;
use SailTools::FeatureExtractor;
use SailTools::SailSegment;
use SailTools::SailLanguage;

use Log::Log4perl qw(:easy);

=head1 NAME

SailTools::AlignText - Utilities for text alignment

=head1 VERSION

Version 0.01

=cut

our $VERSION = '1.00';
our @ISA = qw(SailTools::SailComponent);

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use SailTools::AlignText;

    my $foo = SailTools::AlignText->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 new

Mainly initialize paths and configuration

=cut

sub new {
    my ($class, $cfg) = @_;
    my $self;

    $self->{working_dir} = $cfg->{working_dir};
    $self->{bin_path} = $cfg->{bin_path};
    $self->{min_n_aligned_words} = 3;
	mkpath($self->{working_dir});
    bless($self, $class);
}

=head2 erode_array

Perform erosion of a one-dimensional signal using a given structuring element.
This is used to impose a minimum length to the aligned regions, for robustness.

=cut

sub erode_array {
	my ($array_ref, $strel) = @_;
	
	my @temp_array = @$array_ref;
	@temp_array =(((-1)x($strel-1)), @temp_array,((-1)x($strel-1)));  
	my $n_elems = @$array_ref;
	# Find unreliably aligned words
	for (my $el_counter=$strel-1; $el_counter<$n_elems+$strel-1; $el_counter++) {
		my @back_win = @temp_array[$el_counter-$strel+1..$el_counter];
		my @fwd_win = @temp_array[$el_counter..$el_counter+$strel-1];
		my $flag = max(min(@back_win),min(@fwd_win));
		if ($flag<0) {
			$array_ref->[$el_counter-$strel+1] = -1;			
		}
	}
	@temp_array = @$array_ref;
	@temp_array =(((-1)x($strel-1)), @temp_array,((-1)x($strel-1)));
	# Expand unaligned regions that are too small  
	for (my $el_counter=$strel-1; $el_counter<$n_elems+$strel-1; $el_counter++) {
		my $prev_elm = $temp_array[$el_counter-1];
		my $next_elm = $temp_array[$el_counter+1]; 
		if (($temp_array[$el_counter]==-1) && ($prev_elm>-1) && ($next_elm>-1)) {
			$array_ref->[$el_counter-$strel] = -1;
			$array_ref->[$el_counter-$strel+2] = -1;
			$temp_array[$el_counter-1] = -1;
			$temp_array[$el_counter+1] = -1;
		} 
	}
}

=head2 align_transcriptions

Use text alignment (e.g., with the sclite tool) to align two transcriptions
Input: The hypothesis transcription and the reference transcription

=cut

sub align_transcriptions {
	my ($this, $hyp_trans, $ref_trans, $config) = @_;
	
	my $hyp_file = catfile($this->{working_dir}, 'hyp_'.$hyp_trans->{name}); 
	my $ref_file = catfile($this->{working_dir}, 'ref_'.$ref_trans->{name});
	my $uncertainty = $config->{iteration};
	
	$hyp_trans->write_clean_to_file($hyp_file,'txt','words');
	$ref_trans->write_clean_to_file($ref_file,'txt','words');
	
	my $true_words = $ref_trans->{words};
	my $n_true_words = @$true_words;
	
	my ($alignment_info, $ref_words, $hyp_words) = $this->align_text_files($hyp_file, $ref_file);
	
	my $n_words = @$ref_words;
	
	if ($n_words ne $n_true_words) {
		WARN("Something wrong with speech recognition or text alignment, true words: $n_true_words found words: $n_words");
	}
	
	if (($this->{min_n_aligned_words}<$n_words) and ($this->{min_n_aligned_words}>1)){
		erode_array($alignment_info,$this->{min_n_aligned_words});
	}
	my $hyp_start_times = $hyp_trans->{start_times};
	my $hyp_end_times = $hyp_trans->{end_times};
	my $ref_start_times = $ref_trans->{start_times};
	my $ref_end_times = $ref_trans->{end_times};
	my $ref_uncertainties = $ref_trans->{uncertainties};
	my $n_aligned_words = 0;
	for (my $word_counter=0; $word_counter<$n_words; $word_counter++) {
		my $word_alignment_ind = $alignment_info->[$word_counter];
		if ($word_alignment_ind==-1) {
			$ref_start_times->[$word_counter] = -1;
			$ref_end_times->[$word_counter] = -1;			
		}
		else {
			$ref_start_times->[$word_counter] = $hyp_start_times->[$alignment_info->[$word_counter]];
			$ref_end_times->[$word_counter] = $hyp_end_times->[$alignment_info->[$word_counter]];
			$ref_uncertainties->[$word_counter] = $uncertainty;
			$n_aligned_words++;						
		}
	}
	return ($n_aligned_words, $n_words); 
}

=head2 compare_transcriptions

Use text alignment to compare two transcriptions

=cut

sub compare_transcriptions {
	my ($this, $hyp_trans, $ref_trans) = @_;
	
	my $hyp_file = catfile($this->{working_dir}, 'hyp_'.$hyp_trans->{name}); 
	my $ref_file = catfile($this->{working_dir}, 'ref_'.$ref_trans->{name});
	
	$hyp_trans->write_clean_to_file($hyp_file,'txt','words');
	$ref_trans->write_clean_to_file($ref_file,'txt','words');
	
	my $true_words = $ref_trans->{words};
	my $n_true_words = @$true_words;
	
	my ($alignment_info, $ref_words, $hyp_words) = $this->align_text_files($hyp_file, $ref_file);
	
	open(TMP1,">tmp1.txt");
	print TMP1 join("\n",@$true_words);
	close(TMP1);

	open(TMP2,">tmp2.txt");
	print TMP2 join("\n",@$ref_words);
	close(TMP2);
	
	my $n_words = @$ref_words;
	
	if ($n_words ne $n_true_words) {
		WARN("Something wrong with speech recognition or text alignment, true words: $n_true_words found words: $n_words");
	}
	
	my $hyp_start_times = $hyp_trans->{start_times};
	my $hyp_end_times = $hyp_trans->{end_times};
	my $ref_start_times = $ref_trans->{start_times};
	my $ref_end_times = $ref_trans->{end_times};
	
	my $n_ref_times = @$ref_start_times;
	
	my $n_aligned_words = 0;
	my $n_unaligned_words = 0;
	my $n_unknown_words = 0;
	my @unknown_words;
	my @unaligned_words;
	my $time_diff=0;
	for (my $word_counter=0; $word_counter<$n_words; $word_counter++) {
		my $word_alignment_ind = $alignment_info->[$word_counter];
		if ($word_alignment_ind==-1) {
			push(@unknown_words, $true_words->[$word_counter]);
			$n_unknown_words++;
		}
		else {
			my $hyp_start = $hyp_start_times->[$alignment_info->[$word_counter]];
			my $hyp_end = $hyp_end_times->[$alignment_info->[$word_counter]];
			if ($alignment_info->[$word_counter]<$n_words) {
				my $ref_start = $ref_start_times->[$word_counter];
				my $ref_end = $ref_end_times->[$word_counter];
				
				if ($hyp_start==-1) {
					$n_unaligned_words++;	
				}
				else {
					$n_aligned_words++;
					my $start_diff = abs($hyp_start-$ref_start);
					my $end_diff = abs($hyp_end-$ref_end);
					$time_diff += ($start_diff+$end_diff)/2;					
				}						
			}
		}
	}
	if ($n_aligned_words > 0) {
		$time_diff /= $n_aligned_words;
	}
	return ($time_diff, $n_unknown_words, $n_unaligned_words, $n_aligned_words, $n_words); 	
}

=head2 align_text_files

Align two text files. The second file given is supposed to be the reference file
Input: The two filenames (the 2nd file is the reference file).
Output: List of words in the first file, list of words in the second file, 
		array matching the words of the second file to those of the first file 

=cut

sub align_text_files {
   my ($this, $hyp_file, $ref_file) = @_;

   my $sclite_bin = catfile($this->{bin_path},'sclite');
   my $command = "$sclite_bin -i wsj -h $hyp_file -r $ref_file -O ".$this->{working_dir}." -o pralign";
	   	
   my $cmd_out = SailTools::SailComponent::run($command);

   my ($b_name, $path, $sfx) = fileparse($hyp_file, "\.[^\.]+");

   my $alignment_file = catfile($this->{working_dir},$b_name.$sfx.".pra");
   my ($alignment_map, $ref_words, $hyp_words) = read_sclite_alignment_file($alignment_file);
   
   return ($alignment_map, $ref_words, $hyp_words);   
}

=head2 read_sclite_alignment_file 

Parse sclite alignment output file. 
Lowercase words are supposed to be aligned. Star sequences correspond to either deletions or insertions.
Input: Filename to be parsed.
Output: The mapping between aligned words, the list of words in the hypothesis file and the list of words in the 
        reference file.

=cut

sub read_sclite_alignment_file {
	my $alignment_file = shift;
	my @ref_words = ();
	my @hyp_words = ();
	my @alignment_map = ();
	open(AFILE, $alignment_file) || die("Cannot open file: $alignment_file for reading.\n");
	my $hyp_index = 0;
	my $ref_index = 0;
	my @run_ref_words = ();
	my @run_hyp_words = ();
	my $found_ref_and_hyp = 0;
	
	while(<AFILE>) {
		my $line = $_;
		chomp($line);
		if ($line=~ /^[>\s]*HYP/) {
			my $hyp_tok;
			$line =~ s/^[>\s]+//;
			($hyp_tok, @run_hyp_words) = split(/\s+/, $line);
			$found_ref_and_hyp = 1;			
		}
		elsif ($line=~ /^[>\s]*REF/) {
			my $ref_tok;
			$line =~ s/^[>\s]+//;
			($ref_tok, @run_ref_words) = split(/\s+/, $line);
		}
		if ($line=~ /^[>\s]*Eval/) {
			my $n_words = @run_ref_words;
			
			for (my $word_counter = 0; $word_counter<$n_words; $word_counter++) {
				my $ref_word = $run_ref_words[$word_counter];
				my $hyp_word = $run_hyp_words[$word_counter];
				
				if ($ref_word =~ /[a-z]/) {
					push(@ref_words, uc($ref_word));
					push(@hyp_words, uc($hyp_word));
					push(@alignment_map, $hyp_index);
					$hyp_index++;
					$ref_index++;
				} 
				elsif ($ref_word =~ /[A-Z]/) {
					push(@ref_words, uc($ref_word));
					push(@alignment_map, -1);
					$ref_index++;
					
					if ($hyp_word =~ /[A-Z]/) {
						push(@hyp_words, uc($hyp_word));
						$hyp_index++;
					}
				}
				else {
					# In case stars have been found
					if ($hyp_word =~ /[A-Z]/) {
						push(@hyp_words, uc($hyp_word));
						$hyp_index++;
					}						
				}
			}
			$found_ref_and_hyp = 0;
		}
	}	
	close(AFILE);
	return (\@alignment_map, \@ref_words, \@hyp_words);
}

=head1 AUTHOR

Athanasios Katsamanis, C<< <nkatsam at sipi.usc.edu> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-sailalign at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=SailAlign>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc SailTools::AlignText


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

1; # End of SailTools::AlignText

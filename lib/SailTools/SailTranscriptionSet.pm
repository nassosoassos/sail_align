package SailTools::SailTranscriptionSet;

use warnings;
use strict;
use File::Find;
use File::Path;
use File::Basename;
use File::Spec;
use File::Spec::Functions;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use SailTools::SailDataSet;
use SailTools::SailTranscription;
use SailTools::SailComponent;

=head1 NAME

SailTools::SailTranscriptionSet - Dataset of transcriptions

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.05';
our @ISA =  qw(SailTools::SailDataSet);


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use SailTools::SailTranscriptionSet;

    my $foo = SailTools::SailTranscriptionSet->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 new

New SailTranscriptionSet object.
Usage:
  my $sail_transcription_set = new SailTools::SailTranscriptionSet( %cfg );

=cut

sub new {
    my ($class, $cfg) = @_;
 
    my $parent = new SailTools::SailDataSet($cfg);
    my $this = bless($parent, $class);
    $this->{transcriptions} = [];
    $this->{lab_file} = $cfg->{lab_file};
    $this->{txt_file} = $cfg->{txt_file};

    return $this;
}

=head2 init_from_files

Initialize set of transcriptions from files.
Input: Reference to list of files
Usage:
  $trans_set->init_from_files ( \@files );
=cut
sub init_from_files {
	my ($this, $files_array_ref) = @_;
	
	my $files_ref = $this->{files};
	my $n_files = @$files_ref;
	foreach my $lab_file (@$files_array_ref) {
		my $transcription = new SailTools::SailTranscription($lab_file);
		$transcription->init_from_file($lab_file);
		$this->push_trans($transcription);
	}
}

=head2 init_from_otosense_log

Initialize set of transcriptions from otosense xml log. Filename 
along with speech recognition output are given for each file. 
Input: OtoSense log, configuration hash
Usage:
  $trans_set->init_from_otosense_log( $otosense_log, \%cfg );
=cut
sub init_from_otosense_log {
	my ($this, $otosense_log, $cfg) = @_;
	my $root_audio_file_path = "";
	foreach my $prop (keys %$cfg) {
		if ($prop eq "audio_root_path") {
			$root_audio_file_path = $cfg->{$prop};
		}
	}
	
	open(OLOG, "$otosense_log") || FATAL("Cannot open file $otosense_log for reading");
	my $transcription=0;
	my $name;
	while (<OLOG>) {
		my $line = $_;
		chomp($line);
		
		if ($line =~ /<file name=\s*[\"]*([^\s]+)\s*>/) {
			my $file_name = $1;
			my ($base_name, $path, $sfx) = fileparse($file_name,'\.[^\.]*');
			
			$transcription = new SailTools::SailTranscription("$base_name.lab");
			$this->push_trans($transcription);							
		}
		if ($line =~ /<text>([^<]*)<\/text>/){
			my $text = $1;
			if (!$transcription) {
				$transcription = new SailTools::SailTranscription("unknown_file_name.lab");
				$this->push_trans($transcription);
			}
			$text =~ s/^\s*//;
			my @words = split(/\s/,$text);
			$transcription->set_words(\@words);
			$transcription = 0;
			$name = "unknown_file_name.lab";
		}
		else {
			next;
		}
	}
}

=head2 read_mlf

Read  HTK multiple label file (MLF) 
Usage:
  my $transcription_set_ref = read_mlf ( $mlf_file );
=cut
  
sub read_mlf {
    my $mlf = shift;

    my %mlf_cfg;
    my $first_entry = 1;
    
    open(MLF, $mlf) || FATAL("Cannot open $mlf file for reading");
    my $header = <MLF>;
    if ($header !~ /#!MLF!#/) {
        WARN("Probably found an improperly formatted MLF file");
    }
    my $transcription;
    my @trans_words = ();
    my @trans_start_times = ();
    my @trans_end_times = ();
    my $transcription_set;
    while (<MLF>) {
        my $line = $_;
        chomp($line);
        
        if ($line =~ /\"(.+)\"/) {
            my $file_name = $1;
            my ($b_name, $path, $sfx) = fileparse($file_name, "\.[^\.]+");

            if ($first_entry) {
                $mlf_cfg{suffix} = $sfx;
                $mlf_cfg{root_path} = '*';
                $mlf_cfg{format} = $sfx;

                $transcription_set = new SailTools::SailTranscriptionSet(\%mlf_cfg);
                $first_entry = 0;
            }
            $transcription = new SailTools::SailTranscription($file_name);
        }
        elsif ($line =~ /([\d\.]+)\s+([\d\.]+)\s+(.+)/) {
                my $s_time = $1/$transcription->{lab_time_constant};
                my $e_time = $2/$transcription->{lab_time_constant};
                my $word = $3;

                push(@trans_words, $word);
                push(@trans_start_times, $s_time);
                push(@trans_end_times, $e_time);
        }
        elsif ($line =~ /^\.$/) {
                my @words = @trans_words;
                my @start_times = @trans_start_times;
                my @end_times = @trans_end_times;
                $transcription->set_words(\@words);
                $transcription->{start_times} = \@start_times;
                $transcription->{end_times} = \@end_times;
                $transcription_set->push_trans($transcription);
                @trans_words = ();
                @trans_start_times = ();
                @trans_end_times = ();
        }
    }

    close(MLF);
    return $transcription_set;
}

=head2 find_files_in_mlf

Reading mlf file functionality
Usage:
  my $files_arr_ref = find_files_in_mlf ( $mlf_file );
=cut
sub find_files_in_mlf {
    my $mlf = shift;
    my @file_names;
    
    open(MLF, $mlf) || FATAL("Cannot open $mlf file for reading");
    while (<MLF>) {
        my $line = $_;
        chomp($line);
        if ($line =~ /\".*\/([^\/]+)\"/) {
           push(@file_names, $1); 
        }
    }
    close(MLF);
    return \@file_names;
}

=head2 write_mlf

Write mlf file
Input: Mlf filename
Usage:
  $trans_set->write_mlf ( $mlf_name );
=cut
sub write_mlf {
	my ($this, $mlf_name) = @_;
	
	open(MLF, ">$mlf_name") || FATAL("Cannot open $mlf_name file for writing");
	print MLF "#!MLF!#";
	my $trans_array_ref = $this->{transcriptions};
	
	foreach my $transcription (@$trans_array_ref) {
		print MLF "\"".$transcription->{file}."\"\n";
		my @words = @$transcription->{words};
		print MLF join(" ",@words)."\n";
		print MLF ".\n";	
	}
	close(MLF);	
}

=head2 get_all_words

Get all words in the transcription set, in appearance order
Output: Reference to array of words
Usage:
  my $word_list_ref = $trans_set->get_all_words;

=cut
sub get_all_words {
	my $this = shift;
	
	my @words = ();
	my $trans_array_ref = $this->{transcriptions};

	foreach my $transcription (@$trans_array_ref) {
		my $words_ref = $transcription->{words};
		push(@words, @$words_ref);
	}
	return \@words;
} 

=head2 write_to_wsj_file

Write the set of transcriptions in a wsj formatted file
Input: The filename
Usage:
  $trans_set->write_to_wsj_file ( $wsj_file_name, \@files_to_be_skipped );

=cut
sub write_to_wsj_file {
	my ($this, $file_name, $to_be_skipped) = @_;
    
    my @to_be_skipped_files = ();
    if (@_>2) {
        @to_be_skipped_files = @$to_be_skipped;
    }
	my $trans_array_ref = $this->{transcriptions};
	
	my $n_transcriptions = @$trans_array_ref;
	open(WSJFILE, ">$file_name") || die("Cannot open file $file_name for writing.\n");
	
	my %file_hash;
    my @skipped_trans_files;
	foreach my $trans (@$trans_array_ref) {
		my $text = $trans->get_text;
		my $trans_file_name = $trans->{file};
	
		$trans_file_name =~ s/[\\\/]/_/g;
		$trans_file_name =~ s/\.[^\.]+$//;

        my @match_ind = grep {$trans_file_name eq $_} @to_be_skipped_files;

        if (@match_ind) {
            print $trans_file_name." skipped\n";
            next;
        }
        if ($text =~ /[\[\]]+/) {
            push(@skipped_trans_files, $trans_file_name);
            next;
        }
		$text =~ s/^MAIN$//;
		$text =~ s/^GAP$//;
		$text =~ s/^\[*UNINTELLIGIBLE\]*$//;
		
		$file_hash{$trans_file_name}++;
		# Only allow for unique file names
		
		if ($file_hash{$trans_file_name}==1) { 
			print WSJFILE "$text ($trans_file_name)\n";
		}
	}
	close(WSJFILE);
    return \@skipped_trans_files;
}

=head2 write_to_txt_file

Write transcriptions into text file, the one below the other.
Usage:
 $trans_set->write_to_txt_file( $txt_file );
=cut
  
sub write_to_txt_file {
	my ($this, $file_name) = @_;
	
	my $trans_array_ref = $this->{transcriptions};
	
	my $n_transcriptions = @$trans_array_ref;
	open(TXTFILE, ">$file_name") || die("Cannot open file $file_name for writing.\n");
	
	my %file_hash;
	foreach my $trans (@$trans_array_ref) {
		my $text = $trans->get_text;
		my $trans_file_name = $trans->{file};

		$file_hash{$trans_file_name}++;
		
		$text =~ s/^MAIN$//;
		$text =~ s/^GAP$//;
		
		# Only allow for unique file names
		
		if ($file_hash{$trans_file_name}==1) { 
			print TXTFILE "$text\n";
		}
	}
	close(TXTFILE);	
}

=head2 dump_words_in_file

Write all words in a single file, the one beneath the other
Input: filename, separator character between words, e.g. newline or space
Usage:
  $trans_set->dump_words_in_file( $file_name, $word_separator );
=cut
sub dump_words_in_file {
	my ($this, $file_name, $word_separator) = @_;
	my $word_array_ref = $this->get_all_words;
	SailTools::SailComponent::print_into_file($word_array_ref, $file_name, $word_separator,);
}

=head2 push_trans

PUsh transcription in the end of the list of transcriptions
Input: The transcription to be added
Usage:
  $trans_set->push_trans ( $transcription_object_ref );
  
=cut  
sub push_trans {
	my ($this, $transcription) = @_;
	
	my $transcriptions_ref = $this->{transcriptions};
	push(@$transcriptions_ref, $transcription);
	$this->{n_files}++;
	
	my $file = $transcription->{file};
	my $root_path = $this->{root_path};
	$file =~ s/\Q$root_path\E[\\\/]*//;

	my $files_ref = $this->{files};
	$transcription->{file} = $file;
	push(@$files_ref, $file);
	
}

=head1 AUTHOR

Athanasios Katsamanis, C<< <nkatsam at sipi.usc.edu> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-sailalign at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=SailAlign>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc SailTools::SailTranscriptionSet


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

1; # End of SailTools::SailTranscriptionSet

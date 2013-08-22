package SailTools::SailAdaptation;

use warnings;
use strict;
use File::Basename;
use File::Path;
use POSIX qw(ceil floor);
use SailTools::SailComponent;
use SailTools::SailTranscriptionSet;
use SailTools::SailHtkWrapper;
use File::Spec::Functions;

use Log::Log4perl qw(:easy);

=head1 NAME

SailTools::SailAdaptation - Utilities for acoustic model adaptation

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.01';
our @ISA = qw(SailTools::SailComponent);


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use SailTools::SailAdaptation;

    my $foo = SailTools::SailAdaptation->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 align_speech_feature_set

Align transcriptions with audio for small segments
Input: the feature files, corresponding transcriptions, the output mlf filename, acoustic models
	 dictionary, alignment configuration

=cut

sub align_speech_feature_set {
	    my ($seg_feature_set, $transcription_set, $phone_alignment_filename, $ac_model, $dict, $alignment_conf) = @_;	
	
		my $seg_feature_set_files = $seg_feature_set->get_files;
		my $n_aligned_segments = $seg_feature_set->{n_files};
		
		DEBUG("Number of aligned segments used for adaptation: $n_aligned_segments");
				
		my $trans_dir = $transcription_set->{root_path};
		mkpath($trans_dir);
		for (my $segment_counter=0; $segment_counter<$n_aligned_segments; $segment_counter++) {
			my $seg_file = $seg_feature_set_files->[$segment_counter];
			my $s_bname = fileparse($seg_file,"\.[^\.]+");
			my $trans_file = catfile($trans_dir,$s_bname.".lab");
			$transcription_set->{transcriptions}->[$segment_counter]->write_clean_to_file($trans_file,'lab','no_times'); 	
		}
		my $dict_file = $dict->{file};
		my $word_pron_ref = $dict->{words_pron};
		my %words_pron = %$word_pron_ref;
		SailTools::SailLanguage::add_short_pause_to_word_pronunciations(\%words_pron, $dict->{sp_model}, 'sil');
        $words_pron{$alignment_conf->{oov_symbol}} = 'sil';
		SailTools::SailLanguage::print_htk_dictionary_into_file(\%words_pron, $dict->{output_symbols}, $dict_file);		
		
		$alignment_conf->{output_words} = 0;
		$alignment_conf->{output_dir} = '*';
		$alignment_conf->{out_suffix} = 'lab';
		$alignment_conf->{in_suffix} = 'lab';
		my $file_list = $seg_feature_set->{list_abs_paths};
		SailTools::SailHtkWrapper::run_hvite_align($ac_model, $trans_dir, $phone_alignment_filename, $dict_file, $seg_feature_set->{list_abs_paths}, $alignment_conf);
}

=head2 generate_regression_class_tree

Generate regression class tree based on acoustic model statistics
Input: Acoustic models information structure and regression configuration hash

=cut

sub generate_regression_class_tree {
	my ($ac_model, $regression_cfg) = @_;
	
	SailTools::SailHtkWrapper::run_hhed_regression_class_tree($ac_model, $regression_cfg);	
}

=head2 adaptation

Acoustic model adaptation.

=cut

sub adaptation {
	my ($orig_acoustic_models, $adaptation_cfg) = @_;
	
	my $success = SailTools::SailHtkWrapper::run_herest_adapt($orig_acoustic_models, $adaptation_cfg);
    return $success;
}


=head1 AUTHOR

Athanasios Katsamanis, C<< <nkatsam at sipi.usc.edu> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-sailalign at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=SailAlign>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc SailTools::SailAdaptation


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

1; # End of SailTools::SailAdaptation

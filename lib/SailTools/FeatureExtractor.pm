package SailTools::FeatureExtractor;

use warnings;
use strict;
use Log::Log4perl qw(:easy);
use File::Spec::Functions;
use File::Path;
use Data::Dumper;

use SailTools::SailComponent;
use SailTools::SailHtkWrapper;
use SailTools::SailFeatures;

=head1 NAME

SailTools::FeatureExtractor - Utilities for acoustic feature extraction

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';
our @ISA = qw(SailTools::SailComponent SailTools::SailHtkWrapper);


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use SailTools::FeatureExtractor;

    my $foo = SailTools::FeatureExtractor->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 new

Initialize configuration

=cut

sub new {
    my ($class, $configuration, $experiment) = @_;
    my $self;

    $self->{experiment} = $experiment;
    $self->{configuration_file} = catdir($experiment->{working_dir},$configuration->{configuration_file});
    $self->{tool} = $configuration->{tool};
    $self->{kind} = $configuration->{kind};
    $self->{format} = $configuration->{format};
    $self->{feature_file_suffix} = $configuration->{feature_file_suffix};
    $self->{rate} = $configuration->{rate};
    $self->{save_compressed} = $configuration->{save_compressed};
    $self->{save_with_crc} = $configuration->{save_with_crc};
    $self->{window_size} = $configuration->{window_size};
    $self->{use_hamming} = $configuration->{use_hamming};
    $self->{preemphasis_factor} = $configuration->{preemphasis_factor};
    $self->{n_filters} = $configuration->{n_filters};
    $self->{cepstral_liftering} = $configuration->{cepstral_liftering};
    $self->{n_cepstral_coefs} = $configuration->{n_cepstral_coefs};
    $self->{normalize_energy} = $configuration->{normalize_energy};
    $self->{subtract_dc} = $configuration->{subtract_dc};
    $self->{use_power} = $configuration->{use_power};
    $self->{byte_order} = $configuration->{byte_order};
    $self->{log_level} = $configuration->{log_level};

    bless($self, $class);
    return $self;
}


=head2 extract_features

Extract acoustic features from a SailSignal object or a list of objects.

=cut

sub extract_features {
    my $this = shift;
    my $result;

    if ($_[0]->isa("SailTools::SailSignal")) {
        my $signal = $_[0];
        $result = $this->extract_features_from_signal($signal);
    }
    else {
        DEBUG("Extracting features from multiple signals not yet implemented.");
    }

    return $result;
}

=head2 extract_features_from_signal

Extract acoustic features from a SailSignal object or a list of objects.

=cut

sub extract_features_from_signal {
    my ($this, $signal) = @_;

    my $feature_seq = new SailTools::SailFeatures($this, $signal); 

    DEBUG($feature_seq->{'file'});

    if ($this->{tool} eq 'HCopy') {
        $this->hcopy_extract_features_from_signal($signal, $feature_seq);
    }
    else {
        ERROR("Undefined feature extraction tool has been specified.");
    }

    return $feature_seq;
}

=head2 hcopy_extract_features_from_signal

Extract acoustic features from signal using HCopy

=cut

sub hcopy_extract_features_from_signal {
    my ($this, $signal, $feature_seq) = @_;

    my $hcopy_configuration = $this;
	
    SailTools::SailHtkWrapper::run_hcopy($signal, $feature_seq, $hcopy_configuration);
}


=head1 AUTHOR

Athanasios Katsamanis, C<< <nkatsam at sipi.usc.edu> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-sailalign at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=SailAlign>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc SailTools::FeatureExtractor


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

1; # End of SailTools::FeatureExtractor

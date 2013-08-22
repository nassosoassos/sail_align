package SailTools::SailFeatures;

use warnings;
use strict;
use Log::Log4perl qw(:easy);
use File::Spec;
use File::Path;
use File::Basename;
use Data::Dumper;

=head1 NAME

SailTools::SailFeatures - The great new SailTools::SailFeatures!

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use SailTools::SailFeatures;

    my $foo = SailTools::SailFeatures->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 new

New SailFeatures object.

=cut

sub new {
    my ($class, $extractor, $source) = @_;
    my $self;

    $self->{source} = $source;
    $self->{experiment} = $extractor->{experiment};
    $self->{properties} = $extractor;
    $self->{feature_file_suffix} = $extractor->{feature_file_suffix};

    bless($self, $class);
    $self->{file} = $self->get_feature_file_name_from_signal_file_name($source);

    my ($name, $path) = fileparse($self->{file},'\.[^\.]*');
    $self->{name} = $name;
    $self->{path} = $path;

    return $self;
}

=head2 get_feature_file_name_from_signal_file_name

Generate a feature sequence file name given the filename of the signal

=cut
sub get_feature_file_name_from_signal_file_name {
    my ($this, $signal) = @_;

    my $current_experiment = $this->{experiment};
    my $feature_dir = File::Spec->catdir($current_experiment->{features_directory}, $signal->get_relative_path);
    mkpath($feature_dir);

    my $feature_file_name = File::Spec->catfile($feature_dir, $signal->{name}.".".$this->{feature_file_suffix});
    return $feature_file_name;
}

=head1 AUTHOR

Athanasios Katsamanis, C<< <nkatsam at sipi.usc.edu> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-sailalign at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=SailAlign>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc SailTools::SailFeatures


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

1; # End of SailTools::SailFeatures

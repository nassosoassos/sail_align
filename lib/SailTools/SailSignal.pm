package SailTools::SailSignal;

use warnings;
use strict;
use File::Basename;
use File::Path;
use Log::Log4perl qw(:easy);
use File::Spec;

=head1 NAME

SailTools::SailSignal - Class corresponding to a signal, i.e., an audio file

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use SailTools::SailSignal;

    my $foo = SailTools::SailSignal->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 new

New SailSignal object.
Usage:
  $sail_signal = new SailTools::SailSignal;

=cut

sub new {
    my $class = shift;
    my $self;

    # Basic Members
    $self->{Fs} = 0;
    $self->{name} = '';
    $self->{path} = '';
    $self->{signal_path} = '';
    $self->{format} = '';
    $self->{kind} = 'WAVEFORM';
    $self->{duration} = 0;

    if (@_>=1) {
      my $file_name = $_[0];
      $self->{file} = $file_name;
    }
    else {
        FATAL("Cannot initialize signal object without filename.");
    }
    if (@_ >= 2) {
      my $experiment = $_[1];
      $self->{experiment} = $experiment;
      $self->{signal_path} = $experiment->{signal_path};
    }
    elsif (@_ >= 3) {
        my $configuration = $_[2];
        
        if ($configuration->{Fs}>0) {
            $self->{Fs} = $configuration->{Fs};
        }
        if ($configuration->{format}) {
            $self->{format} = $configuration->{format};
        }
        if ($configuration->{kind}) {
            $self->{kind} = $configuration->{kind};
        }
    }
    else {
        INFO("The signal has not been assigned to a specific experiment.\n");
    }

    bless($self, $class);
    my ($name, $path, $sfx) = fileparse($self->{file},'\.[^\.]*');
    $self->{name} = $name;
    $self->{path} = $path;

    if (!($self->{format})) {
       $self->{format} = $self->set_format_from_suffix($sfx);
    }
    return $self;
}

=head2 format_from_suffix

Identify signal's format from the suffix of the corresponding filename.
Usage:
 my $format = format_from_suffix("wav"); 
=cut
sub format_from_suffix {
    my $suffix = shift;
    my $format;

    if ($suffix =~ m/wav/i) {
        $format = 'WAV';
    }
    return $format;
}

=head2 set_format_from_suffix

Set signal's format from the suffix of the corresponding filename.
Usage:
  $sail_signal->set_format_from_suffix("wav");

=cut
sub set_format_from_suffix {
    my ($this, $suffix) = @_;
    $this->{format} = format_from_suffix($suffix);
}

=head2 get_htk_format

Get the corresponding signal's format for HTK.
Usage:
  my $format = $sail_signal->get_htk_format;
=cut
sub get_htk_format {
    my $this = shift;
    my $format = '';

    if ($this->{format} eq 'WAV') {
        $format = 'WAV';
    }
    else {
        DEBUG("Unidentified format for HTK: ".$this->{format});
    }
    return $format;
}

=head2 get_relative_path

Get the relative path of the signal.
Usage:
  my $rel_path = $sail_signal->get_relative_path;

=cut
sub get_relative_path {
    my $this = shift;

    return File::Spec->abs2rel($this->{path}, $this->{signal_path});
}

=head1 AUTHOR

Athanasios Katsamanis, C<< <nkatsam at sipi.usc.edu> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-sailalign at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=SailAlign>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc SailTools::SailSignal


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

1; # End of SailTools::SailSignal

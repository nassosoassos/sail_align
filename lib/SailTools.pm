package SailTools;

use warnings;
use strict;

use FileHandle;
use File::Basename;
use File::Path;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use File::Spec::Functions;

use SailTools::SailComponent;

use vars qw( %cfg );

use vars qw( 
            $TRUE
            $FALSE
            $ROOTPATH
            $WORKINGDIR
            $EXPERIMENT_ID
            $BINDIR
 	    );

BEGIN {
  $TRUE = 1;
  $FALSE = 0;
  $WORKINGDIR = "tmp";
};


=head1 NAME

SailTools - Perl library of utility functions for SailAlign

=head1 VERSION

Version 1.20

=cut

our @ISA = qw(SailTools::SailComponent);
our $VERSION = '1.4.0';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use SailTools;

    my $foo = SailTools->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 new

Create a new SailTools object, i.e., a new experiment.

=cut

sub new {
  my ($class, $cfg) = @_;
  my $self;
  
  $self->{experiment_id} = $cfg->{experiment_id};
  $self->{working_dir} = $cfg->{working_dir};
  $self->{features_directory} = $cfg->{features_directory};
  $self->{signal_path} = $cfg->{signal_path};
  $self->{vad_output_dir} = $cfg->{vad_output_dir};
  $self->{bin_dir} = $cfg->{bin_dir};
  $self->{cfg} = $cfg;
  $self->{data_sets} = $cfg->{data_sets};
  $self->{conversions} = $cfg->{conversions};
  my $data_sets = $self->{data_sets};
  my $conversions = $self->{conversions};

  foreach my $set (@$data_sets) {
      $self->{$set} = $cfg->{$set};
  }

  foreach my $conversion (@$conversions) {
      $self->{$conversion} = $cfg->{$conversion};
  }
  mkpath $self->{working_dir};
  bless($self, $class);
  return $self;
}

=head1 AUTHOR

Athanasios Katsamanis, C<< <nkatsam at sipi.usc.edu> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-sailalign at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=SailAlign>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc SailTools


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

1; # End of SailTools

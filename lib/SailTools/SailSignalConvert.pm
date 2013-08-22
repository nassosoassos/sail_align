package SailTools::SailSignalConvert;

use warnings;
use strict;
use Log::Log4perl qw(:easy);
use File::Spec::Functions;
use File::Path;
use File::Basename;
use SailTools::SailComponent;

=head1 NAME

SailTools::SailSignalConvert - Convert signals into different formats

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use SailTools::SailSignalConvert;

    my $foo = SailTools::SailSignalConvert->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 convert_data_set

Convert a data set to a target one.
Usage:
  convert_data_set( $dataset_object_ref, $target_dataset_object_ref, \%cfg );

=cut

sub convert_data_set {
    my ($orig_data_set, $target_data_set, $cfg) = @_;

    my $orig_files = $orig_data_set->get_files;
    my $orig_root_path = $orig_data_set->{root_path};
    my $target_root_path = $target_data_set->{root_path};
    my $target_suffix = $target_data_set->{suffix};

    foreach my $file (@$orig_files) {
       my ($name, $path, $sfx) = fileparse($file,'\.[^\.]*');
       my $target_dir = catdir($target_root_path, $path);
       mkpath($target_dir);
       my $target_file_rel_path = catfile($path, "$name.$target_suffix");
       my $target_file = catfile($target_root_path, $target_file_rel_path);
       my $orig_file = catfile($orig_root_path, $file);

       convert_file($orig_file, $target_file, $cfg);
       $target_data_set->push_file($target_file_rel_path);
    }
};

=head2 convert_file

Convert a file into a different format, e.g., using sox.
Usage:
  convert_file ( $original_file, $target_file, \%cfg );

=cut
sub convert_file {
    my ($orig_file, $target_file, $cfg) = @_;

    if ($cfg->{tool} eq 'sox') {
       my $sox_bin; 
       if ($cfg->{bin_dir} eq '') {
          $sox_bin = $cfg->{tool};  
       }
       else {
        $sox_bin = catfile($cfg->{bin_dir}, $cfg->{tool});  
       }
       my $cmd = "$sox_bin $orig_file $target_file";
       my $cmd_out = SailTools::SailComponent::run($cmd);
       my @error_indicators = grep {/Error|USAGE/i} @$cmd_out;
       return \@error_indicators;
    }
    else {
        FATAL("This conversion tool has not been configured yet");
    }
}

=head1 AUTHOR

Athanasios Katsamanis, C<< <nkatsam at sipi.usc.edu> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-sailalign at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=SailAlign>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc SailTools::SailSignalConvert


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

1; # End of SailTools::SailSignalConvert

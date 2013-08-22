package SailTools::SailSegment;

use warnings;
use strict;
use File::Basename;
use POSIX qw(ceil floor);
use File::Spec::Functions;
use File::Path;
use SailTools::SailComponent;
use SailTools::SailDataSet;
use Log::Log4perl qw(:easy);

=head1 NAME

SailTools::SailSegment - Utilities to support file segmentation

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use SailTools::SailSegment;

    my $foo = SailTools::SailSegment->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 segment_features

Feature sequence segmentation at prescribed timestamps

Usage:
  my $set_object_ref = segment_features( $output_dir, $output_list, $segment_script, 
                                          \%conf, \@start_times, \@end_times );
  

=cut
sub segment_features {
    my $file_struct = shift;
    my ($output_dir, $output_list, $segment_script, $conf_ref, $start_times_ref, $end_times_ref) = @_;

    if (@_>5) {
       ($output_dir, $output_list, $segment_script, $conf_ref, $start_times_ref, $end_times_ref) = @_;
    }
    elsif (@_==5) {
        my $times_ref;
       ($output_dir, $output_list, $segment_script, $conf_ref, $times_ref) = @_;

       ($start_times_ref, $end_times_ref) = segments_from_timestamps($times_ref);
    }
    else {
        ERROR("Not enough arguments to run segment features");
    }
    my $tool = $conf_ref->{tool};

	my $n_segments = @$start_times_ref;
    if ($tool eq 'ch_track') {
    	DEBUG("Starting feature file segmentation: n_segments = $n_segments $output_list");
       ch_track_segment_features($file_struct, $output_dir, $output_list, $segment_script, $conf_ref, $start_times_ref, $end_times_ref); 
    }
    else {
        ERROR("Undefined tool for feature segmentation");
    }
    # Create a new dataset of the output files
    my %seg_set_cfg;
    my ($bname, $path, $sfx) = fileparse($file_struct->{file},'\.[^\.]*');
    $seg_set_cfg{root_path} = $output_dir; 
	$seg_set_cfg{suffix} = $sfx;
	$seg_set_cfg{list_abs_paths} = $output_list;
    $seg_set_cfg{name} = '${bname}_segs';
    $seg_set_cfg{type} = 'abs_list';
    my $seg_set = new SailTools::SailDataSet(\%seg_set_cfg);    
    return $seg_set;
}


=head2 segment_features_given_ids

Feature sequence segmentation at prescribed timestamps. The ids of the generated segments are also given.

Usage:
  my $set_object_ref = segment_features_given_ids ( $output_dir, $output_list, $segment_script
                                                    \%conf, \@start_times, \@end_times, \@ids);
=cut
sub segment_features_given_ids {
    my $file_struct = shift;
    my ($output_dir, $output_list, $segment_script, $conf_ref, $start_times_ref, $end_times_ref, $segment_ids_ref) = @_;

    my $tool = $conf_ref->{tool};

	my $n_segments = @$start_times_ref;
    if ($tool eq 'ch_track') {
    	DEBUG("Starting feature file segmentation: n_segments = $n_segments $output_list");
       ch_track_segment_features($file_struct, $output_dir, $output_list, $segment_script, $conf_ref, $start_times_ref, $end_times_ref, $segment_ids_ref); 
    }
    else {
        ERROR("Undefined tool for feature segmentation");
    }
    # Create a new dataset of the output files
    my %seg_set_cfg;
    my ($bname, $path, $sfx) = fileparse($file_struct->{file},'\.[^\.]*');
    $seg_set_cfg{root_path} = $output_dir; 
	$seg_set_cfg{suffix} = $sfx;
	$seg_set_cfg{list_abs_paths} = $output_list;
    $seg_set_cfg{name} = '${bname}_segs';
    $seg_set_cfg{type} = 'abs_list';
    my $seg_set = new SailTools::SailDataSet(\%seg_set_cfg);    
}

=head2 segments_from_timestamps

Consider segmentation of consecutive segments. Provide only the start times.
Usage: 
  ($start_times_ref, $end_times_ref) = segments_from_timestamps( \@timestamps );

=cut
sub segments_from_timestamps {
    my $times_ref = shift;
    my @start_times=();
    my @end_times=();
    my $k=0;

    while ($k<(@$times_ref-1)) {
        push(@start_times, @$times_ref[$k]);
        push(@end_times, @$times_ref[$k+1]);
        $k++;
    }
    return (\@start_times, \@end_times);
}

=head2 ch_track_segment_features

Feature sequence segmentation using ch_track.
Usage: 
  ch_track_segment_features( $file_info_hash_ref, $output_dir, $output_list, $segment_script, \%cfg,
                              \@start_times, \@end_times, \@segment_ids ); 
=cut
sub ch_track_segment_features {
    my ($file_struct, $output_dir, $output_list, $segment_script, $conf_ref, $start_times_ref, $end_times_ref, $segment_ids_ref) = @_;
    my $ids_given = 1;
    if (@_<8) {
        $ids_given = 0;
    }
    my $file_name = $file_struct->{file};

    my $files_ref;
    if ($ids_given) {
        $files_ref = write_cut_script_for_single_file($file_name, $segment_script, $output_dir, $start_times_ref, $end_times_ref, $segment_ids_ref);
    }
    else {
        $files_ref = write_cut_script_for_single_file($file_name, $segment_script, $output_dir, $start_times_ref, $end_times_ref);
    }
    run_ch_track_segment($file_name, $segment_script, $conf_ref);
    my $existing_files_ref = SailTools::SailComponent::find_existing_files($files_ref);
    
    my $n_existing_files = @$existing_files_ref;
    DEBUG("Number of existing files after segmentation: $n_existing_files");
    SailTools::SailComponent::write_files_to_list($existing_files_ref, $output_list);    
}

=head2 write_cut_script_for_single_file

Write segmentation information file for ch_track.
Usage: 
  write_cut_script_for_single_file ( $file_name, $cut_file, $output_dir, \@start_times, \@end_times, \@segment_ids );

=cut
sub write_cut_script_for_single_file {
    my ($file_name, $segment_script, $output_dir, $start_times_ref, $end_times_ref, $segment_ids_ref) = @_;
    my $ids_given = 1;
    if (@_<6) {
        $ids_given = 0;
    }
    my @output_files = ();

    my $n_segments = @$start_times_ref;
    my $segment_counter = 0;
    my ($name, $path, $sfx) = fileparse($file_name,'\.[^\.]*');

    open(SEGSCP, ">$segment_script") || ERROR("Cannot write to file $segment_script\n");
    for ($segment_counter=0; $segment_counter<$n_segments; $segment_counter++) {
       my $start_time = @$start_times_ref[$segment_counter];
       my $end_time = @$end_times_ref[$segment_counter];

       my $floored_start_time_ms = floor($start_time*1000);
       my $floored_end_time_ms = floor($end_time*1000);
       
       if ($end_time==-2) {
       		# Account for unknown ending time, i.e., end of file
       		$floored_end_time_ms = 'inf';
       }

       my $segment_name;
       if (!$ids_given) {
          $segment_name = "${name}.${floored_start_time_ms}-${floored_end_time_ms}$sfx";
       } 
       else {
           my $s_id = $segment_ids_ref->[$segment_counter];
           $segment_name = "${name}.${s_id}$sfx";
       }
       my $segment_file = catfile($output_dir, $segment_name);
       print SEGSCP "$start_time $end_time $segment_file\n";
       push(@output_files, $segment_file);
    }
    close(SEGSCP);
    return \@output_files;
}

=head2 run_ch_track_segment

Run ch_track to segment a feature sequence.
Usage:
  run_ch_track_segment ( $original_file, $cut_file, \%cfg, $list_of_output_files );

=cut
sub run_ch_track_segment {
	my ($orig_file, $segment_script, $conf_ref, $output_list) = @_;
	my $format = $conf_ref->{format};
	my $ch_track_bin = catfile($conf_ref->{bin_dir}, $conf_ref->{tool});
       
    if ($format eq 'HTK') {
    	$format = 'htk';  	
    } 
    elsif ($format eq 'ascii') {
    	$format = 'ascii'
    }
    my $cmd = "$ch_track_bin $orig_file -otype $format -cut_file $segment_script";
    my $cmd_out = SailTools::SailComponent::run($cmd);
    
    my @error_indicators = grep {/Error|USAGE/i} @$cmd_out;
    return \@error_indicators;
}

=head1 AUTHOR

Athanasios Katsamanis, C<< <nkatsam at sipi.usc.edu> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-sailalign at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=SailAlign>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc SailTools::SailSegment


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

1; # End of SailTools::SailSegment

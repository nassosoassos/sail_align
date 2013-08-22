package SailTools::SailDataSet;

use warnings;
use strict;
use File::Find;
use File::Path;
use File::Basename;
use File::Spec;
use File::Spec::Functions;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use Math::Random;

=head1 NAME

SailTools::SailDataSet - Class to represent a dataset.

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use SailTools::SailDataSet;

    my $foo = SailTools::SailDataSet->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 new

New class object. Configuration has to be provided.

=cut
sub new {
    my ($class, $cfg) = @_;
    my $self;
    
    $self->{format} = $cfg->{format};
    $self->{n_files} = 0;
    $self->{files} = [];
    $self->{current_file_id} = -1;
    $self->{name} = $cfg->{name};
    $self->{root_path} = $cfg->{root_path};
    $self->{suffix} = $cfg->{suffix};
    $self->{list_abs_paths} = $cfg->{list_abs_paths};
    $self->{list} = $cfg->{list};
    $self->{type} = $cfg->{type};
    $self->{pattern} = $cfg->{pattern};

    if ($self->{root_path} !~ "\Q*\E") {  
      mkpath($self->{root_path});
  }

    bless($self, $class);

    return $self;
}

=head2 get_files

Return a list of files of the dataset.

=cut
sub get_files {
    my ($this, $n_files) = @_;
    
    if ($this->{n_files}==0) {
    	my $files_ref;
    	if ($this->{type} eq 'abs_list') {
    		$files_ref = SailTools::SailComponent::read_from_file($this->{list_abs_paths});
    		
    		my $n_files = @$files_ref;
    		DEBUG("In get_files abs_list: n_files=$n_files file=".$this->{list_abs_paths});
    		my @files;
    		foreach my $abs_file (@$files_ref) {
    			my $rel_file = File::Spec->abs2rel($abs_file, $this->{root_path}); 
    			push(@files, $rel_file);
    			$files_ref = \@files;
    		}  		
     		$this->{files} = \@files;
      		$this->{n_files} = @files;
    	}
    	elsif ($this->{type} eq 'list') {
    		$files_ref = SailTools::SailComponent::read_from_file($this->{list}); 
      		$this->{files} = $files_ref;
      		$this->{n_files} = @$files_ref;
    	}
    	else {
    		my $pattern = $this->{pattern};
    		my $suffix = $this->{suffix};
    		my $file_pattern = $pattern.'\.'.$suffix.'\z';
      		$files_ref = find_files_following_pattern_in_dir($this->{root_path}, $file_pattern);
      		$this->{files} = $files_ref;
      		$this->{n_files} = @$files_ref;
    	}
   		return $files_ref;
    }
    else {
      return $this->{files};
    }
}

=head2 concatenate_into_file

Concatenate all the files of the dataset to a single file

=cut
sub concatenate_into_file {
	my ($this, $file) = @_;
	
	my $n_files = $this->{n_files};
	
  	open(FFILE, ">$file") || die("Cannot open file $file for writing\n");
	for (my $file_counter=0; $file_counter<$n_files; $file_counter++) {
		my $file_name = $this->get_next_file_abs_path;
		open(IFILE, $file_name) || die("Cannot open file for reading\n");
		while(<IFILE>) {
			print FFILE $_;	
		}
		close(IFILE);
	}
	close(FFILE);
}

=head2 set_files_from_file_array

Set the fileset to that in a particular list that is given. 
The root path is removed from the file path. 
Input: reference to array of filenames

=cut
sub set_files_from_file_array {
	my ($this, $file_array_ref) = @_;
	my $root_path = $this->{root_path};
	
	$this->{n_files} = @$file_array_ref;
	my @files = ();
	foreach my $file (@$file_array_ref) {
		$file =~ s/\Q$root_path\E[\\\/]*//;
		$file =~ s/[\\\/]/\\/g;
		
		push(@files, $file);
	}
	$this->{files} = \@files;
}

=head2 set_files_from_parallel_file_array

Set the fileset to that in a particular list that is given.
The list is of parallel fileset. The assumption is that the suffix is different only. 
The root path is removed from the file path. The suffix is changed.
Input: reference to array of filenames

=cut
sub set_files_from_parallel_file_array {
	my ($this, $file_array_ref) = @_;
	my $root_path = $this->{root_path};
	my $sfx = $this->{suffix};
	
	$this->{n_files} = @$file_array_ref;
	my @files = ();
	foreach my $file (@$file_array_ref) {
		$file =~ s/\Q$root_path\E[\\\/]*//;
		$file =~ s/[\\\/]/\//g;
		$file =~ s/\.([^\.]+)$/\./;
		
		push(@files, $file.$sfx);
	}
	$this->{files} = \@files;
	$this->{n_files} = @files;
}

=head2 get_files_from_parallel_file_array

Get the fileset that would correspond to a particular list that is given.
The list is of parallel fileset. The assumption is that the suffix is different only. 
The root path is removed from the file path. The suffix is changed.
Input: reference to array of filenames

=cut
sub get_files_from_parallel_file_array {
	my ($this, $file_array_ref) = @_;
	my $root_path = $this->{root_path};
	my $sfx = $this->{suffix};
	
	$this->{n_files} = @$file_array_ref;
	my @files = ();
	foreach my $file (@$file_array_ref) {
		$file =~ s/\Q$root_path\E[\\\/]*//;
		$file =~ s/[\\\/]/\//g;
		$file =~ s/\.([^\.]+)$/\./;
		
		push(@files, catfile($root_path,"$file$sfx"));
	}
	return \@files;
}

=head2 get_files_abs_paths

Get absolute path names to files corresponding to the dataset
Input:
Output: reference to list of filenames

=cut
sub get_files_abs_paths {
	my $this = shift;
	my $files_ref = $this->get_files;
	
	my @files_abs_paths = ();
	foreach my $file (@$files_ref) {
		push(@files_abs_paths, catfile($this->{root_path}, $file));
	}
	return \@files_abs_paths;
}

=head2 find_files_following_pattern_in_dir

Find all the files in a directory tree whose names follows a specific pattern

=cut
sub find_files_following_pattern_in_dir {
    my ($dir, $pattern) = @_;

    my @files;
    my $file_finder = sub {
        my $file_name = $File::Find::name;   
        return if (! -f $file_name);
        $_ = $file_name;
        return if ! /$pattern/;        
		$file_name =~ s/\Q$dir\E[\/]*//;
        push @files, $file_name;
    };
    DEBUG($dir);
    find( $file_finder, $dir);
    return \@files;	
}

=head2 find_files_with_suffix_in_dir

Find all the files in a directory tree with a specific suffix

=cut
sub find_files_with_suffix_in_dir {
    my ($dir, $suffix) = @_;

    my @files;
    my $file_finder = sub {
        return if ! -f;
        return if ! /\.$suffix\z/;
        my $file_name = $File::Find::name;
		$file_name =~ s/\Q$dir\E[\/]*//;
        push @files, $file_name;
    };
    DEBUG($dir);
    find( $file_finder, $dir);
    return \@files;
}

=head2 push_file

Add a file to the dataset. The file is added to the list of files and 
the number of files is increased.
Input: The file to be added to the dataset

=cut
sub push_file {
    my ($this, $file) = @_;

	my $root_path = $this->{root_path};
    my $file_ref = $this->{files};
    
    # Remove the root path from the file path
    $file =~ s/\Q$root_path\E[\\\/]*//;
	$file =~ s/[\\\/]/\//g;
    
    push(@$file_ref, $file);
    my $n_files = @$file_ref;
    $this->{n_files}++;
}

=head2 get_next_file_abs_path

Get the next file of the dataset. The absolute path to the file is returned.
Input:
Output: Absolute file_name

=cut
sub get_next_file_abs_path {
	my $this = shift;
	
	my $file_rel_path = $this->get_next_file;
	return catfile( $this->{root_path},$file_rel_path);
	
}

=head2 get_next_file

Get the next file of the dataset. The absolute path to the file is returned.
Input:
Output: Relative file_name

=cut
sub get_next_file {
	my $this = shift;
	$this->{current_file_id} += 1;
	my $id = $this->{current_file_id};
	my $files = $this->{files};
	return $files->[$id];
}

=head2 write_list_of_files_abs_path

Write a list of absolute path filenames.

=cut
sub write_list_of_files_abs_path {
    my ($this, $list_name) = @_;
      
    if (@_<2) {
    	$list_name = $this->{list_abs_paths};
    }
    
    my $files_ref;
    if ($this->{n_files}==0) {
      $files_ref = $this->get_files;
    }
    else {
        $files_ref = $this->{files};
    }

    my $root_path = $this->{root_path};
    open(LIST,">$list_name") || FATAL("Cannot open $list_name for writing.");
    foreach my $file (@$files_ref) {
        print LIST catfile($root_path, $file)."\n";
    }
    close(LIST);
}

=head2 select_random_files

Select a number of random files from the dataset.

=cut
sub select_random_files {
	my ($this, $n_files) = @_;
	
	my @rand_files = ();
	
	my $upper_lim = $this->{n_files}-1;
	my $files_abs_path_ref = $this->get_files_abs_path;
	for (my $file_counter=0; $file_counter<$n_files; $file_counter++) {
		my $file_ind = random_uniform_integer(1, 0,$upper_lim);
		push(@rand_files, $files_abs_path_ref->[$file_ind]);
	}
	return \@rand_files;
}


=head1 AUTHOR

Athanasios Katsamanis, C<< <nkatsam at sipi.usc.edu> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-sailalign at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=SailAlign>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc SailTools::SailDataSet


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

1; # End of SailTools::SailDataSet

package SailTools::SailComponent;

use warnings;
use strict;
use FileHandle;
use File::Basename;
use File::Path;
use Log::Log4perl qw(:easy);
use Spreadsheet::ParseExcel;
use List::Util qw(min max);

use vars qw( 
            $TRUE
            $FALSE
           );

=head1 NAME

SailTools::SailComponent - Basic functionality, basic class for SailTools

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use SailTools::SailComponent;

    my $foo = SailTools::SailComponent->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 read_spreadsheet

Read an xls spreadsheet.

=cut
sub read_spreadsheet {
    my ($spreadsheet, $columns_ref, $rows_ref) = @_;
    
    my $parser = Spreadsheet::ParseExcel->new();
    my $workbook = $parser->Parse($spreadsheet);
    my @transcription_arr = ();

    my ($row_min, $row_max); 
    my $n_rows = @$rows_ref;
    my $n_cols = @$columns_ref;
    my @values = (0)x$n_cols;
    $row_min = $rows_ref->[0];
    $row_max = $rows_ref->[$n_rows-1];

    for my $worksheet ( $workbook->worksheets() ) {
     # For each row, the second column is the filename of the audio and the fourth column
     # is the transcription
     my ($real_row_min, $real_row_max) = $worksheet->row_range();
     if ($row_max == -1) {
         $row_max = $real_row_max;
     }
     my @all_rows;
     if ($n_rows==2) {
        @all_rows = $row_min .. $row_max;
     }
     else {
         @all_rows = @$rows_ref;
     }
     for my $row ( @all_rows ) {
        my $index = 0;
        for my $col (@$columns_ref) {
            my $col_contents_ref;
            if ($values[$index]) {
               $col_contents_ref = $values[$index];
            } 
            else {
               my @col_values = [];
               $col_contents_ref = \@col_values;
               $values[$index] = $col_contents_ref;
            }
            my $cell = $worksheet->get_cell($row, $col);
            my $cel_val = " ";
            if ($cell) {
               $cel_val = $cell->value();
            }
            push(@$col_contents_ref, $cel_val);
            my $n_elems = @$col_contents_ref;
            $index++;
        }

     }
   }
   return \@values;
}

=head2 print_into_file

Print array into file given a separator between the entries.
It opens and closes the file.

=cut

sub print_into_file {
	my ($array_ref, $file_name, $separator) = @_;
	
	if (@_<3) {
		$separator = "\n";
	}
	open(FILE, ">$file_name") || FATAL("Cannot open file $file_name for writing");
    my $n_elems = @$array_ref;
	print FILE join($separator,@$array_ref);
	print FILE "\n";
	close(FILE);
}

=head2 read_from_file

Read a file, given the filename and return an array of all the lines
Input: filename
Output:reference to array of lines (chomped) 

=cut

sub read_from_file {
	my $file_name = shift;
	
	open(FILE,"$file_name") || FATAL("Cannot read file $file_name.");
	my @content = <FILE>;
	chomp(@content);
	close(FILE);
	return \@content;
}

=head2 print_code_config

Configuration file in the form of a set of "property=value" lines.

=cut
sub print_code_config {
  my ($this, $mode) = @_;
  my $conf_file;
  my $conf_hash_ref;
  if ($mode eq "audio") {
    $conf_hash_ref = $this->{audio_code_config};
    $conf_file = $this->{audio_code_config_file};
  }
  elsif ($mode eq "speech") {
    $conf_hash_ref = $this->{speech_code_config};
    $conf_file = $this->{speech_code_config_file};
  }
  my $conf_file_handle = $this->open_file($conf_file, "write");

  foreach my $key (keys %$conf_hash_ref) {
     $conf_file_handle->print($key.'='.$$conf_hash_ref{$key}."\n");  
  }
  $this->close_file($conf_file_handle); 
}

=head2 find_existing_files

Find the files that exist from a list of files

=cut

sub find_existing_files {
	my $files_ref=shift;
	my @existing_files=();
	
	foreach my $file (@$files_ref) {
		if (-e $file) {
			push(@existing_files, $file);
		}
	}
	return \@existing_files;
}

=head2 write_files_to_list 

Write an array of files into a list.

=cut

sub write_files_to_list {
	my ($files_ref, $list) = @_;
	
	open(LIST, ">$list") || FATAL("Cannot open file $list for writing");
	foreach my $file (@$files_ref) {
		print LIST $file."\n";
	}
	close(LIST);
}

=head2 sprint_otosense_config

Print a string of otosense configuration parameters given a hash.

=cut

sub sprint_otosense_config {
    my ($config_ref, $separator) = @_;
    if (@_<2) {
        $separator = " ";
    }
    my $config_string;
    foreach my $att (keys %$config_ref) {
        $config_string .= "-$att ".$config_ref->{$att}.$separator;
    }
    return $config_string;
}

=head2 fprint_otosense_config

Print otosense style configuration into file.

=cut

sub fprint_otosense_config {
    my ($config_ref, $config_file) = @_;

    open(CONFIG, ">$config_file") or (FATAL("Cannot open configuration file for writing") && die);
    print CONFIG sprint_otosense_config($config_ref, "\n");
    close(CONFIG);
}

=head2 print_recognize_config 

Write configuration file for recognition

=cut

sub print_recognize_config {
  my ($this, $mode) = @_;
  my $conf_file;
  my $conf_hash_ref;
  if ($mode eq "audio") {
    $conf_hash_ref = $this->{audio_recognize_config};
    $conf_file = $this->{audio_recognize_conf_file};
  }
  elsif ($mode eq "speech") {
    $conf_hash_ref = $this->{speech_recognize_config};
    $conf_file = $this->{speech_recognize_conf_file};
  }
  my $conf_file_handle = $this->open_file($conf_file, "write");

  foreach my $key (keys %$conf_hash_ref) {
     $conf_file_handle->print($key.'='.$$conf_hash_ref{$key}."\n");  
  }
  $this->close_file($conf_file_handle); 
}

=head2 print_code_scp_single_audio_file 

Print scp file for HTK.

=cut
sub print_code_scp_single_audio_file {
  my $this   = shift; 
  my $file_name = $this->{fileName};
  
  # Obviously the filename should be given relative to the $audio_wav_dir
  my ($base_name, $dir, $ext) = fileparse($file_name,'\..*');
  my $scp_file_name = $this->{audio_code_scp_file};

  my $scp_file_handle = $this->open_file($scp_file_name, "write");

  my $audio_wav_dir = $this->{audio_source_wav_dir};
  my $audio_mfcc_dir = $this->{audio_mfcc_dir};
  my $mfcc_ext = $this->{mfcc_file_ext};
  my $scp_line = "$audio_wav_dir/$dir/$base_name$ext $audio_mfcc_dir/$base_name.$mfcc_ext\n";
  $scp_line =~ s/\/[\.]+/\//;
  print $scp_file_handle $scp_line;
  $this->close_file($scp_file_handle);
}

=head2 print_recognize_scp

Print scp file for speech recognition with HVite.

=cut
sub print_recognize_scp {
  my ($this, $list, $scp, $path, $ext) = @_;
  my $list_handle = $this->open_file($list, "read");
  my $scp_handle = $this->open_file($scp, "write");

  while (<$list_handle>) {
      chomp;
      my $filename = $_;
      my ($basename, $dir, $ext) = fileparse($filename,'\.[^\.]*');
      print $scp_handle "$path/$basename$ext\n";
  }
  $this->close_file($list_handle);
  $this->close_file($scp_handle);
}

=head2 frontend_cut_silences

Call the frontend binary to segment audio.

=cut
sub frontend_cut_silences {
  my $this = shift; 
  my $config = $this->{audio_code_config_file};
  my $scp = $this->{audio_code_scp_file};
  my $segmentList = $this->{silence_separated_segments_times_list};
  my $bin_dir = $this->{bin_dir};

  my $arguments = "-confFile $config -scpFile $scp -segmentList $segmentList";

  my $output = $this->execute('frontend', $arguments, $bin_dir);
  my @cut_sil_output = @$output;
  $this->debug('frontend output:'."@cut_sil_output");
  #QualiEngine::QualiComponent::run($commandStr);
}

=head2 frontend

Call the frontend binary to extract acoustic features

=cut
sub frontend {
  my ($config, $scp) = @_; 
  my $command = "frontend -confFile $config -scpFile $scp";
  run($command);
}

=head2 run

Run a command using perl's system. Capture stdout and stderr into a pipe.
This probably has to change so that a file is used instead.

=cut
sub run {
    my $command = shift;
   
    open(MPIPE, "$command 2>&1 |") || FATAL("Cannot open pipe to run command:\n$command\n");
    DEBUG($command);
    my @output = <MPIPE>;
    close(MPIPE);
    return \@output;
}

=head2 read_columns_file

Read a file that has multiple columns. Provide the name of the file and the number of the columns 
to be read. Returns an array of references to the columns.

=cut
sub read_columns_file {
    my ($file, $n_columns) = @_;
    my @columns;
    open(FI, $file) or (FATAL("Cannot open file $file for reading") && die());
    my $first_line = 1;
    while(<FI>) {
        my $line = $_;
        chomp($line);
        my @entries = split(/\s+/, $line);
        for (my $k=0; $k<$n_columns; $k++) {
            if ($first_line) {
                my @k_col = ();
                $k_col[0] = $entries[$k];
                $columns[$k] = \@k_col;
            }
            else {
                my $k_col_ref = $columns[$k];
                push(@$k_col_ref, $entries[$k]);
            }
        }
        $first_line = 0;
    }
    close(FI);
    return @columns;
}

=head2 sum_array_and_scalar

Sum an array and a scalar.

=cut
sub sum_array_and_scalar {
    my ($arr_ref, $scalar) = @_;
    
    my $n_elms = @$arr_ref;
    for (my $k=0; $k<$n_elms; $k++) {
       $arr_ref->[$k] += $scalar;
    }
}

=head2 execute

Like run but the command to be run and arguments may be given separately.

=cut
sub execute {
  my ($this, $program, $arguments, $bin_dir) = @_;
  if (defined($bin_dir)) {
    $program = "$bin_dir/$program";
  }
  my $command = "$program $arguments";
  open(MPIPE, "$command 2>&1 |") or $this->fatal("Cannot open pipe to run command $program\n", "FileMgmt"); 
  $this->debug($command);
  my @output;
  @output = <MPIPE>;
  close(MPIPE);
  return \@output;
}

=head2 execute_python

Execute a python script.

=cut
sub execute_python {
  my ($this, $program, $arguments, $bin_dir) = @_;
  my $python_bin_dir = $this->{python_bin_dir};
  if (defined($bin_dir)) {
    $program = "$bin_dir/$program";
  }
  my $command = "$python_bin_dir/python $program $arguments";
  open(MPIPE, "$command 2>&1 |") or $this->fatal("Cannot open pipe to run command $program\n", "FileMgmt"); 
  $this->debug($command);
  my @output;
  @output = <MPIPE>;
  close(MPIPE);
  return \@output;
}

=head2 open_file

Object oriented file opening with more elaborate logging.

=cut
sub open_file {
  my ($this, $file_name, $mode) = @_;
  my $file_handle = new FileHandle;
  if ($mode eq "read") {
    $file_handle->open("< $file_name") or FATAL("Cannot open $file_name for reading.", "FileMgmt"); 
  }
  elsif ($mode eq "write") {
    $file_handle->open("> $file_name") or FATAL("Cannot open $file_name for writing.", "FileMgmt"); 
  }
  elsif ($mode eq "append") {
    $file_handle->open(">> $file_name") or FATAL("Cannot open $file_name for appending.", "FileMgmt");
  }
  return $file_handle;
}

=head2 close_file

Object oriented file handler closing.

=cut
sub close_file {
  my ($this, $file_handle) = @_;
  $file_handle->close() or $this->fatal("Problem closing file.", "FileMgmt");
}

=head2 cleanup

Remove working directory

=cut
sub cleanup {
  my $this = shift;
  rmtree $this->{working_dir};
}


=head1 AUTHOR

Athanasios Katsamanis, C<< <nkatsam at sipi.usc.edu> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-sailalign at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=SailAlign>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc SailTools::SailComponent


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

1; # End of SailTools::SailComponent

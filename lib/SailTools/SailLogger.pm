package SailTools::SailLogger;

use warnings;
use strict;
use IO::File;

use vars qw(
  $TRUE
  $FALSE
  @LEVELS
  $DEBUG
  $INFO
  $WARN
  $ERROR
  $FATAL
  $LOG
  $LOG_LEVEL_NO
  $LOG_LEVEL
  @matching_levels
	);

BEGIN {
  $TRUE = 1;
  $FALSE = 0;
  @LEVELS = ('$DEBUG','$INFO','$WARN','$ERROR','$FATAL');
  $DEBUG = 0;
  $INFO = 1;
  $WARN = 2;
  $ERROR = 3;
  $LOG_LEVEL='$DEBUG';
  $FATAL = 4;
  @matching_levels = grep {/$LOG_LEVEL/} @LEVELS; 
};

=head1 NAME

SailTools::SailLogger - Take care of the logging of any action in the experimentation framework.
	 Support various levels of logging. This module is obsolete, since Log4perl is now used.


=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use SailTools::SailLogger;

    my $foo = SailTools::SailLogger->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 new

New SailLogger object.

=cut
sub new {
  my $class = shift;
  my $this = bless({}, $class);
  $this->{log_event_arr} = ();
  return $this;
}

=head2 create_log_event

Add to the log event arr a new log event.
Input: Type of the event, Source, Timestamp, Package, Subroutine, Line, Message
Usage:
  $sail_logger->create_log_event($ERROR, $source, $timestamp, $package, $subroutine, $line, $message);

=cut
sub create_log_event {
  my ($this,$type, $source, $timestamp, $package, $subroutine, $line, $message) = @_;
  my $event = {};
  $event->{source} = $source;
  $event->{type} = $type;
  $event->{timestamp} = $timestamp;
  $event->{package} = $package;
  $event->{subroutine} = $subroutine;
  $event->{line} = $line;
  $event->{message} = $message;

  my $logarr_ref = $this->{log_event_arr};
  my @logarr = ();

  if (defined $logarr_ref) {
	@logarr = @$logarr_ref;
  }
  push(@logarr, $event);
  $this->{log_event_arr} = \@logarr;
}

=head2 dump_log

Dump log into string.
Input: None
Output: The log string
Usage:
  my $log_string = $sail_logger->dump_log;

=cut
sub dump_log {
  my $this = shift;
  my $logarr_ref = $this->{log_event_arr};
  my @logarr = @$logarr_ref;
  my $log_string = "<LogDataSet>\n";
  my $count=0;

  foreach my $log_event (@logarr) {
    $count++;
    my $source = $log_event->{source};
    my $type = $log_event->{type};
    my $timestamp = $log_event->{timestamp};
    my $package = $log_event->{package};
    my $subroutine = $log_event->{subroutine};
    my $line = $log_event->{line};
    my $message = $log_event->{message};
    $log_string .= "\t<LogEvent Source=\"LESAQE $source\" Type=\"LETSAP $type\">\n"; 
    $log_string .= "\t<LogData>\n";
    $log_string .= "\t\t<timestamp>$timestamp<\/timestamp>\n";
    $log_string .= "\t\t<package>$package<\/package>\n";
    $log_string .= "\t\t<subroutine>$subroutine<\/subroutine>\n";
    $log_string .= "\t\t<line>$line<\/line>\n";
    $log_string .= "\t\t<message>$message<\/message>\n";
    $log_string .= "\t<\/LogData>\n";
    $log_string .= "\t<\/LogEvent>\n";
  }
  $log_string .= "<\/LogDataSet>\n";
  return $log_string;
}

=head2 debug

Create a debugging log event.
Input: The message, source
Output: None
Usage:
  $sail_logger->debug($message, $source);

=cut
sub debug {
  my ($this, $message, $source) = @_;
  my $log_level = $LOG_LEVEL_NO;

  if ($log_level <= $DEBUG) {
	my $timestamp = localtime time;
        my ($package, $file_name, $line, $subroutine) = caller(1);
	if (!defined $source) {
         $source = 'VoiceRec'; 
	}
        $this->create_log_event('Information', $source, $timestamp, $package, $subroutine, $line, $message);
  }
}

=head2 info

Create an informational log event.
Input: The message, source
Output: None
Usage:
  $sail_logger->info($message, $source);

=cut
sub info {
  my ($this, $message, $source) = @_;
  my $log_level = $LOG_LEVEL_NO;

  if ($log_level <= $INFO) {
	my $timestamp = localtime time;
        my ($package, $file_name, $line, $subroutine) = caller(1);
	if (!defined $source) {
	        $source = 'VoiceRec'; 
	}
        $this->create_log_event('Information', $source, $timestamp, $package, $subroutine, $line, $message);
  }
}

=head2 warn

Create a warning log event.
Input: The message and source
Output: None
Usage: 
  $sail_logger->warn($message, $source);
=cut
sub warn {
  my ($this, $message, $source) = @_;
  my $log_level = $LOG_LEVEL_NO;

  if ($log_level <= $WARN) {
	my $timestamp = localtime time;
        my ($package, $file_name, $line, $subroutine) = caller(1);
	if (!defined $source) {
	        $source = 'VoiceRec'; 
	}
        $this->create_log_event('Warning', $source, $timestamp, $package, $subroutine, $line, $message);
  }
}
=head2 error

Create an error log event.
Input: The message and source
Output: None
Usage: 
  $sail_logger->error($message, $source);
=cut
sub error {
  my ($this, $message, $source) = @_;
  my $log_level = $LOG_LEVEL_NO;

  if ($log_level <= $ERROR) {
	my $timestamp = localtime time;
        my ($package, $file_name, $line, $subroutine) = caller(1);
	if (!defined $source) {
	        $source = 'VoiceRec'; 
	}
        $this->create_log_event('Information', $source, $timestamp, $package, $subroutine, $line, $message);
  }
}

=head2 fatal

Create a fatal log event.
Input: The message and source
Output: None
Usage: 
  $sail_logger->fatal($message, $source);
=cut
sub fatal {
  my ($this, $message, $source) = @_;
  my $log_level = $LOG_LEVEL_NO;

  if ($log_level <= $FATAL) {
	my $timestamp = localtime time;
        my ($package, $file_name, $line, $subroutine) = caller(1);
	if (!defined $source) {
	        $source = 'VoiceRec'; 
	}
        $this->create_log_event('Error', $source, $timestamp, $package, $subroutine, $line, $message);
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

    perldoc SailTools::SailLogger


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

1; # End of SailTools::SailLogger

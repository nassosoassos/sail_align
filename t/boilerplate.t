#!perl -T

use strict;
use warnings;
use Test::More tests => 23;

sub not_in_file_ok {
    my ($filename, %regex) = @_;
    open( my $fh, '<', $filename )
        or die "couldn't open $filename for reading: $!";

    my %violated;

    while (my $line = <$fh>) {
        while (my ($desc, $regex) = each %regex) {
            if ($line =~ $regex) {
                push @{$violated{$desc}||=[]}, $.;
            }
        }
    }

    if (%violated) {
        fail("$filename contains boilerplate text");
        diag "$_ appears on lines @{$violated{$_}}" for keys %violated;
    } else {
        pass("$filename contains no boilerplate text");
    }
}

sub module_boilerplate_ok {
    my ($module) = @_;
    not_in_file_ok($module =>
        'the great new $MODULENAME'   => qr/ - The great new /,
        'boilerplate description'     => qr/Quick summary of what the module/,
        'stub function definition'    => qr/function[12]/,
    );
}

TODO: {
  local $TODO = "Need to replace the boilerplate text";

  not_in_file_ok(README =>
    "The README is used..."       => qr/The README is used/,
    "'version information here'"  => qr/to provide version information/,
  );

  not_in_file_ok(Changes =>
    "placeholder date/time"       => qr(Date/time)
  );

  module_boilerplate_ok('lib/SailTools.pm');
  module_boilerplate_ok('lib/SailTools/AlignSpeech.pm');
  module_boilerplate_ok('lib/SailTools/AlignText.pm');
  module_boilerplate_ok('lib/SailTools/FeatureExtractor.pm');
  module_boilerplate_ok('lib/SailTools/SailAdaptation.pm');
  module_boilerplate_ok('lib/SailTools/SailComponent.pm');
  module_boilerplate_ok('lib/SailTools/SailComponent.pm');
  module_boilerplate_ok('lib/SailTools/SailFeatures.pm');
  module_boilerplate_ok('lib/SailTools/SailLanguage.pm');
  module_boilerplate_ok('lib/SailTools/SailLogger.pm');
  module_boilerplate_ok('lib/SailTools/SailRecognizeSpeech.pm');
  module_boilerplate_ok('lib/SailTools/SailSegment.pm');
  module_boilerplate_ok('lib/SailTools/SailSignalConvert.pm');
  module_boilerplate_ok('lib/SailTools/SailSignal.pm');
  module_boilerplate_ok('lib/SailTools/SailSignalSet.pm');
  module_boilerplate_ok('lib/SailTools/SailTranscription.pm');
  module_boilerplate_ok('lib/SailTools/SailTranscriptionSet.pm');
  module_boilerplate_ok('lib/SailTools/SegmentAudio.pm');
  module_boilerplate_ok('lib/SailTools/VoiceActivityDetection.pm');
  module_boilerplate_ok('lib/SailTools/SailDataSet.pm');
  module_boilerplate_ok('lib/SailTools/SailHtkWrapper.pm');


}


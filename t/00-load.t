#!perl -T

use Test::More tests => 21;

BEGIN {
    use_ok( 'SailTools' ) || print "Bail out!
";
    use_ok( 'SailTools::AlignSpeech' ) || print "Bail out!
";
    use_ok( 'SailTools::AlignText' ) || print "Bail out!
";
    use_ok( 'SailTools::FeatureExtractor' ) || print "Bail out!
";
    use_ok( 'SailTools::SailAdaptation' ) || print "Bail out!
";
    use_ok( 'SailTools::SailComponent' ) || print "Bail out!
";
    use_ok( 'SailTools::SailComponent' ) || print "Bail out!
";
    use_ok( 'SailTools::SailFeatures' ) || print "Bail out!
";
    use_ok( 'SailTools::SailLanguage' ) || print "Bail out!
";
    use_ok( 'SailTools::SailLogger' ) || print "Bail out!
";
    use_ok( 'SailTools::SailRecognizeSpeech' ) || print "Bail out!
";
    use_ok( 'SailTools::SailSegment' ) || print "Bail out!
";
    use_ok( 'SailTools::SailSignalConvert' ) || print "Bail out!
";
    use_ok( 'SailTools::SailSignal' ) || print "Bail out!
";
    use_ok( 'SailTools::SailSignalSet' ) || print "Bail out!
";
    use_ok( 'SailTools::SailTranscription' ) || print "Bail out!
";
    use_ok( 'SailTools::SailTranscriptionSet' ) || print "Bail out!
";
    use_ok( 'SailTools::SegmentAudio' ) || print "Bail out!
";
    use_ok( 'SailTools::VoiceActivityDetection' ) || print "Bail out!
";
    use_ok( 'SailTools::SailDataSet' ) || print "Bail out!
";
    use_ok( 'SailTools::SailHtkWrapper' ) || print "Bail out!
";
}

diag( "Testing SailTools $SailTools::VERSION, Perl $], $^X" );

use strict;
use warnings;
use Module::Build;
use File::Spec::Functions;
use File::Path qw(mkpath);
use POSIX qw(uname);
use LWP::Simple;
use Archive::Extract;

my $bin_dir = "bin";
my $config_dir = "config";
my $support_dir = "support";
my $model_dir = "models/ac_models";
my $model_url = "http://cvsp.cs.ntua.gr/~nassos/sail_align";
my $required_modules_hash_ref = {
       'Log::Log4perl' => '1.31',
       'Math::Random' => '0.71',
       'OLE::Storage_Lite' => '0.19',
       'Parallel::ForkManager' => '0.7.9',
       'Spreadsheet::ParseExcel' => '0.55',
       'Audio::Wav' => '0.13',
};

mkpath($bin_dir);
mkpath($config_dir);

my $builder = Module::Build->new(
    module_name         => 'SailTools',
    dist_name           => 'SailAlign',
    script_files        => 'scripts',
    license             => 'gpl',
    requires            => $required_modules_hash_ref,
    dist_author         => q{Athanasios Katsamanis <nkatsam@sipi.usc.edu>},
    dist_version_from   => 'lib/SailTools.pm',
    build_requires => {
        'Test::More' => 0,
    },
    add_to_cleanup      => [ 'SailAlign-*' ],
    create_makefile_pl => 'passthrough',
);

# Get the path to the HTK binaries
my $htk_bin_dir = $builder->prompt(
    "Due to licensing issues the following HTK binaries are required and have not been included in the distribution: HCopy, HDecode, HERest, HHEd, HParse, HVite. \n".
    "Please provide the directory where these are installed: ", 
    '/usr/local/bin');

# Check if the binaries really exist and work. If not, quit.
# Otherwise create symbolic links to these binaries inside the bin directory
my @htk_binaries = ('HCopy', 'HERest', 'HHEd', 'HParse', 'HVite', 'HDecode');
foreach my $htk_tool (@htk_binaries) {
    my $htk_tool_bin = catfile($htk_bin_dir, $htk_tool);
    if (!-e $htk_tool_bin) {
        die("$htk_tool is missing. Cannot proceed with installation.");
    }
    else {
        my $command = "$htk_tool_bin -V";
        open(MPIPE, "$command 2>&1 |") || FATAL("Cannot open pipe to run command:\n$command\n");
        my @output = <MPIPE>;
        close(MPIPE);
        if (grep {/HTK\sVersion/} @output) {
            print "$htk_tool is installed. Creating symbolic link in the directory of binaries.\n";

            # Create the symbolic links inside the bin directory
            my $link_name = catfile($bin_dir, $htk_tool);
            unlink($link_name);
            symlink($htk_tool_bin, $link_name);
        }
        else {
            print "$htk_tool is seemingly not installed.\n";
            print "$htk_tool run output: ".join("\n", @output)."\n";
            die("$htk_tool is not working properly. Cannot proceed with installation.\n");
        }
    }
}

# Find the architecture of the system and check whether the other binaries work
# Check for the platform using uname
my ($sysname, $nodename, $release, $version, $machine) = POSIX::uname();
my $bin_sys_id = lc($sysname)."_$machine";
print "Platform: $bin_sys_id\n";

if (!-e catdir('support','bin',$bin_sys_id)) {
    die("There are no precompiled binaries for your platform. Cannot proceed with installation\n");
}

my @util_binaries = ('ngram', 'ngram-count', 'ch_track', 'vad', 'sclite');
my $bin_args = { 
    'ngram'       => '-help',
    'ngram-count' => '-help',
    'ch_track'    => '-help',
    'vad'         => '--help',
    'sclite'      => '',
};
my $bin_output = {
    'ngram'       => 'Usage',
    'ngram-count' => 'Usage',
    'ch_track'    => 'Usage',
    'vad'         => 'Usage',
    'sclite'      => 'OPTIONS',
};

my $root_path = $builder->base_dir;
foreach my $util_tool (@util_binaries) {
    my $util_tool_bin = catfile($root_path,'support','bin',$bin_sys_id,$util_tool);

    if (!-e $util_tool_bin) {
        die("$util_tool_bin is missing. Cannot proceed with installation.\n");
    }
    else {
        my $command = $util_tool_bin." ".$bin_args->{$util_tool};
        open(MPIPE, "$command 2>&1 |") || FATAL("Cannot open pipe to run command:\n$command\n");
        my @output = <MPIPE>;
        close(MPIPE);
        
        my $exp_output = $bin_output->{$util_tool};
        if (grep {/$exp_output/} @output) {
            print "$util_tool is working. Creating symbolic link in the directory of binaries.\n";

            # Create the symbolic links inside the bin directory
            my $link_name = catfile($bin_dir, $util_tool);
            unlink($link_name);
            symlink($util_tool_bin, $link_name);
        }
        else {
            print "$util_tool is not working. Probably needs to be recompiled.\n";
            print "Please contact the author of SailAlign.\n";
            print "$util_tool run output: ".join("\n", @output)."\n";
            die("Cannot proceed with installation.\n");
        }
    }
}

# Download the acoustic models if they do not already exist
if (!-e catdir($model_dir, "english", "htk", "wsj_all_10000_32")) {
    print "Downloading english acoustic models from $model_url\n";
    mkpath(catdir($model_dir,"english"));
    my $model_tgz = catfile($model_dir, "english", "english_htk.tgz");
    getstore("$model_url/english_htk.tgz", $model_tgz);

    # Extract files
    my $archive = Archive::Extract->new( archive => $model_tgz );
    my $ok = $archive->extract( to => catdir($model_dir, "english") ) or die $archive->error;
    unlink($model_tgz);
}

if (!-e catdir($model_dir, "spanish", "htk", "voxforge_all_8")) {
    print "Downloading spanish acoustic models from $model_url\n";
    mkpath(catdir($model_dir,"spanish"));
    my $model_tgz = catfile($model_dir, "spanish", "spanish_htk.tgz");
    getstore("$model_url/spanish_htk.tgz", $model_tgz);

    # Extract files
    my $archive = Archive::Extract->new( archive => $model_tgz );
    my $ok = $archive->extract( to => catdir($model_dir, "spanish") ) or die $archive->error;
    unlink($model_tgz);
}

if (!-e catdir($model_dir, "greek", "htk", "greekdb_all_14")) {
    print "Downloading greek acoustic models from $model_url\n";
    mkpath(catdir($model_dir,"greek"));
    my $model_tgz = catfile($model_dir, "greek", "greek_htk.tgz");
    getstore("$model_url/greek_htk.tgz", $model_tgz);

    # Extract files
    my $archive = Archive::Extract->new( archive => $model_tgz );
    my $ok = $archive->extract( to => catdir($model_dir, "greek") ) or die $archive->error;
    unlink($model_tgz);
}

if (!-e catdir($model_dir, "norwegian", "htk", "norwegian_24")) {
    print "Downloading norwegian acoustic models from $model_url\n";
    mkpath(catdir($model_dir,"norwegian"));
    my $model_tgz = catfile($model_dir, "norwegian", "norwegian_htk.tgz");
    getstore("$model_url/norwegian_htk.tgz", $model_tgz);

    # Extract files
    my $archive = Archive::Extract->new( archive => $model_tgz );
    my $ok = $archive->extract( to => catdir($model_dir, "norwegian") ) or die $archive->error;
    unlink($model_tgz);
}

# Properly modify the configuration files
my @config_files = ("timit_alignment.cfg", "spanish_alignment.cfg","greek_alignment.cfg", "norwegian_alignment.cfg");

foreach my $conf (@config_files)
{ 
    my $config_file_tmpl = catfile('support', 'config', $conf);
    my $config_file = catfile($config_dir, $conf);
    open(CFG_TMPL, $config_file_tmpl) or die("Cannot open file $config_file_tmpl for reading");
    open(CFG, ">$config_file") or die("Cannot open file $config_file for writing");
    while (<CFG_TMPL>) {
        my $line = $_;
        chomp($line);
        if ($line =~ /^\$ROOTPATH\s+=\s+\"([^\"]+)\"/) {
            my $default_path = $1;
            $line =~ s/\Q$default_path\E/$root_path/;
        } 
        print CFG $line."\n";
    }
    close(CFG);
    close(CFG_TMPL);
}

$builder->create_build_script();

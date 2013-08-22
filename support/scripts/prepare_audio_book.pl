#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  prepare_audio_book.pl
#
#        USAGE:  ./prepare_audio_book.pl  
#
#  DESCRIPTION:  Preparation of an audio book for speech text alignment.
#                1) Convert the mp3 files to wavs
#                2) Find correspondence of audio files to chapters.
#                3) Divide the text into chapters. Each chapter is saved in 
#                   a separate file with the same basename as the wav file.
#                4) Clean the text from punctuation.
#
#      OPTIONS:  -h                 Help message
#                -d dir             Audio book folder
#                -t dir             Text folder
#                -o dir             Output folder (where .wav and .txt files will 
#                                   be stored)
#                -l file            list of final audio files
#                
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Nassos Katsamanis (NK), nkatsam@sipi.usc.edu
#      COMPANY:  University of Southern California
#      VERSION:  1.0
#      CREATED:  11/24/2010 09:42:46 AM
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

use SailTools::SailComponent;
use SailTools::SailDataSet;
use File::Basename;
use Getopt::Long;
use File::Spec::Functions;
use File::Path;
use File::Copy;

my $help = 0;
my $audio_book_folder = "audio_books";
my $text_folder = "audio_books/text";
my $out_folder = "out";
my $file_list = "audio.list";
my $title_bch_ech_author = '([^_]+)_(\d+)_*(\d+)*_([^_]+)';
my $naming_pattern = $title_bch_ech_author;
my $type = 1;

GetOptions(
    'h' => \$help,
    'd=s' => \$audio_book_folder,
    'o=s' => \$out_folder,
    'l=s' => \$file_list,
    't=s' => \$text_folder,
  ) or usage();
if ($help) {usage();}

my $audio_files_ref = SailTools::SailDataSet::find_files_with_suffix_in_dir($audio_book_folder, "mp3" );
my %ids_map;
@$audio_files_ref = sort @$audio_files_ref;
mkpath($out_folder);

my $n_audio_files = @$audio_files_ref;
my @n_vol_chapters;
$n_vol_chapters[0] = 0;
my %vol_map;
open(FL, ">$file_list") or die("Cannot open file list $file_list for writing\n");
for (my $file_counter=0; $file_counter<$n_audio_files; $file_counter++) {
    my $file = $audio_files_ref->[$file_counter];
    my $file_abs_path = catfile($audio_book_folder, $file);
    my ($b_name, $path, $sfx) = fileparse($file, "\.mp3");

    my @info = split(/_/, $b_name);

    my ($title, $vol, $bch, $ech, $author, $compression);
    $vol = 1;
    if (@info==5) { 
        if ($type == 1) {
          $title = $info[0];
          $bch = int($info[1]);
          $ech = int($info[2]);
          $author = $info[3];
          $compression = $info[4];
      }
      elsif ($type == 2) {
          $title = $info[0];
          $vol = int($info[1]);
          $n_vol_chapters[$vol]++;
          $bch = int($info[2]);
          $author = $info[3];
          $compression = $info[4];
          $ech = $bch;
      }
    }
    elsif (@info==4) {
        $title = $info[0];
        if ($info[1] !~ /^\d+$/) {
          $bch = 0;
        }
        else {
          $bch = int($info[1]);
        }
        $ech = $bch;
        $author = $info[3];
        $compression = $info[4];
    }
    elsif (@info==2) {
        $title = $info[1];
        $bch = int($info[0]);
        $ech = $bch;

        if ($type == 4) {
            #      $bch -= 1;
            # $ech = $bch;
        }
    }
    elsif (@info==1) {
        $title = $info[0];
        $bch = 1;
        $ech = 1;
    }
    if ($bch == 0) {
         # print "Skipping file $file\n";
         #     next;
    }
    
    my $b_id = "${title}_${vol}_${bch}_${ech}";
    $ids_map{$b_id} = $bch;
    $vol_map{$b_id} = $vol;

    my $output_file = catfile($out_folder, $b_id.".wav");
    print FL "$b_id.wav\n";
    my $cmd = "mpg123 --mono -r 16000 -w $output_file $file_abs_path";
    #system($cmd);
}
close(FL);

foreach my $b_id (keys %ids_map) { 
    my $s = $ids_map{$b_id};
    my $cur_vol = $vol_map{$b_id};
    for (my $c=0; $c<$cur_vol; $c++) {
      $ids_map{$b_id} += $n_vol_chapters[$c];
    }
    my $l = $ids_map{$b_id};
    #print "$b_id $s $l\n";
}

my $text_files_ref = SailTools::SailDataSet::find_files_with_suffix_in_dir($text_folder, "txt");
my $text = catfile($text_folder, $text_files_ref->[0]);

open(TXT, $text) or die("Cannot open text file $text for reading");
my $current_chapter = -1;

my @ids;
foreach my $key (sort {$ids_map{$a} <=> $ids_map{$b}} (keys(%ids_map))) {
    push(@ids, $key);
}
my $id = shift @ids;
my @saved_ids = @ids;
my $bch = $ids_map{$id};
my $chap = -1;
my $trans_file;
if ($type == 3) {
    $trans_file = catfile($out_folder, "$id.txt");
    open(CH, ">".$trans_file);
}
my $start_reading = 0;

while (my $line = <TXT>) {
    chomp($line);

    if (($line !~ /\*\*\* START OF THIS PROJECT/) && (!$start_reading)) {
        $start_reading = 1;
    }
    elsif (!$start_reading) {
        next;
    }
    if ($line =~ /\*\*\* END OF THIS PROJECT/)  {
        last;
    }

    if ((($line =~ /^[IXV0]+\./) || ($line =~ /^chapter\s(.+)/i)) && ( $type != 3)) {
        # my $chap = int($1);
        print $line."\n";
        $chap++;
        print "Chapter $chap $bch\n";
        if (($current_chapter != -1) && ($chap == $bch)) {
            close(CH);
            $trans_file = catfile($out_folder, "$id.txt");
            open(CH, ">".$trans_file);
            if (@ids) {
              $id = shift @ids;
              $bch = $ids_map{$id};
          }
        }
        elsif ($chap == $bch) {
           print catfile($out_folder, "$id.txt")."\n";
            open(CH, ">".catfile($out_folder, "$id.txt"));
            $id = shift @ids;
            $bch = $ids_map{$id};
        }
        $current_chapter = $chap;
    }
    elsif (($current_chapter == -1) && ($type != 3)) {
        next;
    }
    else {
        $line =~ s/\r//g;
        $line =~ s/[\[\]\*()\.\?\-!,:,;\"]/ /g;
        $line =~ s/^\s+//;
        $line =~ s/\s\'/ /g;
        $line =~ s/\s\'/ /g;
        print CH uc($line)." ";
    }
}
close(CH);
close(TXT);

if ($type==3) {
  foreach my $id (@saved_ids) {
      my $txt_file = catfile($out_folder, "$id.txt");
      copy( $trans_file, $txt_file);
  }
}


sub usage {
    print qq{
#===============================================================================
#
#         FILE:  prepare_audio_book.pl
#
#        USAGE:  ./prepare_audio_book.pl  
#
#  DESCRIPTION:  Preparation of an audio book for speech text alignment.
#                1) Convert the mp3 files to wavs
#                2) Find correspondence of audio files to chapters.
#                3) Divide the text into chapters. Each chapter is saved in 
#                   a separate file with the same basename as the wav file.
#                4) Clean the text from punctuation.
#
#      OPTIONS:  -h                 Help message
#                -d dir             Audio book folder
#                -t dir             Text folder
#                -o dir             Output folder (where .wav and .txt files will 
#                                   be stored)
#                -l file            list of final audio files


    };
    exit;
}

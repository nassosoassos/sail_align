#!/usr/bin/perl

# Used to create a new set of phone label TIMIT
# training data where we have used the word 
# level transcriptions to insert sp phones
# between the words in phone level transcriptions.
#
# Copyright 2005 by Keith Vertanen
#

use strict;

if ( @ARGV < 2 )
{
    print "$0 <file containing list of *.PHN files> <output extension>\n"; 
    exit(1);
}

my $listFile;
my $outExt;

($listFile, $outExt) = @ARGV;

my $line;
my $baseName;
my @startTimes;
my $numWords;
my @chunks;
my $currentWord;

open(IN, $listFile);
while ($line = <IN>) 
{
    $line =~ s/\n//g;
    $line =~ s/\r//g;

    # Make sure the line has some content
    if ($line =~ /\w/)
    {
	$baseName = substr($line, 0, rindex($line, "."));

#print $baseName . "\n";

	# First read in the word break points from the word
	# level transcription file which should be stored
	# in a *.WRD filename. 
	open(IN_WRD, $baseName . ".WRD");

	$numWords = 0;

	# Skip the first line
	$line = <IN_WRD>;
	while ($line = <IN_WRD>)
	{
	    $line =~ s/\n//g;
	    $line =~ s/\r//g;

	    @chunks = split(/\s{1,}/, $line);

	    $startTimes[$numWords] = $chunks[0];
	    $numWords++;
	}
	close(IN_WRD);

	open(OUT, ">" . $baseName . "." . $outExt);      
	open(IN_PHN, $baseName . ".PHN");

	$currentWord = 0;

	while ($line = <IN_PHN>)
	{
	    $line =~ s/\n//g;
	    $line =~ s/\r//g;

	    if ($line =~ /\w/)
	    {
		@chunks = split(/\s{1,}/, $line);

		# If this phone starts at the start of a new word, then
		# we put in a short pause phone.
		if (($currentWord < $numWords) && ($startTimes[$currentWord] == $chunks[0]))
		{
		    print OUT $chunks[0] . " ". $chunks[0] . " sp\n";
		    $currentWord++;
		}

		print OUT $line . "\n";
	    }
	}
       	
	close(IN_PHN);
	close(OUT);

    }
}
close IN;

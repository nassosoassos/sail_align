#!/usr/bin/perl

# Given a list of MFC files, a list of transcriptions in WSJ DOT format,
# a dictionary, produce a word level MLF file and script file that
# only contain things were all the words are in the dictionary.
#
# Also can be set to ignore [] elements in the transcripts and 
# output a file of all the unknown vocab.  But it turns out to be
# better to include these in the training (0.67 abs on Nov92)
#
# Optionally can be set to output even those with unknown vocab,
# this would be used when construction a test set MLF with OOVs.
#
# Can also optionally try and fix up things like:
#     *WORLD*
#     STOCKDEALS
#
# A find-and-replace file can be sent in to manually enter corrections
# for some transcriptions.
#
# Copyright 2006 by Keith Vertanen
#

use strict;

if ( @ARGV < 5 )
{
    print "$0 <MFC files> <transcription files> <dictionary> <output MLF> <output script> [ignore noises] [include OOVs] [unknown vocab file] [fix up] [find and replace file] [split file]\n";
    exit(1);
}

my $mfcFiles;
my $transFiles;
my $line;
my $posStart;
my $posEnd;
my $id; 
my $dictFile;
my $outputMLF;
my $outputScript;
my %missing;
my $missingFile;
my $ignoreNoises;
my %idsCase;
my $includeOOVs;
my %foundTrans;
my $fixUp;
my $findReplaceFile;
my %findReplace;
my %trans;
my $filename;
my $text;
my @words;
my $i;
my $j;
my $outLine;
my $badWord;
my $firstChar;
my $word;
my $madeFix;
my $goodSplits = 0;
my $splitLoc = -1;
my $part1;
my $part2;
my $pos1;
my $pos2;
my %hasFile;
my %mfcNames;
my %inDict;
my @chunks;
my $convertedLine;
my $splitFile;
my %splits;
my $totalTrain;
my $totalGood;
my %idWithPath;

($mfcFiles, $transFiles, $dictFile, $outputMLF, $outputScript, $ignoreNoises, $includeOOVs, $missingFile, $fixUp, $findReplaceFile, $splitFile) = @ARGV;

print "MFC file:              $mfcFiles\n";
print "Transcription file:    $transFiles\n";
print "Dictionary:            $dictFile\n";
print "Output MLF:            $outputMLF\n";
print "Output script:         $outputScript\n";
print "Ignore noises:         $ignoreNoises\n";
print "Include OOVs:          $includeOOVs\n";
print "Unknown vocab:         $missingFile\n";
print "Fix up:                $fixUp\n";
print "Find and replace:      $findReplaceFile\n";
print "Split file:            $splitFile\n\n";

# print "Include OOVs = " . $includeOOVs . "\n";

# First we read in all the MFC filenames into a hash

open(IN, $mfcFiles);
while ($line = <IN>) 
{
    $line =~ s/\n//g;

    $posStart = rindex($line, "/");
    $posEnd   = rindex($line, ".");

    if (($posStart > -1) && ($posEnd > -1))
    {
	$id = substr($line, $posStart + 1, $posEnd - $posStart - 1);

	# Remember the original case of the file on disk
	$idsCase{lc($id)} = $id;
	$id = lc($id);

	$posStart = index($line, ".");
	$idWithPath{$id} = substr($line, $posStart, $posEnd - $posStart);

#	print "id = " . $id . ", line = '" . $line . "'\n";

	if ($hasFile{$id})
	{
	    print "WARNING: duplicate file ID of $id!\n";
	}

	$hasFile{$id} = 1;
	$mfcNames{$id} = $line;
	$foundTrans{$id} = 0;

	$totalTrain++;
    }
}
close IN;

# Read in all the words we have in our dictionary

open(IN, $dictFile);
while ($line = <IN>) 
{
    $line =~ s/\n//g;
    @chunks = split(/\s{1,}/, $line);

    if (scalar @chunks > 0)
    {
	# Remove any escaping of special character with back slash
	$chunks[0] =~ s/\\//g;
	
	$inDict{$chunks[0]} = 1;
    }
}
close IN;

# Load our table of find and replace manually entered fixes
if ($findReplaceFile)
{
    open(IN, $findReplaceFile);
    while ($line = <IN>) 
    {
	$line =~ s/\n//g;
	@chunks = split(/\s{1,}/, $line);
	
	if (scalar @chunks >= 2)
	{
	    $word = "";
	    for ($i = 1; $i < scalar @chunks; $i++)
	    {
		$word = $word . $chunks[$i];
		if ($i < (scalar @chunks - 1))
		{
		    $word = $word . " ";
		}
	    }

	    $findReplace{$chunks[0]} = $word;
	}
    }
    
    close IN;
}


# Now read all the transcription that we have into another hash

open(IN, $transFiles);
open(OUT_MLF, ">" . $outputMLF);
open(OUT_SCRIPT, ">" . $outputScript);

print OUT_MLF "#!MLF!#\n";

while ($filename = <IN>) 
{
    $filename =~ s/\n//g;

#print "Working on filename: " . $filename . "\n";

    open(IN2, $filename);
    
    while ($line = <IN2>)
    {
#print "Line is: " . $line . "\n";

	$posStart = rindex($line, "(");
	$posEnd   = rindex($line, ")");


	@words = split(/\s{1,}/, $line);
	if (($line =~ /bad_recording/) || (scalar @words <= 2))
	{
	    # Drop the training file if the recording was marked as bad
	    # or there wasn't a plausibe number of words in the transcript.
	}
	elsif (($posStart > -1) && ($posEnd > -1))
	{
	    $id = substr($line, $posStart + 1, $posEnd - $posStart - 1);
	    $id = lc($id);

	    $foundTrans{$id} = 1;

	    $text = substr($line, 0, $posStart - 1);

	    # WSJ0 dot files are mixed case, convert to upper to match 
	    # CMU dictionary
	    $text = uc($text);
	    
	    # We got read of the escaped special characters when we read
	    # in the dictionary so do the same here.
	    $text =~ s/\\//g;

	    # Sometimes we get a . surrounded by whitespace in the 
	    # transcripts.  This appears to not denote anything in
	    # the audio, so we'll just eliminate these from the
	    # transcripts.
	    $text =~ s/\s\.\s/ /g;

	    if ($ignoreNoises)
	    {
		# Get rid of anything between []'s
		$text =~ s/\[[\w\<\>\/\-\_]*\]//g;
	    }

	    $outLine = "";

	    # If we found a MFC file with this ID then we output
	    if (($hasFile{$id} > 0) && (length($text) > 0))
	    {
#print "Found ID: " . $id . "\n";


		$outLine = $outLine . "\"" . $idWithPath{$id} . ".lab\"\n";

#		$outLine = $outLine . "\"*/";
#		# Make sure to use the same case as was on disk
#		$outLine = $outLine .$idsCase{$id};
#		$outLine = $outLine .".lab\"\n";

		@words = split(/\s{1,}/, $text);
		$badWord = 0;

		$convertedLine = "";
		# Apply any find and replace rules for this word
		if ($findReplaceFile)
		{
		    for ($i = 0; $i < scalar @words; $i++)
		    {
			if ($findReplace{$words[$i]})
			{			    
			    $convertedLine = $convertedLine . $findReplace{$words[$i]};
			}
			else
			{
			    $convertedLine = $convertedLine . $words[$i];
			}

			if ($i < (scalar @words - 1))
			{
			    $convertedLine = $convertedLine . " ";
			}
		    }

		    @words = split(/\s{1,}/, $convertedLine);			
		}


		for ($i = 0; $i < scalar @words; $i++)
		{
		    if (length($words[$i]) > 0)
		    {
			# Make sure every word is in our dictionary
			if ($inDict{$words[$i]} == 1)
			{
			    # If first letter is non-alphanumeric, we escape it			    
			    $firstChar = substr($words[$i], 0, 1);
			    
			    if ($firstChar !~ /[A-Za-z0-9]/)
			    {
				$words[$i] = "\\" . $words[$i];
			    }

			    $outLine = $outLine . $words[$i] . "\n";
			}
			else
			{
			    $word = $words[$i];
			    $madeFix = 0;

			    if ($fixUp)
			    {
				# Try and recover from common problems in the transcripts
				$word = $words[$i];


				# Make things like *KINSLEY*'S into KINSLEY'S
				if ($word =~ /^\*.+\*\'S$/)
				{
				    $word =~ s/\*//g;
				}

				# Handle words like *BLAH*
				if ($word =~ /\*.+\*/)
				{
				    # Check for cases like *EIGHTH*AND or EIGHTH*AND*, in these
				    # cases we'll split and check both words
				    
				    $pos1 = index($word, "\*");
				    $pos2 = rindex($word, "\*");

				    if (($pos1 != 0) || ($pos2 != (length($word) - 1)))
				    {
					if ($pos1 == 0)
					{
					    $part1 = substr($word, 1, $pos2 - 1);
					    $part2 = substr($word, $pos2 + 1);
					    # print "part1 $part1 part2 $part2\n";
					}
					else
					{
					    $part1 = substr($word, 0, $pos1);
					    $part2 = substr($word, $pos1 + 1, $pos2 - $pos1 - 1);
					}

					if (($inDict{$part1}) && ($inDict{$part2}))
					{
					    $madeFix = 1;
					    $outLine = $outLine . $part1 . "\n" . $part2 . "\n";					    				           
					    # print "part 1 $part1 part2 $part2 both in dict\n"; 
					}
					
				    }

				    if (!$madeFix)
				    {
					$word =~ s/\*//g;
				    }

#				    print "temp: " . $word . "\n";
				}

				# Fix words like !WASHINGTON
				if ($word =~ /^\!/)
				{
				    $word =~ s/\!//g;				    
				}
				
				# Repalce back apostrophe with normal one
				if ($word =~ /\`/)
				{
				    $word =~ s/\`/\'/g;
				}

				# Colon indicates a bit of a blip in their
				# prounouncing a word, we'll use them anyway.
				if ($word =~ /\:/)
				{
				    $word =~ s/\://g;
				}

				if ((!$madeFix) && (!$inDict{$word}))
				{
				    # Sometimes words are missing a space,
				    # if we can split into two dictionary words
				    # we output them to the split file for
				    # review (it would be dubious to accept
				    # without human review).

				    $goodSplits = 0;
				    $splitLoc = -1;
				    for ($j = 1; $j < length($word); $j++)
				    {
					$part1 = substr($word, 0, $j);
					$part2 = substr($word, $j);

					if (($inDict{$part1}) && ($inDict{$part2}))
					{
					    $goodSplits++;
					    $splitLoc = $j;
					}
#					print $part1 . " - " . $part2 . "\n";
				    }

				    # Only counts if there was one unique good way to split
				    if ($goodSplits == 1)
				    {				      
					# This is a possible good split to recommend
					$splits{$word} = $part1 . " " . $part2;
				    }
				    elsif ($goodSplits > 1)
				    {
					# Not sure which split was right
					$splits{$word} = $word;
				    }

				}
				else
				{
				    if (!$madeFix)
				    {
					# We modified the word to match
					$outLine = $outLine . $word . "\n";
					$madeFix = 1;
				    }
				}

			    }

			    if (!$madeFix)
			    {
				$badWord = 1;
				$missing{$words[$i]}++;

				# Print it out to the console
				print $id . "\t" . $words[$i] . "\n";
			    }
			}
		    }
		}
		
		$outLine = $outLine .".\n";
	    }
	    else
{
#print "Not found ID: " . $id . "\n";
}

	    # Output the line to our MLF file if everything was in dictionary
	    if (($badWord == 0) || ($includeOOVs))
	    {
		print OUT_MLF $outLine;
		#print "looking for: '" . $id . "' = '" . $mfcNames{$id} . "'\n";
		if ($hasFile{$id})
		{
		    print OUT_SCRIPT $mfcNames{$id} . "\n";

		    $totalGood++;
		}
	    }

	}
    }
    close IN2;

}

close IN;
close OUT_MLF;
close OUT_SCRIPT;

# Dump out all the unique split suggestions
if ($splitFile)
{
    open(OUT_SPLIT, ">", $splitFile);

    foreach $i (sort keys %splits)
    {
	print OUT_SPLIT $i . "\t" . $splits{$i} . "\n";
    }
    close OUT_SPLIT;
}

my $word;

# Output the file containing all the missing words, sorted
if (length($missingFile) > 0)
{
    open(OUT_MISSING, ">" . $missingFile);
    foreach $word (sort keys %missing)
    {
	print OUT_MISSING $word . "\t" . $missing{$word} . "\n";
#	print OUT_MISSING $word . "\n";
    }
    close OUT_MISSING;
}

# Output any MFC files that didn't have a transcription
foreach $id (sort keys %foundTrans)
{
    if ($foundTrans{$id} == 0)
    {
	print "MFC missing trans: " . $id . "\n";
    }

}

print "Total MFC files: $totalTrain\n";
print "Total good:      $totalGood\n";

package SailTools::SailHtkWrapper;

use warnings;
use strict;
use Log::Log4perl qw(:easy);
use File::Spec::Functions;
use File::Path;
use Data::Dumper;
use SailTools::SailComponent;
use File::Basename;

=head1 NAME

SailTools::SailHtkWrapper - Wrapper for HTK tools in the SailTools library

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.3.0';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use SailTools::SailHtkWrapper;

    my $foo = SailTools::SailHtkWrapper->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 print_htk_config

Print HTK configuration file
Usage:
  print_htk_config("file.cfg", \%cfg);

=cut

sub print_htk_config {
  my ($conf_file, $conf_hash_ref) = @_;
  
  open(FILE,">$conf_file") || FATAL("Cannot open $conf_file for writing.");
  foreach my $key (keys %$conf_hash_ref) {
     print FILE $key.' = '.$$conf_hash_ref{$key}."\n";  
  }
  close(FILE);
}

=head2 run_hcopy

Run HCopy for feature extraction.
Usage:
  run_hcopy($signal, $feature_seq, \%cfg);

=cut
sub run_hcopy {
    my ($signal, $feature_seq, $configuration) = @_;

    my $configuration_file = $configuration->{configuration_file};
    my %conf_hash;
    my $current_experiment = $configuration->{experiment};
    my $bin_dir = $current_experiment->{bin_dir};


    my $in_file = $signal->{file};
    my $out_file = $feature_seq->{file};
    
    if ($signal->{format} eq 'WAV') {
       $conf_hash{SOURCEFORMAT} = 'WAV';
    }
    else {
        $conf_hash{SOURCEFORMAT} = $signal->{format};
        $conf_hash{SOURCERATE} = $signal->{Fs}*(10**7);
    }

    $conf_hash{TARGETFORMAT} = $configuration->{format};
    $conf_hash{TARGETKIND} = $configuration->{kind};
    $conf_hash{TARGETRATE} = $configuration->{rate}*(10**7);

    if ($configuration->{save_compressed}) { 
       $conf_hash{SAVECOMPRESSED}=$configuration->{save_compressed};
    }
    else {
       $conf_hash{SAVECOMPRESSED}='F';
    }
    if ($configuration->{save_with_crc}) {
        $conf_hash{SAVEWITHCRC}=$configuration->{save_with_crc};
    }
    else {
        $conf_hash{SAVEWITHCRC}='F';
    }
    if ($configuration->{window_size}) {
        $conf_hash{WINDOWSIZE} = $configuration->{window_size}*(10**7);
    }
    if ($configuration->{use_hamming}) {
        $conf_hash{USEHAMMING} = 'T';
    }
    else {
        $conf_hash{USEHAMMING} = 'F';
    }
    if ($configuration->{preemphasis_factor}) {
        $conf_hash{PREEMCOEF} = $configuration->{preemphasis_factor};
    }
    if ($configuration->{n_filters}) {
        $conf_hash{NUMCHANS} = $configuration->{n_filters};
    }
    if (exists $configuration->{cepstral_liftering}) {
        $conf_hash{CEPLIFTER} = $configuration->{cepstral_liftering};       
    }
    if ($configuration->{n_cepstral_coefs}) {
        $conf_hash{NUMCEPS} = $configuration->{n_cepstral_coefs};
    }
    if ($configuration->{normalize_energy}) {
        $conf_hash{ENORMALISE} = $configuration->{normalize_energy};
    }
    else {
        $conf_hash{ENORMALISE} = 'F';
    }
    if ($configuration->{subtract_dc}) {
        $conf_hash{ZMEANSOURCE} = 'T';
    }
    else {
        $conf_hash{ZMEANSOURCE} = 'F';
    }
    if ($configuration->{use_power}) {
        $conf_hash{USEPOWER} = $configuration->{use_power};
    }
    else {
        $conf_hash{USEPOWER} = 'F';
    }
    if ($configuration->{byte_order}) {
        $conf_hash{BYTEORDER} = $configuration->{byte_order};
    }
    my $trace_level = $configuration->{log_level};
    my $display_conf_settings =0;
    my $print_arguments = 0;
    if ($trace_level>2) {
        $display_conf_settings =1;
        $print_arguments = 2;
    }
    print_htk_config($configuration_file, \%conf_hash);
    my $arguments = "-C $configuration_file $in_file $out_file";
    my $error_indicators = run_htk('HCopy',$arguments, $trace_level, $display_conf_settings, $print_arguments, $bin_dir);
    if (@$error_indicators) {
        FATAL("HCopy failed:".@$error_indicators);
    }
}

=head2 run_hdecode_recognize_lm 

Run HDecode for speech recognition using an arpa formatted language model
Usage:
   run_hdecode_recognize_lm( $ac_model, $language_model, $dictionary, $file_list, $output_directory, \%cfg ); 

=cut
sub run_hdecode_recognize_lm {
	my ($ac_model, $language_model, $dictionary, $file_list, $output_directory, $configuration) = @_;

    my $configuration_file = $configuration->{configuration_file};
    my %conf_hash;
    my $bin_dir = $configuration->{bin_path};
    my $pruning = $configuration->{prune};
    my @pruning_info = split(/\s/, $pruning);
    $pruning = $pruning_info[1];
    my $insertion_penalty = $configuration->{insert_pen};
    my $lm_scale = $configuration->{lm_scale};
     
	my $model_file = catfile($ac_model->{path}, $ac_model->{file});
	my $macros_file = catfile($ac_model->{path}, $ac_model->{macros});
	my $model_list = catfile($ac_model->{path}, $ac_model->{list});	
	my $lm_file = $language_model->{file};

    if ($configuration->{triphone_context}) { 
       $conf_hash{FORCECXTEXP}=$configuration->{triphone_context};
    }
    if ($configuration->{word_context}) {
        $conf_hash{ALLOWXWRDEXP}=$configuration->{word_context};
    }
    if ($configuration->{no_num_escapes}) {
        $conf_hash{NONUMESCAPES}=$configuration->{no_num_escapes};
    }
    my $trace_level = $configuration->{log_level};
    my $display_conf_settings =0;
    my $print_arguments = 0;
    if ($trace_level>2) {
        $display_conf_settings =1;
        $print_arguments = 2;
    }
    print_htk_config($configuration_file, \%conf_hash);
    my $arguments="";
      
    if ($configuration->{use_adapted_models}) {
    	my $adaptation_cfg = $configuration->{adaptation};
    	my $transform_dir = $adaptation_cfg->{transforms_dir};
    	my $class_dir = $adaptation_cfg->{class_dir};
    	my $transform_name_pattern = $adaptation_cfg->{transform_name_pattern};
    	my $rc_trans_sfx = $adaptation_cfg->{rc_trans_sfx};
    	
    	$arguments .= "-C $configuration_file -t $pruning -o S -p $insertion_penalty -s $lm_scale".
    				" -J $transform_dir $rc_trans_sfx -h \'$transform_name_pattern\' -m -J $class_dir". 
    				" -H $model_file -H $macros_file -l $output_directory -S $file_list -w $lm_file $dictionary $model_list";    	    	
    }
    else {
    	$arguments .= "-C $configuration_file -t $pruning -o S -p $insertion_penalty -s $lm_scale".
    				" -H $model_file -H $macros_file -l $output_directory -S $file_list -w $lm_file $dictionary $model_list";    	
    }
    my $error_indicators = run_htk('HDecode',$arguments, $trace_level, $display_conf_settings, $print_arguments, $bin_dir);
    if (@$error_indicators) {
        FATAL("HDecode failed:".join(" ",@$error_indicators));
    }    
}

=head2 run_hvite_recognize_lm

Run speech recognition using HTK's HVite and a language model.
Usage: 
  run_hvite_recognize_lm( \%ac_model, \%language_model, $dictionary, $file_list, $output_directory, \%cfg );
=cut
sub run_hvite_recognize_lm {
	my ($ac_model, $language_model, $dictionary, $file_list, $output_directory, $configuration) = @_;

    my $configuration_file = $configuration->{configuration_file};
    my %conf_hash;
    my $bin_dir = $configuration->{bin_path};
    my $pruning = $configuration->{prune};
    my $insertion_penalty = $configuration->{insert_pen};
    my $lm_scale = $configuration->{lm_scale};
     
	my $model_file = catfile($ac_model->{path}, $ac_model->{file});
	my $macros_file = catfile($ac_model->{path}, $ac_model->{macros});
	my $model_list = catfile($ac_model->{path}, $ac_model->{list});	
	my $lm_file = $language_model->{file};

    if ($configuration->{triphone_context}) { 
       $conf_hash{FORCECXTEXP}=$configuration->{triphone_context};
    }
    if ($configuration->{word_context}) {
        $conf_hash{ALLOWXWRDEXP}=$configuration->{word_context};
    }
    my $trace_level = $configuration->{log_level};
    my $display_conf_settings =0;
    my $print_arguments = 0;
    if ($trace_level>2) {
        $display_conf_settings =1;
        $print_arguments = 2;
    }
    print_htk_config($configuration_file, \%conf_hash);
    my $arguments="";
    if ($configuration->{filter_transcriptions}) {
    	$arguments = "-m ";
    }
    if ($configuration->{use_adapted_models}) {
    	my $adaptation_cfg = $configuration->{adaptation};
    	my $transform_dir = $adaptation_cfg->{transforms_dir};
    	my $class_dir = $adaptation_cfg->{class_dir};
    	my $transform_name_pattern = $adaptation_cfg->{transform_name_pattern};
    	my $rc_trans_sfx = $adaptation_cfg->{rc_trans_sfx};
    	
    	$arguments .= "-C $configuration_file -t $pruning -o S -p $insertion_penalty -s $lm_scale".
    				" -J $transform_dir $rc_trans_sfx -h \'$transform_name_pattern\' -k -J $class_dir". 
    				" -H $model_file -H $macros_file -l $output_directory -S $file_list -w $lm_file $dictionary $model_list";    	    	
    }
    else {
    	$arguments .= "-C $configuration_file -t $pruning -o S -p $insertion_penalty -s $lm_scale".
    				" -H $model_file -H $macros_file -l $output_directory -S $file_list -w $lm_file $dictionary $model_list";    	
    }
    my $error_indicators = run_htk('HVite',$arguments, $trace_level, $display_conf_settings, $print_arguments, $bin_dir);
    if (@$error_indicators) {
        FATAL("HVite failed:".join(" ",@$error_indicators));
    }
    
}

=head2 run_hvite_recognize_fsg

Finite state grammar based speech recognition using HVite
Usage:
  run_hvite_recognize_fsg( \%ac_model, $wordnet_file, \%dictionary, $file_list, $output_directory, \%cfg );

=cut
sub run_hvite_recognize_fsg {
	my ($ac_model, $wdnet_file, $dictionary, $file_list, $output_directory, $configuration) = @_;

    my $configuration_file = $configuration->{configuration_file};
    my %conf_hash;
    my $bin_dir = $configuration->{bin_path};
    my $pruning = $configuration->{prune};
    my $insertion_penalty = $configuration->{insert_pen};
    my $lm_scale = $configuration->{lm_scale};
     
	my $model_file = catfile($ac_model->{path}, $ac_model->{file});
	my $macros_file = catfile($ac_model->{path}, $ac_model->{macros});
	my $model_list = catfile($ac_model->{path}, $ac_model->{list});	

    my $trace_level = $configuration->{log_level};
    my $display_conf_settings =0;
    my $print_arguments = 0;
    if ($trace_level>2) {
        $display_conf_settings =1;
        $print_arguments = 2;
    }
    print_htk_config($configuration_file, \%conf_hash);
    my $arguments="";
    if ($configuration->{filter_transcriptions}) {
    	$arguments = "-m ";
    }
    if ($configuration->{use_adapted_models}) {
    	my $adaptation_cfg = $configuration->{adaptation};
    	my $transform_dir = $adaptation_cfg->{transforms_dir};
    	my $class_dir = $adaptation_cfg->{class_dir};
    	my $transform_name_pattern = $adaptation_cfg->{transform_name_pattern};
    	my $rc_trans_sfx = $adaptation_cfg->{rc_trans_sfx};
    	
    	$arguments .= "-C $configuration_file -t $pruning -o S -p $insertion_penalty -s $lm_scale".
    				" -J $transform_dir $rc_trans_sfx -h \'$transform_name_pattern\' -k -J $class_dir". 
    				" -H $model_file -H $macros_file -l $output_directory -S $file_list -w $wdnet_file $dictionary $model_list";    	    	
    }
    else {
    	$arguments .= "-C $configuration_file -t $pruning -o S -p $insertion_penalty -s $lm_scale".
    				" -H $model_file -H $macros_file -l $output_directory -S $file_list -w $wdnet_file $dictionary $model_list";    	
    }
    my $error_indicators = run_htk('HVite',$arguments, $trace_level, $display_conf_settings, $print_arguments, $bin_dir);
    if (@$error_indicators) {
        FATAL("HVite failed:".join(" ",@$error_indicators));
    }
    
}

=head2 run_hvite_align

Forced alignment using the Viterbi algorithm
Usage:
  run_hvite_align( \%ac_model, $transcription_dir, $phon_alignment_file, $dict_file, $scp_file, \%cfg);

=cut
sub run_hvite_align {
	my ($ac_model, $trans_dir, $phone_alignment_filename, $dict_file, $scp_file, $alignment_conf) = @_;	
	
    my $configuration_file = $alignment_conf->{configuration_file};
    my %conf_hash;
    my $bin_dir = $alignment_conf->{bin_path};
    my $pruning = $alignment_conf->{prune};
	my $model_file = catfile($ac_model->{path}, $ac_model->{file});
	my $macros_file = catfile($ac_model->{path}, $ac_model->{macros});
	my $model_list = catfile($ac_model->{path}, $ac_model->{list});
    #my $label_format = 'SWT';
    my $label_format = $alignment_conf->{label_format};
    my $arguments = '';

	my $sen_boundary = $alignment_conf->{sen_boundary};
    if ($alignment_conf->{triphone_context}) { 
       $conf_hash{FORCECXTEXP}=$alignment_conf->{triphone_context};
    }
    if ($alignment_conf->{word_context}) {
        $conf_hash{ALLOWXWRDEXP}=$alignment_conf->{triphone_context};
    }
    if ($alignment_conf->{no_num_escapes}) {
        $conf_hash{NONUMESCAPES}=$alignment_conf->{no_num_escapes};
    }
    if ($alignment_conf->{output_words}) {
		$label_format = 'S';    	
    }
    if ($alignment_conf->{output_dir} eq '*') {
		$arguments = "-l '*' -i $phone_alignment_filename";    	
    }
    else {
    	my $out_dir = $alignment_conf->{output_dir};
    	$arguments = "-l $out_dir";
    }
    if ((!exists $alignment_conf->{track_model_boundaries}) || ($alignment_conf->{track_model_boundaries}==1)) {
        $arguments.= " -m ";
    }
    my $in_suffix = $alignment_conf->{in_suffix};
    my $out_suffix = $alignment_conf->{out_suffix};
    my $trace_level = $alignment_conf->{log_level};
    my $display_conf_settings =0;
    my $print_arguments = 0;
    if ($trace_level>2) {
        $display_conf_settings =1;
        $print_arguments = 2;
    }
    print_htk_config($configuration_file, \%conf_hash);
    
    if ($alignment_conf->{use_adapted_models}) {
    	my $adaptation_cfg = $alignment_conf->{adaptation};
    	my $transform_dir = $adaptation_cfg->{transforms_dir};
    	my $class_dir = $adaptation_cfg->{class_dir};
    	my $transform_name_pattern = $adaptation_cfg->{transform_name_pattern};
    	my $rc_trans_sfx = $adaptation_cfg->{rc_trans_sfx};
    	
    	$arguments .= " -o $label_format -a -C $configuration_file -t $pruning".
    				" -J $transform_dir $rc_trans_sfx -h \'$transform_name_pattern\' -k -J $class_dir". 
    				" -H $model_file -H $macros_file -b \'$sen_boundary\' -L $trans_dir".
    				" -X $in_suffix -y $out_suffix -S $scp_file $dict_file $model_list";  	    	
    }   
    else { 
    	$arguments .= " -o $label_format -C $configuration_file -b \'$sen_boundary\' -a -t $pruning -L $trans_dir".
    				" -H $model_file -H $macros_file -X $in_suffix -y $out_suffix".
    				" -S $scp_file $dict_file $model_list";
    }
    my $error_indicators = run_htk('HVite',$arguments, $trace_level, $display_conf_settings, $print_arguments, $bin_dir);
    if (@$error_indicators) {
        FATAL("HVite failed:". join("\n",@$error_indicators));
    }
}

=head2 run_herest_adapt

Run HERest to perform MLLR adaptation.
Usage:
 $success = run_herest_adapt( \%original_acoustic_models, \%cfg );

=cut
sub run_herest_adapt {
	my ($orig_acoustic_models, $adaptation_cfg) = @_;
	
	my $bin_dir = $adaptation_cfg->{bin_path};
	my $model_file = catfile($orig_acoustic_models->{path}, $orig_acoustic_models->{file});
	my $macros_file = catfile($orig_acoustic_models->{path}, $orig_acoustic_models->{macros});
	my $model_list = catfile($orig_acoustic_models->{path}, $orig_acoustic_models->{list});
	my $scp_file = $adaptation_cfg->{file_list};
	my $mlf = $adaptation_cfg->{alignment}->{mlf};
	my $transform_dir = $adaptation_cfg->{transforms_dir};
	my $class_dir = $adaptation_cfg->{class_dir};
	my $glob_trans_sfx = $adaptation_cfg->{glob_trans_sfx};
	my $rc_trans_sfx = $adaptation_cfg->{rc_trans_sfx};
	my $transform_name_pattern = $adaptation_cfg->{transform_name_pattern};
   	mkpath($transform_dir); 
	
	my $global_config_file = $adaptation_cfg->{glob_config_file};
	my %glob_conf_hash;
	$glob_conf_hash{'HADAPT:TRANSKIND'} = $adaptation_cfg->{transkind};
	$glob_conf_hash{'HADAPT:USEBIAS'} = 'TRUE';
	$glob_conf_hash{'HADAPT:BASECLASS'} = $adaptation_cfg->{base_class};
	$glob_conf_hash{'HADAPT:ADAPTKIND'} = 'BASE';
	$glob_conf_hash{'HADAPT:KEEPXFORMDISTINCT'} = 'TRUE';
	$glob_conf_hash{'HADAPT:TRACE'} = 61;
	$glob_conf_hash{'HMODEL:TRACE'} = 512;
	print_htk_config($global_config_file, \%glob_conf_hash);
	
	my $rc_config_file = $adaptation_cfg->{rc_config_file};
	my %rc_conf_hash;
	$rc_conf_hash{'HADAPT:TRANSKIND'} = $adaptation_cfg->{transkind};
	$rc_conf_hash{'HADAPT:USEBIAS'} = 'TRUE';
	$rc_conf_hash{'HADAPT:REGTREE'} = "rtree.tree";
	$rc_conf_hash{'HADAPT:ADAPTKIND'} = 'TREE';
	$rc_conf_hash{'HADAPT:SPLITTHRESH'} = 1000;
	$rc_conf_hash{'HADAPT:KEEPXFORMDISTINCT'} = 'TRUE';
	$rc_conf_hash{'HADAPT:TRACE'} = 61;
	$rc_conf_hash{'HMODEL:TRACE'} = 512;
	$rc_conf_hash{'HADAPT:SAVESPKRMODELS'} = 'FALSE';	
	print_htk_config($rc_config_file, \%rc_conf_hash);

	my $trace_level = $adaptation_cfg->{log_level};
	my $display_conf_settings =0;
    my $print_arguments = 0;

	# First pass global adaptation
	my $arguments = "-C $global_config_file -S $scp_file -I $mlf ".
					"-H $macros_file -u a -H $model_file -K $transform_dir $glob_trans_sfx ".
					" -J $class_dir -h \'$transform_name_pattern\' $model_list";
    my $error_indicators = run_htk('HERest',$arguments, $trace_level, $display_conf_settings, $print_arguments, $adaptation_cfg->{bin_path});
    if (@$error_indicators) {
        FATAL("HERest global adaptation failed:".@$error_indicators);
    }
    
    # Second pass regression class tree adaptation
	$arguments = "-C $rc_config_file -a -S $scp_file -I $mlf ".
					"-H $macros_file -u a -H $model_file -K $transform_dir $rc_trans_sfx ".
					"-J $transform_dir $glob_trans_sfx -J $class_dir -h \'$transform_name_pattern\' $model_list";
    $error_indicators = run_htk('HERest',$arguments, $trace_level, $display_conf_settings, $print_arguments, $adaptation_cfg->{bin_path});
    my $success=1;
    if (@$error_indicators) {
        FATAL("HERest regression class tree adaptation failed:".@$error_indicators);
        $success=0;
    }
    return $success;
}

=head2 run_hhed_regression_class_tree

Use HTK's tool HHEd to generate a regression class tree which will afterwards be used for adaptation.
Usage: 
  run_hhed_regression_class_tree( \%acoustic_model, \%cfg);

=cut
sub	run_hhed_regression_class_tree {
	my ($ac_model, $regression_cfg) = @_;

	my $model_file = catfile($ac_model->{path}, $ac_model->{file});
	my $macros_file = catfile($ac_model->{path}, $ac_model->{macros});
	my $stats_file = catfile($ac_model->{path}, $ac_model->{stats});
	my $model_list = catfile($ac_model->{path}, $ac_model->{list});
	my $hed_script = $regression_cfg->{hed_file};
	my $class_dir = $regression_cfg->{class_dir};
	my $n_classes = $regression_cfg->{n_classes};
	my $global_class_file = catfile($regression_cfg->{class_dir}, $regression_cfg->{base_class});
	
	mkpath($class_dir);
	# Write HHEd script
	my $load_stats_cmd = "LS \"$stats_file\"";
	my $regression_class_cmd = "RC $n_classes \"rtree\"";
	my @hed_commands = ($load_stats_cmd, $regression_class_cmd);
	SailTools::SailComponent::print_into_file(\@hed_commands, $hed_script, "\n");
	
	# Write global class definition
	my @global_class_def = ("~b \"global\"\n".
						   "\<MMFIDMASK\> *\n".
						   "\<PARAMETERS\> MIXBASE\n".
						   "\<NUMCLASSES\> 1\n".
						   " \<CLASS\> 1 {*.state[2-4].mix[1-64]}"); 
	SailTools::SailComponent::print_into_file(\@global_class_def, $global_class_file);
						   
	my $trace_level = $regression_cfg->{log_level};
	my $display_conf_settings =0;
    my $print_arguments = 0;
	my $arguments = "-B -H $macros_file -H $model_file -M $class_dir ".
					"$hed_script $model_list";	
    my $error_indicators = run_htk('HHEd',$arguments, $trace_level, $display_conf_settings, $print_arguments, $regression_cfg->{bin_path});
    if (@$error_indicators) {
        FATAL("HHEd failed:".@$error_indicators);
    }
}	


=head2 run_hbuild

Low-level HBuild wrapper
Usage:
  run_hbuild( $source_file, $target_file, $word_list, \@utterance_boundaries, $oov_symbol, \%cfg )

=cut
sub run_hbuild {
	my ($source_file, $target_file, $word_list, $utterance_boundaries, $oov_symbol, $configuration) = @_;
	
	my $configuration_file = $configuration->{configuration_file};
	my %conf_hash;
	my $bin_dir = $configuration->{bin_path};
	my @utt_bounds = @$utterance_boundaries;
	for (my $k=0; $k<2; $k++) {
		$utt_bounds[$k] = "\'".$utt_bounds[$k]."\'";
	}
	
	# Add the utterance delimiters to the list of words
	my $words_ref = SailTools::SailComponent::read_from_file($word_list);
	push(@$words_ref, @utt_bounds);
	my @sorted_words = sort(@$words_ref);
	SailTools::SailComponent::print_into_file(\@sorted_words, $word_list);
	
	my $utterance_delimiters = join(" ", @utt_bounds);
	
	if ($configuration->{mit_raw_format}) {
		$conf_hash{MITRAWFORMAT} = $configuration->{mit_raw_format};
	}
    my $trace_level = $configuration->{log_level};
    my $display_conf_settings =0;
    my $print_arguments = 0;
    if ($trace_level>2) {
        $display_conf_settings =1;
        $print_arguments = 2;
    }
    print_htk_config($configuration_file, \%conf_hash);
    
    my $arguments = " -C $configuration_file -n $source_file -u \'$oov_symbol\' -s $utterance_delimiters -z $word_list $target_file";
    my $error_indicators = run_htk('HBuild',$arguments, $trace_level, $display_conf_settings, $print_arguments, $bin_dir);
    if (@$error_indicators) {
        FATAL("HBuild failed:".join(" ",@$error_indicators));
    }
}

=head2 run_hparse

Low-level HParse wrapper
Usage:
  run_hparse( $grammar_file, $wdnet_file, $configuration)

=cut
sub run_hparse {
	my ($grammar_file, $wdnet_file, $configuration) = @_;
    my $arguments = " $grammar_file $wdnet_file";
    my $trace_level=1;
    my $display_conf_settings = 0;
    my $print_arguments = 0;
    my $bin_dir = $configuration->{bin_path};
    my $error_indicators = run_htk('HParse',$arguments, $trace_level, $display_conf_settings, $print_arguments, $bin_dir);
    if (@$error_indicators) {
        FATAL("HParse failed:".join(" ",@$error_indicators)) && die();
    }	
}

=head2 run_htk

Run an HTK command. Account for HTK-specific errors.
Usage:
  run_htk( $program, $arguments, $trace_level, $display_conf_settings, $print_arguments, $bin_dir);

=cut
sub run_htk {
    my ($program, $arguments, $trace_level, $display_conf_settings, $print_arguments, $bin_dir) = @_;
   
    my $path_to_program = catfile($bin_dir, $program);
    my $command = "$path_to_program -T $trace_level";
    if ($display_conf_settings) {
        $command.=" -D";
    }
    if ($print_arguments) {
        $command.=" -A";
    }
    $command.=" $arguments";

    my $cmd_out = SailTools::SailComponent::run($command);
    my @error_indicators = grep {/Error |USAGE/i} @$cmd_out;

    return \@error_indicators;
}
1;


=head1 AUTHOR

Athanasios Katsamanis, C<< <nkatsam at sipi.usc.edu> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-sailalign at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=SailAlign>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc SailTools::SailHtkWrapper


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

1; # End of SailTools::SailHtkWrapper

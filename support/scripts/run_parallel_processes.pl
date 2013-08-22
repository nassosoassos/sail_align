#!/usr/bin/perl -w 
use Parallel::ForkManager;

my $n_processes=10;
my $pm = new Parallel::ForkManager($n_processes);
my $n_files = 100;
for (my $file_index=0; $file_index<$n_files; $file_index++) {
  my $pid = $pm->start and next;
  my $command = "script.bash $file_index";
  system($command);
  $pm->finish;
}
$pm->wait_all_children;

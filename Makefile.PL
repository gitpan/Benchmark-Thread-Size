require 5.008;
use threads (); # just to force breakage if threads are not available
use ExtUtils::MakeMaker;

my @extra;
if ($^O =~ m#MSWin#) {
    push @extra,'Win32::Process::Info' => 0;
}

WriteMakefile (
 NAME		=> "Benchmark::Thread::Size",
 ($[ >= 5.005) ?
 (AUTHOR	=> 'Elizabeth Mattijsen (liz@dijkmat.nl)',
  ABSTRACT	=> 'report size of threads for different code approaches') : (),
 VERSION_FROM	=> 'lib/Benchmark/Thread/Size.pm',
 PREREQ_PM	=> {
                    @extra,
                   },
);

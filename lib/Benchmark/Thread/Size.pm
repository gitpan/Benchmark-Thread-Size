package Benchmark::Thread::Size;

# Make sure we have version info for this module
# Make sure we do everything by the book from now on

$VERSION = '0.05';
use strict;

# Satisfy -require-

1;

#---------------------------------------------------------------------------
#  IN: 1 class (ignored)
#      2..N parameter hash

sub import {

# Lose the class
# Initialize the parameters hash
# Initialize the number of times setting
# Initialize the reference only flag
# Initialize the key list

    shift;
    my %param;
    my $times = '';
    my $refonly;
    my @key;

# While there are keys to be obtained
#  If it is the times setting
#   Set that
#  Elseif we want the reference only
#   Set reference only flag
#  Else (key + code setting)
#   Associate the code with this key
#   Keep the key for the right order
# Return now unless there is something to do

    while (my $key = shift) {
        if ($key eq 'times') {
            $times = shift;
        } elsif ($key eq 'refonly') {
            $refonly = 1;
        } else {
            $param{$key} = shift;
            push( @key,$key );
        }
    }
    return unless $refonly or keys %param;

# Initialize the test scripts

    _ramthread(); _ramthread1();

# For all of the pieces of code to check
#  Create the file or die
#  Write the code there
#  Close the handle or die

    while (my($file,$code) = each %param) {
        open( my $handle,'>',$file ) or die "Could not write $file: $!\n";
        print $handle $code;
        close( $handle ) or die "Could not close $file: $!\n";
    }

# Execute the test script
# Remove the test scripts from the face of the earth

    system( "$^X -w ramthread $times @key" );
    unlink( qw(ramthread ramthread1),@key );
} #import

#---------------------------------------------------------------------------

# internal subroutines

#---------------------------------------------------------------------------

sub _ramthread {

# Attempt to create the main test script
# Write out the script

    open( my $out,'>','ramthread' ) or die "Could not initialize script: $!\n";
    print $out <<'RAMTHREAD';
# ramthread - test more than one piece of code
# - first parameter (optional): number of repetitions (default: 10)
# - other parameters: filenames with source code to test
#
my $times = ($ARGV[0] || '') =~ m#^(\d+)$# ? shift : 10;

my %code;
my %temp;
$/ = undef;
print STDERR "Performing each test $times times\n" if $times > 1;

foreach my $file ('',@ARGV) {
    if ($file) {
        print STDERR "$file ";
        open( my $code,'<',$file ) or die "Could not read $file: $!\n";
        $code{$file} = <$code>;
        close( $code );             # don't care whether successful
    } else {
        print STDERR "(ref) ";
        $code{$file} = '';
    }

    foreach my $i (1..$times) {
        printf STDERR '%2d',$i;
        open( my $out,"$^X -w ramthread1 $file |" )
         or die "Could not test $file: $!\n";
        push( @{$temp{$file}},<$out> );
        close( $out ) or die "Could not close pipe for $file: $!\n";
        print STDERR "\b\b";
    }
    print STDERR "\n";
}

# normalize results of multiple runs of the same code approach

my %threads;
my %result;
my %deviation;
while (my($file,$list) = each %temp) {
    my %a;
    my %l;
    my %h;
    foreach my $single (@{$list}) {
        foreach (split( "\n",$single )) {
            s#^\s+##;
            my ($t,$ram) = split( m#\s+# );
            $a{$t} += $ram;
            $threads{$t} = 1;
            if (exists( $l{$t} )) {
                $l{$t} = $ram if $ram < $l{$t};
            } else {
                $l{$t} = $ram;
            }
            $h{$t} = $ram if $ram > ($h{$t} || 0);
        }
    }
    $h{$_} = ($h{$_}-$l{$_})/2 foreach keys %h;
    $h{$_} = $h{$_} ? sprintf( ' ±%2d',$h{$_} ) : '   ' foreach keys %h;
    $a{$_} /= $times foreach keys %a;
    $result{$file} = \%a;
    $deviation{$file} = \%h;
}

# print out the result summary

printf( "  #   (ref)%12s%12s%12s%12s%12s\n",@ARGV,'','','','','','' );
foreach my $t (sort {$a <=> $b} keys %threads) {
    printf '%3d',$t;
    my $base = $result{''}->{$t};
    printf '%8d%4s',$base,$deviation{''}->{$t};
    foreach my $file (@ARGV) {
        printf '%+8d%4s',$result{$file}->{$t} - $base,$deviation{$file}->{$t};
    }
    print "\n";
}

print "\n";
my $line = "==================================================================";
foreach (@ARGV) {
    my $header = $line;
    substr( $header,4,length($_)+2 ) = " $_ ";
    print <<EOD;
$header
$code{$_}
EOD
}
print "$line\n";
RAMTHREAD
} #_ramthread

#---------------------------------------------------------------------------

sub _ramthread1 {

# Attempt to create the sub test script
# Write out the script

    open( my $out,'>','ramthread1' ) or die "Could not initialize script: $!\n";
    print $out <<'RAMTHREAD1';
# ramthread1 - test a single piece of code for a varying number of threads.
#
# Source to be checked is specified as filename (empty when missing)
# Output memory sizes to STDOUT so that they can be compared.  Fields are:
#  1 number of threads
#  2 absolute size in Kb (as reported by ps)
#  3 relative size in Kb (size of process with 0 threads substracted)
#  4 size increase per thread in bytes (from the base size)

my %size;

my $code = '';
if (my $file = shift) {
    open( my $in,'<',$file ) or die "Could not read source from $file: $!\n";
    $code = join( '',<$in> );
    close( $in );
}

my $testfile = '_test_ramthread';
foreach my $threads (0,1,2,5,10,20,50,100) {
    printf STDERR '%4d',$threads;
    open( my $script,'>',$testfile ) or die "Could not open $testfile: $!\n";

# create the external script to be executed
    print $script <<EOD;
\$| = 1;               # make sure everything gets sent immediately
print "\$\$\\n";       # make sure parent knows the pid

use threads ();

$code                  # whatever was received from STDIN

for (\$i=0; \$i< $threads ; \$i++) {
  threads->new( sub {print "started\\n"; sleep( 86400 )} );
}
print "done\\n";
<>;                    # make sure it waits until killed
EOD

    close( $script ) or die "Could not close $testfile: $!\n";

    open( my $out,"$^X -w $testfile |" ) or die "Could not run $testfile: $!\n";
    chomp( my $pid = <$out> );
    my $started = 0;
    my $done = 0;
    while (<$out>) {
        $done++ if m#^done#;
        $started++ if m#^started#;
        last if $done and $started == $threads;
    }

# this may need tweaking on non-Linux systems
    my $size = 0;
    while (!$size and kill 0,$pid) {
        open( my $ps,"ps -o rss= -p $pid |" )
         or die "Could not ps -o rss= -p $pid: $!\n";
        while (<$ps>) {
            $size = $1 if m#(\d+)#;
        }
        close( $ps );       # don't care whether successful
    }
    $size{$threads} = $size;

    kill 9,$pid;        # not interested in cleanup, just speed
    close( $out );      # don't care whether successful
    unlink( $testfile );
    print STDERR "\b\b\b\b";
}

# print the report
my $base = $size{0};
my $diff;
foreach my $threads (sort {$a <=> $b} keys %size) {
    printf( "%3d %6d %6d %9d\n",
     $threads,
     $size{$threads},
     $diff = $size{$threads} - $base,
     $threads ? (1024 * $diff) / $threads : 0,
     );
}
RAMTHREAD1
} #_ramthread1

#---------------------------------------------------------------------------

__END__

=head1 NAME

Benchmark::Thread::Size - report size of threads for different code approaches

=head1 SYNOPSIS

  use Benchmark::Thread::Size times => 5, noexport => <<'E1', export => <<'E2';
  use threads::shared ();
  E1
  use threads::shared;
  E2

  use Benchmark::Thread::Size 'refonly'; # do reference run only

=head1 DESCRIPTION

                  *** A note of CAUTION ***

 This module only functions on Perl versions 5.8.0 and later.
 And then only when threads are enabled with -Dusethreads.  It
 is of no use with any version of Perl before 5.8.0 or without
 threads enabled.

                  *************************

The Benchmark::Thread::Size module reports how much memory is used by different
pieces of source code within a threaded application.  This allows you to test
different approaches to coding a specific threaded application or to find ways
how to reduce memory usage of threads in general.

It achieves this goal by running the indicated code with a varying number of
threads and asking the operating system how much memory is in use.  This is
an empirical process that may take quite some time on slower machines.

One or more approaches can be checked at a time, each tested 10 times by
default.  Each approach is compared to an empty piece of code (the reference)
to allow you to easily determine how much memory each different approach has
taken.  Testing is done for 0, 1, 2, 5, 10, 20, 50 and 100 threads.  The code
you specify is only entered once in the main thread and consequently cloned
to all threads when they are created (which is where it becomes B<very>
important to reduce as much as possible.

The final report is sent to STDOUT.  This is an example report:

   #   (ref)        bare        full        vars         our      unique
   0    2172          +0          +0          +0          +0          +0    
   1    2624 ± 4      +4 ± 4      +4 ± 4     +27          +4 ± 4     +27    
   2    3004 ± 4      +2 ± 6      +2 ± 6     +33 ± 4      +8         +36 ± 6
   5    4126 ± 6      -2 ± 6      -3 ± 8     +29 ± 4     +10 ± 2     +27 ± 4
  10    5984 ± 8      -1 ± 8      +0 ± 4      +0 ± 6     +17 ± 4     +43 ± 6
  20    9694 ± 4     +15 ± 4     +15 ± 2     +13 ± 6     +32 ± 6     +58 ± 6
  50   20832 ± 4     +51 ±10     +50 ± 8     +50 ± 8     +68 ±12     +96 ± 6
 100   39392 ± 8    +106 ±10    +156 ±12    +108 ±10    +131 ±10    +155 ±12
 
 ==== bare ========================================================
 $VERSION = '0.01';
 
 ==== full ========================================================
 $main::VERSION = '0.01';
 
 ==== vars ========================================================
 use vars qw($VERSION);
 $VERSION = '0.01';
 
 ==== our =========================================================
 our $VERSION = '0.01';
 
 ==== unique ======================================================
 our $VERSION : unique = '0.01';
 
 ==================================================================

The first column shows the reference amount (the amount of memory used without
adding any specific code).  All other columns show the difference with the
amounts from the first column.

The sizes given are the numbers that were obtained from the system for the
size of the process.  This is usually in Kbytes but could be anything,
depending on how the information about the memory usage is obtained.

Since starting threads can have non-deterministic effects on the amount of
memory used, each number of threads is tried 10 times by default.  The average
of the amount of memory used is shown.  If the amount was not always the same
for the same piece of code and number of threads, a deviation (in the form ±10) is also shown.

So, what does this report tell us?  That it seems that it is better to use a
bare $VERSION in a module in a Perl module that is going to be used with
threads.  And that contrary from what you would like to believe, the ":unique"
attribute does B<not> save any memory: it even causes threads to use B<more>
memory.  And that strangely enough using a fully qualified $module::VERSION
seems to be equivalent to using a bare $VERSION upto 50 threads.  At 100
threads however, the fully qualified $module::VERSION seems to use as much as
with the ":unique" attribute.  Who knows what's going on there.

=head1 PARAMETERS

You can specify the following parameters with the C<use> command.

=head2 times => 5

The word 'times' followed by a numeric value, indicates how many times each
run will be executed.  The default is 10.

=head2 'refonly'

The word 'refonly' indicates that the reference runs will be executed even if
there is no further code specified.  This is important mostly when trying
different approaches to the Perl core modules.

=head2 identifier => 'code'

Any other string followed by Perl code (as a string) indicates a set of runs
to be executed.

=head1 SUBROUTINES

There are no subroutines to call: all values need to be specified with the
C<use> command.

=head1 WHAT IT DOES

This module started life as just a number of scripts.  In order to facilitate
distribution I decided to bundle them together into this module.  So, what
does happen exactly when you execute this module?

=over 2

=item create ramthread

This is the main script that does the testing.  It collects the data that is
written out to STDOUT by ramthread1.

=item create ramthread1

This is the script that gets called for each seperate test.  It creates a
special test-script "_test_ramthread" for each test and each number of threads
to be checked (to avoid artefacts from previous runs in the same interpreter),
then measures the size of memory for each number of threads running
simultaneously and writes out the result to STDOUT.

=item create files for each piece of code

For several (historical) reasons, a seperate file is created for each piece of
code given.  These files are used by ramthread1 to measure the amount of memory
used.  The identification of the code is used as the filename, so be sure that
this will not overwrite stuff you might need later.

The actual code is functionally equivalent to:

 use threads ();
 # your code comes here
 for ($i = 0; $i < (number of threads to test) ; $i++) {
   threads->new( sub {sleep( 86400 )} );
 }

=item run ramthread

The ramthread script is then run with the appropriate parameters.  The output
is sent to STDERR (progress indication) and STDOUT (final report).

=item remove all files that were created

Then all of the files (including the ramthread and ramthread1 script) are
removed, so that no files are left behind.

=back

All files are created in the current directory.  This may not be the best
place, but it was the easiest thing to code.

=head1 HOW TO MEASURE SIZE?

Currently the size of the process is measured by doing a:

  ps -o rss= -p $pid

However, this may not be as portable as I would like.  If you would like to
use Benchmark::Thread::Size on your system and the above doesn't work, please
send me a string for your system that writes out the size of the given process
to STDOUT and the condition that should be used to determine that that string
should be used instead of the above default.

=head1 AUTHOR

Elizabeth Mattijsen, <liz@dijkmat.nl>.

Please report bugs to <perlbugs@dijkmat.nl>.

=head1 ACKNOWLEDGEMENTS

James FitzGibbon for pointing out a more portable "ps" string and the fact
that "ps" on Mac OS X has a bug in it.

=head1 COPYRIGHT

Copyright (c) 2002-2003 Elizabeth Mattijsen <liz@dijkmat.nl>. All rights
reserved.  This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Benchmark>.

=cut

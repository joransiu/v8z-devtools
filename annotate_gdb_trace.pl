#!/usr/bin/perl
use strict;
use warnings;

# Script to annotate a v8 gdb trace log with the location of the
# stubs/builtins + offset.
#  Generate a v8 trace with:
#     d8 --print_code_stubs --print_all_code > print_stubs.txt
#  Run this script:
#     annotate_gdb_trace.pl print_stubs.txt gdb.txt [init_counter] > stubs.txt  2> trace.txt
#  Currently, STDOUT prints stubs output, STDERR prints annotated trace.


my $input_file = $ARGV[0];
open (my $trace_file, "<", $input_file)  || die "Can't open $input_file: $!\n";
my $gdb_file = $ARGV[1];
open (my $gdb_trace_file, "<", $gdb_file)  || die "Can't open $gdb_file: $!\n";

my %stub_hash = ();
my %function_hash = ();
my $stub_name = '';
my $invoke_count = 1;

my $counter = 1;
if ($#ARGV == 2) {
  $counter = $ARGV[2];
}
while (my $line = readline($trace_file)) {
  # Found STUB/BUILTIN name
  if ($line =~ m/^name = (\w+)/) { 
    $stub_name = $1;
    # We may compile stubs multiple times, so increment counter
    # and track them.
    if (defined $function_hash{$stub_name}) {
      chomp($line);
      my $orig_stub_name = $stub_name;
      $line .= "_".$function_hash{$orig_stub_name}."\n";
      $stub_name .= "_".$function_hash{$orig_stub_name};
      $function_hash{$orig_stub_name}++;
    } else {
      $function_hash{$stub_name} = 2;
    }
  } elsif ($line =~ m/^0x([0-9a-f]+) +([0-9]+) +/) {
    $stub_hash{$1} = "<$stub_name+$2>";
  }
}

while (my $line = readline($gdb_trace_file)) {
  if ($line =~ m/^[=> ]+0x([a-f0-9]+):(.*)$/) {
    if (defined $stub_hash{$1}) {
      # Print INVOKE line if it's JSEntryStub+0
      my $address = $1;
      my $instruction = $2;
      # Convert tabs to spaces
      $instruction =~ s/\t/ /;
      my $stub_info = $stub_hash{$address};
      if ($stub_info =~ m/JSEntryStub\+0/) {
         print "\n===========> INVOKE:$invoke_count\n";
         $invoke_count++;
      } elsif ($stub_info =~ m/JSConstructEntryStub\+0/) {
         print "\n===========> INVOKE:$invoke_count (is_construct)\n";
         $invoke_count++;
      } 
      chomp($line);
      printf  ("%05d %s %-40s %s\n",$counter, $address, $instruction, $stub_hash{$address});

      if ($instruction =~ m/basr\s+%r14,%r7/) {
         print "Call to host function\n";
         if ($stub_info =~ m/CEntryStub\+/) {
         # Calls to Runtime routines has an extra counter bump in simulator
           $counter++;
         }
      }
    }
    $counter++;
  }
}

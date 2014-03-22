#!/usr/bin/perl
use strict;
use warnings;

# Script to annotate a v8 simulator trace log with the location of the
# stubs/builtins + offset.
#  Generate a v8 trace with:
#     d8 --trace_sim --print_code_stubs --print_all_code > sim_trace.txt
#  Run this script:
#     annotate_sim_trace.pl sim_trace.txt > stubs.txt  2> trace.txt
#  Currently, STDOUT prints stubs output, STDERR prints annotated trace.


my $input_file = $ARGV[0];
open (my $trace_file, "<", $input_file)  || die "Can't open $input_file: $!\n";

my %stub_hash = ();
my %function_hash = ();
my $stub_name = '';
my $invoke_count = 1;
while (my $line = readline($trace_file)) {
  my $print_line = 1;
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
  } elsif ($line =~ m/^([0-9]+) +([a-f0-9]+) +/) {
    if (defined $stub_hash{$2}) {
      # Print INVOKE line if it's JSEntryStub+0
      my $address = $2;
      my $stub_info = $stub_hash{$address};
      if ($stub_info =~ m/JSEntryStub\+0/) {
         print STDERR "\n===========> INVOKE:$invoke_count\n";
         $invoke_count++;
      } elsif ($stub_info =~ m/JSConstructEntryStub\+0/) {
         print STDERR "\n===========> INVOKE:$invoke_count (is_construct)\n";
         $invoke_count++;
      }
      chomp($line);
      printf STDERR ("%-60s %s\n",$line, $stub_hash{$address});
      $print_line = 0;
    }
    elsif ($line =~ m/ call rt redirected/) {
      # For redirected calls, we want to also print the next 3 lines
      # for function, args and return values.
      print STDERR $line;
      $print_line = 0;
    }
  } elsif ($line =~ m/Call to host function/) {
      # This is a native call, we want to have it in the trace.
      print STDERR $line;
      $print_line = 0;
  } elsif ($line =~ m/^\s+args /) {
      # This is arguments for a native call, we want to ahve it in trace
      print STDERR $line;
      $print_line = 0;
  } elsif ($line =~ m/^Returned /) {
      # This is return argument for a native call.
      print STDERR $line;
      $print_line = 0;
  }
  if ($print_line) {
    print $line;
  }
}

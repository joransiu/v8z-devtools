#!/usr/bin/perl
use strict;
use warnings;
use bignum;

# Script to annotate a v8 simulator trace log with the location of the
# stubs/builtins + offset.
#  Generate a v8 trace with:
#     d8 --trace_sim --print_all_code > sim_trace.txt
#  Run this script:
#     annotate_sim_trace.pl sim_trace.txt > stubs.txt  2> trace.txt
#  Currently, STDOUT prints stubs output, STDERR prints annotated trace.


my $input_file = $ARGV[0];
open (my $trace_file, "<", $input_file)  || die "Can't open $input_file: $!\n";

my %stub_hash = ();
my %function_hash = ();
my $stub_name = '';
my $invoke_count = 1;
my $call_output = 0;
my $unrecognized_function = 0;
my $optimized_function = 0;
my $optimization_id = 0;
my $last_JSEntryAddress = 0;
my $invoke_depth = 0;
my $kind = '';

while (my $line = readline($trace_file)) {
  my $print_line = 1;
  # Found STUB/BUILTIN name
  if ($line =~ m/^name = (.+)/) {
    $stub_name = $1;
    $stub_name =~ s/[^\w\d]/_/g;
    if ($kind =~ m/REGEXP/) {
      $stub_name = $kind . $stub_name;
    }
    # We may compile stubs multiple times, so increment counter
    # and track them.
    if ($optimized_function == 1) {
      $stub_name .= "_OPTID_$optimization_id";
      $optimized_function = 0;
    }
    if (defined $function_hash{$stub_name}) {
      chomp($line);
      my $orig_stub_name = $stub_name;
      $line .= "_".$function_hash{$orig_stub_name}."\n";
      $stub_name .= "_".$function_hash{$orig_stub_name};
      $function_hash{$orig_stub_name}++;
    } else {
      $function_hash{$stub_name} = 2;
    }
    $unrecognized_function = 0;
  } elsif ($line =~ m/^optimization_id = (\d+)/) {
    $optimized_function = 1;
    $optimization_id = $1;
  } elsif ($line =~ m/^kind = .*FUNCTION/) {
    $kind = $1;
    $unrecognized_function = 1;
    $stub_name = "unnamed_function";
  } elsif ($line =~ m/^kind = (.+)/) {
    $kind = $1;
    print ("KIND = $kind\n");
  } elsif ($line =~ m/^0x([0-9a-fA-F]+) +([0-9]+) +/ or
           $line =~ m/^([0-9a-fA-F]+) +([0-9]+) +/) {
    if ($unrecognized_function == 1) {
      if (defined $function_hash{$stub_name}) {
        my $orig_stub_name = $stub_name;
        $line .= "_".$function_hash{$orig_stub_name}."\n";
        $stub_name .= "_".$function_hash{$orig_stub_name};
        $function_hash{$orig_stub_name}++;
      } else {
        $function_hash{$stub_name} = 2;
      }
      $unrecognized_function = 0;
    }
    my $address = Math::BigInt->new('0x'. $1);
    $stub_hash{$address} = "<$stub_name+$2>";
     if ($stub_name =~ m/JSEntryStub/) {
       $last_JSEntryAddress = $address;
     }
  } elsif ($line =~ m/^([0-9]+) +([a-f0-9]+) +/) {
    my $address = Math::BigInt->new('0x'. $2);
    if (defined $stub_hash{$address}) {
# Print INVOKE line if it's JSEntryStub+0
      my $stub_info = $stub_hash{$address};
      my $offset = "$^O" eq "os390" ? 16 : 0;
      if ($stub_info =~ m/JSEntryStub\+$offset>/) {
        print STDERR "\n===========> INVOKE:$invoke_count (depth: $invoke_depth)\n";
        $invoke_count++;
        $invoke_depth++;
      } elsif ($stub_info =~ m/JSConstructEntryStub\+$offset>/) {
        print STDERR "\n===========> INVOKE:$invoke_count (is_construct) (depth: $invoke_depth)\n";
        $invoke_count++;
        $invoke_depth++;
      }
      chomp($line);
      my $tabs = "";
      for (my $i = 1; $i < $invoke_depth; $i++) {
        $tabs .= "  ";
      }
      printf STDERR ("%s%2s: %-60s %s\n",$tabs, $invoke_depth - 1, $line, $stub_hash{$address});
      $print_line = 0;
      if ($address eq $last_JSEntryAddress) {
        $invoke_depth--;
        print STDERR "<========== JSEntryStub Return (depth: $invoke_depth)\n\n";
      }
    } else {
      # Still print the line out even if we don't find mapping, as snapshot
      # may be on or we didn't print stubs properly yet.
      chomp($line);
      my $tabs = "";
      for (my $i = 1; $i < $invoke_depth; $i++) {
        $tabs .= "  ";
      }
      printf STDERR ("%s%2s: %-60s\n",$tabs, $invoke_depth - 1, $line);
      $print_line = 0;
    }
  } elsif ($line =~ m/ call rt redirected/) {
    # For redirected calls, we want to also print the next 3 lines
    # for function, args and return values.
    print STDERR $line;
    $print_line = 0;
  } elsif ($line =~ m/Call to host function/) {
    # This is a native call, we want to have it in the trace.
    print STDERR $line;
    $print_line = 0;
    $call_output = 1;
  } elsif ($line =~ m/^\s+args /) {
    if ($call_output) {
      # This is arguments for a native call, we want to ahve it in trace
      print STDERR $line;
      $print_line = 0;
    }
  } elsif ($line =~ m/^Returned /) {
    if ($call_output) {
      # This is return argument for a native call.
      print STDERR $line;
      $print_line = 0;
      $call_output = 0;
    }
  } elsif ($line =~ m/^\s+\d+:\s+/) {
    if ($call_output) {
      # This is the name of the called function
      print STDERR $line;
      $print_line = 0;
    }
  }
  if ($print_line) {
    print $line;
  }
}

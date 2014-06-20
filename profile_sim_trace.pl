#!/usr/bin/perl
use strict;
use warnings;

# Script to annotate a v8 simulator trace log with the location of the
# stubs/builtins + offset.
#  Generate a v8 trace with:
#     d8 --trace_sim --print_all_code --code_comments > sim_trace.txt
#  Run this script:
#     profile_sim_trace.pl sim_trace.txt > profile.txt 
#  Currently, STDOUT prints stubs output


my $input_file = $ARGV[0];
open (my $trace_file, "<", $input_file)  || die "Can't open $input_file: $!\n";

my %stub_hash = ();
my %function_hash = ();
my $stub_name = '';
my $invoke_count = 1;
my $call_output = 0;
my $unrecognized_function = 0;
my $last_JSEntryAddress = 0;
my $invoke_depth = 0;
# Hash Tables to keep track of method count, and instruction count.
my %method_counts = ();
my %instruction_counts = ();
my $total_instructions = 0;

# Cycle through log
while (my $line = readline($trace_file)) {
  # Found STUB/BUILTIN name
  if ($line =~ m/^name = ([\w.]+)/) { 
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
    $unrecognized_function = 0;
  } elsif ($line =~ m/^kind = .*FUNCTION/) {
    $unrecognized_function = 1;
    $stub_name = "unnamed_function";
  } elsif ($line =~ m/^0x([0-9a-f]+) +([0-9]+) +/) {
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
    $stub_hash{$1} = "$stub_name";
  } elsif ($line =~ m/^([0-9]+) +([a-f0-9]+) +/) {
    # Bump up instruction count on this address.
    $instruction_counts{$2}++;

    if (defined $stub_hash{$2}) {
      $method_counts{$stub_hash{$2}}++;
    } else {
      $method_counts{"unknown - not mapped"}++;
    }
    $total_instructions++;
  }
}

close ($trace_file);

# Print sorted
print "Total Instructions found: $total_instructions\n";

# Method hotness
print "Method/Stub Hotness\n";
print "-------------------\n";
my @hot_methods = sort { $method_counts{$a} <=> $method_counts{$b} } 
                  keys(%method_counts);
# Sort in descending order
@hot_methods = reverse(@hot_methods);

foreach my $method (@hot_methods) {
  my $count = $method_counts{$method};
  my $percentage = $count / $total_instructions * 100;
  my $output = sprintf("%02.2f%% %10.d", $percentage, $count);

  print "$output   $method\n";
}

print "\n\n-------------------\n";
print "Method Logs\n";
print "-------------------\n";

# Print out the logs
%stub_hash = ();
%function_hash = ();
open ($trace_file, "<", $input_file)  || die "Can't open $input_file: $!\n";

# Cycle through log
while (my $line = readline($trace_file)) {
  my $print_line = 1;
  # Found STUB/BUILTIN name
  if ($line =~ m/^name = ([\w.]+)/) {
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
    $unrecognized_function = 0;
    if (defined $method_counts{$stub_name}) {
      my $count = $method_counts{$stub_name};
      my $percentage = $count / $total_instructions * 100;
      $line = sprintf("%02.2f%% %10.d $line", $percentage, $count);
    }
  } elsif ($line =~ m/^kind = .*FUNCTION/) {
    $unrecognized_function = 1;
    $stub_name = "unnamed_function";
  } elsif ($line =~ m/^0x([0-9a-f]+) +([0-9]+) +/) {
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
      if (defined $method_counts{$stub_name}) {
        my $count = $method_counts{$stub_name};
        my $percentage = $count / $total_instructions * 100;
        my $special_line = sprintf("%02.2f%% %10.d name = $stub_name", $percentage, $count);
        print "$special_line\n";
      }
    }
    $stub_hash{$1} = "$stub_name";
    if (defined $instruction_counts{$1}) {
       if (defined $method_counts{$stub_name}) {
         my $percentage = $instruction_counts{$1} / $method_counts{$stub_name} * 100;
         $line = sprintf("[%02.2f%% %10.d] $line", $percentage, $instruction_counts{$1});
       } else {
         $line = sprintf("[--.--%% %10.d] $line", $instruction_counts{$1});
       }
    } else {
       $line = sprintf("[ 0.00%% %10.d] $line",0);
    }
  } elsif ($line =~ m/^([0-9]+) +([a-f0-9]+) +/) {
    $print_line = 0;
  } elsif ($line =~ m/ call rt redirected/) {
    $print_line = 0;
  } elsif ($line =~ m/Call to host function/) {
    # This is a native call, we want to have it in the trace.
    $print_line = 0;
    $call_output = 1;
  } elsif ($line =~ m/^\s+args /) {
    if ($call_output) {
      # This is arguments for a native call, we want to ahve it in trace
      $print_line = 0;
    }
  } elsif ($line =~ m/^Returned /) {
    if ($call_output) {
      # This is return argument for a native call.
      $print_line = 0;
      $call_output = 0;
    }
  }

  if ($print_line) {
    print "$line";
  }
}


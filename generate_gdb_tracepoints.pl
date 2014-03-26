#!/usr/bin/perl
use strict;
use warnings;

# Script to generate GDB tracepoints for all stub functions
#  Generate a v8 output trace with:
#     d8 --print_code_stubs --print_all_code > stub_output.txt
#  Run this script:
#     generate_gdb_tracepoints.pl stub_output.txt

my $input_file = $ARGV[0];
open (my $trace_file, "<", $input_file)  || die "Can't open $input_file: $!\n";

my %function_hash = ();
my %forward_reloc_hash = ();
my $stub_name = '';
my $invoke_count = 1;
my $current_break_addr;
my $current_break_count = 0;
my $break_on_next = 0;
my $issue_break_point = 0;

while (my $line = readline($trace_file)) {
  my $print_line = 1;
  # Found STUB/BUILTIN name
  if ($line =~ m/^name = (\w+)/) { 
    # New Stub - Force issue of previous one.
    if (defined $current_break_addr) {
      $issue_break_point = 1;
    }

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
  } elsif ($line =~ m/^0x([0-9a-f]+) +([0-9]+) +([0-9a-f]+) +([a-z]+.*)/) {
    my $address = $1;
    my $offset = $2;
    my $mnemonic = $4;
    if ($offset == 0 || $break_on_next != 0 || defined $forward_reloc_hash{$address}) {
      # Forward relocation scenario, we need to generate print for prior sequence
      if ($break_on_next == 0 && defined $forward_reloc_hash{$address}) {
        print ("break *0x$current_break_addr\ncommands\nx/".$current_break_count."i \$pc\ncont\nend\n");
      }
      $current_break_addr = $address;
      $current_break_count = 0;
      $break_on_next = 0;
    } elsif ($mnemonic =~ m/^brc[lt]?.*,\*\+[0-9]+ .*\(0x([0-9a-f]+)\)/) {
      # Forward relative branch.
      $forward_reloc_hash{$1} = 1;
      $break_on_next = 1;
      $issue_break_point = 1;
    } elsif ($mnemonic =~ m/^brc[lt]?.*,\*\-[0-9]+ .*\(0x([0-9a-f]+)\)/) {
      # Backwards relative branch.
      $break_on_next = 1;
      $issue_break_point = 1;
    } elsif ($mnemonic =~ m/^b/) {
      # Branch instruction
      $break_on_next = 1;
      $issue_break_point = 1;
    }
    $current_break_count++;
  }

  if ($issue_break_point != 0) {
    print ("break *0x$current_break_addr\ncommands\nx/".$current_break_count."i \$pc\ncont\nend\n");
    $issue_break_point = 0;
  }
}

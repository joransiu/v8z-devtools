#!/usr/bin/perl
use strict;
use warnings;

# Script to determine which stub/builtin a given address is in.
#  Generate a v8 output trace with:
#     d8 --print_code_stubs --print_all_code > stub_output.txt
#  Run this script:
#     which_stub_from_addr.pl 0xaddr stub_output.txt

my $addr = $ARGV[0];
# Trim any leading 0x chars
$addr =~ s/^0x//;

# Trim leading zeros.
$addr =~ s/^[0]+//;

my $input_file = $ARGV[1];
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
  }
}

if (defined $stub_hash{$addr}) {
  print "0x$addr - $stub_hash{$addr}\n";
  exit 0;
} else {
  print STDERR "Address 0x$addr not found.\n";
  exit 1;
}


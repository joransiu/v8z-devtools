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
my %break_addr_hash = ();
my @function_listing = ();
my $stub_name = '';
my $invoke_count = 1;
my $current_break_addr;
my $current_break_count = 0;
my $break_on_next = 0;
my $CEntryStub_branch_point = 0;
my $issue_break_point = 0;

my $num_break_points = 1; # Start with one for brentry
sub printBreakPoint{
  $num_break_points++;
  
  my($addr, $num_instr, @commands) = @_;
  print "break *0x$current_break_addr\n";
  print "commands\n";
  foreach (@commands) {
    print "$_\n";
  }
  print "x/".$num_instr."i \$pc\n";
  print "cont\n";
  print "end\n";
}

while (my $line = readline($trace_file)) {
  my $print_line = 1;
  # Found STUB/BUILTIN name
  if ($line =~ m/^name = (\w+)/) { 
    $stub_name = $1;

    # New Stub - Force issue of previous one.
    if (defined $current_break_addr) {
      $issue_break_point = 1;
    }
    # Reset our function trace and hashes.
    @function_listing = ();
    %break_addr_hash = ();

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
    
    unshift @function_listing, $address;
    if (($offset == 0) ||
        ($break_on_next != 0) ||
        (defined $forward_reloc_hash{$address})) {
      # Forward relocation scenario, we need to generate print
      # for prior sequence
      if ($break_on_next == 0 && defined $forward_reloc_hash{$address}) {
        #print ("break *0x$current_break_addr\ncommands\nx/".$current_break_count."i \$pc\ncont\nend\n");
        my @commands;
       
        if ($CEntryStub_branch_point == 1) {
          push @commands,'disable br',"br *$address";
          $CEntryStub_branch_point++;
        } elsif ($CEntryStub_branch_point == 2) {
          push @commands,'enable br';
          $CEntryStub_branch_point = 0;
        }
        printBreakPoint($current_break_addr, $current_break_count, @commands);
      }
      $current_break_addr = $address;
      $current_break_count = 0;
      $break_on_next = 0;
      $break_addr_hash{$address} = 1;
    } elsif ($mnemonic =~ m/^b/) {
      # Branch instruction
      $break_on_next = 1;
      $issue_break_point = 1;

      
      # Handle relative branches
      if ($mnemonic =~ m/^brc[lt]?.*,\*\+[0-9]+ .*\(0x([0-9a-f]+)\)/) {
        # Forward relative branch.
        $forward_reloc_hash{$1} = 1;
      } elsif ($mnemonic =~ m/^brc[lt]?.*,\*\-[0-9]+ .*\(0x([0-9a-f]+)\)/) {
        # Backwards relative branch.
        my $branch_target = $1;

        # If target is already a breakpoint, we're done
        if (!defined $break_addr_hash{$branch_target}) {
          my $last_break_addr;
          my $num_instr = 0;
          # Iterate through our list of addresses
          foreach(@function_listing) {
            my $cur_address = $_;
            if (defined $break_addr_hash{$cur_address}) {
              $last_break_addr = $cur_address;
            $num_instr = 0;
            } elsif ($cur_address eq $branch_target) {
              # We have not emitted a break point from branch target
              if (!defined $last_break_addr) {
#                print ("break *0x$current_break_addr\ncommands\nx/".($current_break_count-$num_instr)."i \$pc\ncont\nend\n");
                printBreakPoint($current_break_addr, ($current_break_count - $num_instr));
                $current_break_addr = $branch_target;
                $current_break_count = $num_instr;
              } else {
                print ("break *0x$branch_target\ncommands\nx/".$num_instr."i \$pc\ncont\nend\n");
                printBreakPoint($branch_target, $num_instr);
              }
              $break_addr_hash{$branch_target} = 1;
              last;
            }
            $num_instr++;
          }
        }
      } elsif ($mnemonic =~ m/^basr\s+r14,r7/) {
        # Special handling of breakpoints for CEntryStub
        if ($stub_name =~ m/CEntryStub/) {
          $CEntryStub_branch_point = 1;
        }
      }
    }
    $current_break_count++;
  }

  if ($issue_break_point != 0) {
    print ("break *0x$current_break_addr\ncommands\nx/".$current_break_count."i \$pc\ncont\nend\n");
    printBreakPoint($current_break_addr, $current_break_count);
    $issue_break_point = 0;
  }
}

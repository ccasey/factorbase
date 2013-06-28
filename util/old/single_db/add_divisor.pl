#!/usr/bin/perl

require "factorbase.pm";

if($#ARGV != 1) {
  print("Usage: $0 <num_id> <factor>\n");
  exit;
}

printf("Adding divisor of $ARGV[0]: $ARGV[1]\n");

&open_database();
add_divisor($ARGV[0], $ARGV[1], "MANUAL",  undef, undef, undef);

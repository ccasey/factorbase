#!/usr/bin/perl

require "factorbase.pm";

if($#ARGV != 2) {
  print("Usage: $0 <db> <num_id> <factor>\n");
  print $#ARGV . "\n";
  exit;
}

$DB = $ARGV[0];

 
printf("Adding to $ARGV[0] divisor of $ARGV[1]: $ARGV[2]\n");

&open_database();

$DATABASE_H = $DB_HANDLES{$DB}{DATABASE_H};

add_divisor($ARGV[1], $ARGV[2], "MANUAL",  undef, undef, undef);

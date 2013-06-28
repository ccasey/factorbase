#!/usr/bin/perl

require "factorbase.pm";

if($#ARGV != 0) {
  print("Usage: $0 <db>\n");
  exit;
}

 $DB = $ARGV[0];
 print "adding to database $DB\n";


&open_database();

$DATABASE_H = $DB_HANDLES{$DB}{DATABASE_H};

while(chomp($foo = <STDIN>)) {
  &add_number(split(/\s+/, $foo), UNSAFE);
}

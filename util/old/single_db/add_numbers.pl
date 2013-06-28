#!/usr/bin/perl

require "factorbase.pm";

$DATABASE_NAME = "FBTest";

&open_database();

while(<>) {
  &add_number(split(/\s+/, $_), UNSAFE);
}

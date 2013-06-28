#!/usr/bin/perl

require "factorbase.pm";

if(!$ARGV[0]) {
  print("Usage: $0 <db>\n");
  print #$ARGV . "\n";
  exit;
}

$DB = $ARGV[0];

 print "checking database $DB\n";
 




&open_database();

$DATABASE_H = $DB_HANDLES{$DB}{DATABASE_H};

my $number_sth;		# Statement handle on the number table
my $number_ref;		# Reference handle on the number table


# Check the factorization of a given num_id and number
sub check_factors() {
  my ($num_id, $number) = (@_);

  my $factor_sth;		# Statement handle on the factor table
  my $factor_ref;		# Reference handle on the factor table
  my @factors;			# List of factors of number
  
  $factor_sth = $DATABASE_H->prepare("select * from factor where num_id=\"$num_id\"");
  $factor_sth->execute();
  while($factor_ref = $factor_sth->fetchrow_hashref()) {
    @factors = (@factors, $factor_ref->{'factor'} . "^" . $factor_ref->{'power'});
    if(&calc_status($factor_ref->{'factor'}) ne $factor_ref->{'status'}) {
      print("ERROR: Factor " . $factor_ref->{'factor'} .
            " of $num_id marked as " .  $factor_ref->{'status'} . 
            ", tested as " . &calc_status($factor_ref->{'factor'}) . "\n");
    }
  }
  $factor_sth->finish();
  if(&calc("$number / (" . join('*', @factors) . ")") ne "1") {
    print("ERROR: Factorization of $num_id incorrect: " . join('*', @factors) . "\n");
  }
}

$number_sth = $DATABASE_H->prepare("select * from number");
$number_sth->execute();
while($number_ref = $number_sth->fetchrow_hashref()) {
  if(($number_ref->{'status'} eq "COMPOSITE") ||
     ($number_ref->{'status'} eq "COMPLETE") ||
     ($number_ref->{'status'} eq "PARTIAL")) {
    &check_factors($number_ref->{'num_id'}, $number_ref->{'number'});
  } elsif ($number_ref->{'status'} eq "PRIME") {
    if(&calc_status($number_ref->{'number'}) ne "PRIME") {
      print("ERROR: " . $number_ref->{'num_id'} .
            " incorrectly marked as prime\n");
    }
  } elsif ($number_ref->{'status'} eq "TRIVIAL") {
    if(($number_ref->{'number'} ne "1") && ($number_ref->{'number'} ne "0")) {
      print("ERROR: " . $number_ref->{'num_id'} .
            " incorrectly marked as trivial\n");
    }
  } else {
    print("ERROR: " . $number_ref->{'num_id'} . " has unknown status " . $number_ref->{'status'} . "\n");
  }
}
$number_sth->finish();

&close_database();
exit;

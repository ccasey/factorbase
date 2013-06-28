#!/usr/bin/perl

# This script stamps the current date on all numbers scheduled
# for "slow" ECM (>50k).  The point is to get started again on all "fast"
# ECM trials.  ECM work is handed out oldest first.

require "factorbase.pm";

&open_database();
$DATABASE_H = $DB_HANDLES{FactorBase}{DATABASE_H};

$factor_sth;               # Statement handle on the factor table
$factor_ref;               # Reference handle on the factor table
$count = 0;

$factor_sth = $DATABASE_H->prepare("select factor.* from factor,ecm where factor.status='COMPOSITE' and factor.method='ECM' and ecm.status='ACTIVE' and ecm.b1>50000 and ecm.num_id = factor.num_id");
$factor_sth->execute();

while($factor_ref = $factor_sth->fetchrow_hashref()) {
  $string="update low_priority factor set date=now() where num_id=\"$factor_ref->{'num_id'}\" and status='COMPOSITE' and method='ECM' and factor=\"$factor_ref->{'factor'}\"";
  $DATABASE_H->do($string);
  $count++;
}

$factor_sth->finish();
&close_database();
print("$count rows updated.\n");

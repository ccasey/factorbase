#!/usr/bin/perl

require "factorbase.pm";
$| = 1;

# Paths to the factoring binaries
$BASIC="./basic";
$GP="/usr/local/bin/gp";
$ECM="./ecm";

$ECM_MAX_CURVES=100;

# Who I am
my $who = "Andy";

# The methods available to me
my @methods_available = ("BASIC", "MPQS", "ECM");
#my @methods_available = ("MPQS");

# The built-up work array
my @work_out = ();
my @work_in = ();

# Appends the work log with the results of a trial factorization attempt
# Call like factor_basic(num_id, n);
sub factor_basic() {
  my ($num_id, $n) = @_;
  my $factor_count = 0;
  my $method;
  my $factor;

  open(FACTOR_H, "$BASIC $n|");
  while(<FACTOR_H>) {
    chomp($_);
    # Grab one factor at a time and shove it into the work_out array
    ($method, $factor, $notes) = split(/\s+/, $_, 3);
    @work_out = (@work_out, "REPORT_FACTOR", $num_id, $factor, $method, $notes);
    print("Factor of $num_id found by $method: $factor\n");
    $factor_count++;
  }
  close(FACTOR_H);

  # If we didn't find any factors, return the work done.
  # The undef is for "no notes"
  if($factor_count == 0) {
    @work_out = (@work_out, "REPORT_WORK", $num_id, $n, "BASIC", undef);
  }
}


sub factor_mpqs() {
  my ($num_id, $n) = @_;
  my $factor_count = 0;
  my $factor;
  my $power;

  open(FACTOR_H, "echo \'factorint($n, 14)\' | $GP 2>&1|");
  while(<FACTOR_H>) {
    chomp($_);
    if ($_ =~ /\[(\d+)\s+(\d+)\]/) {
      $factor = $1;
      for($power=$2; $power > 0; $power--) {
        @work_out = (@work_out, "REPORT_FACTOR", $num_id, $factor, "MPQS", undef);
        print("Factor of $num_id found by MPQS: $factor\n");
        $factor_count++;
      }
    }
  }
  close(FACTOR_H);

  if($factor_count == 0) {
    @work_out = (@work_out, "REPORT_WORK", $num_id, $n, "MPQS", undef);
  }
}

sub factor_ecm() {
  my ($num_id, $n, $notes) = @_;

  my $sigma;
  my $step;
  my $factor;

  my $b1;
  my $max_curves;
  my $curve_count;

  if($notes =~ /B1=(\d+)/i) {
    $b1 = $1;
  } else {
    printf("ECM paramaters malformed: $notes\n");
    return();
  }

  if($notes =~ /CURVES=(\d+)/i) {
    $max_curves = $1;
  } else {
    printf("ECM paramaters malformed: $notes\n");
    return();
  }

  if ($max_curves > $ECM_MAX_CURVES) {
    $max_curves = $ECM_MAX_CURVES;
  }

  for($curve_count = 1; $curve_count <= $max_curves; $curve_count++) {
    $sigma = undef;
    $step = undef;
    $factor = undef;

    open(FACTOR_H, "echo $n | $ECM $b1|");
    while(<FACTOR_H>) {
      chomp($_);
      if ($_ =~ /sigma=(\d+)/i) {
        $sigma = $1;
      } elsif ($_ =~ /factor found in step (\d+):\s*(\d+)/i) {
        $step = $1;
        $factor = $2;
      }
    }
    close(FACTOR_H);
    printf("Completed $curve_count curves on $num_id\n");
    if($factor) {
      last();
    }
  }

  # If no factor, the "for" loop incremented the curve count
  if(!$factor) {
    $curve_count--;
  }

  # For proper bookkeeping, we should report curves completed before
  # factors found.
  @work_out = (@work_out, "REPORT_WORK", $num_id, $n, "ECM", "B1=$b1 CURVES=$curve_count");

  if($factor) {
    @work_out = (@work_out, "REPORT_FACTOR", $num_id, $factor, "ECM", "B1=$b1 SIGMA=$sigma STEP=$step");
    print("Factor of $num_id found by ECM: $factor\n");
  }
}


sub do_work() {
  while(@work_in) {
    my $num_id = shift(@work_in);
    my $n = shift(@work_in);
    my $method = shift(@work_in);
    my $notes = shift(@work_in);

    if("$method" eq "BASIC") {
      printf("Doing BASIC test on $num_id: $n\n");
      &factor_basic($num_id, $n, $notes);
    } elsif ("$method" eq "ECM") {
      printf("Doing ECM on $num_id: $n ($notes)\n");
      &factor_ecm($num_id, $n, $notes);
    } elsif ("$method" eq "MPQS") {
      printf("Doing MPQS on $num_id: $n\n");
      &factor_mpqs($num_id, $n, $notes);
    } else {
      printf("Unknown method $method for $num_id = $n\n");
    }
  }
}


sub return_work() {
  printf("Returning " . (($#work_out + 1)/5) . " items to server...\n");
  while(@work_out) {
    my $report_type = shift(@work_out);
    my $num_id = shift(@work_out);
    my $n = shift(@work_out);
    my $method = shift(@work_out);
    my $notes = shift(@work_out);
  
    if("$report_type" eq "REPORT_WORK") {
      process_work($num_id, $n, $method, $notes);
    } elsif ("$report_type" eq "REPORT_FACTOR") {
      add_divisor($num_id, $n, $method, undef, $who, $notes);
    }
  }
}

&open_database();

while(1) {
  printf("Getting work from server...\n");
  @work_in = getwork($who, @methods_available);

  if (! @work_in) {
    printf("No work to do.  Exiting.\n");
    exit(0);
  }

  print("Received " . (($#work_in + 1)/4) . " items from server.\n");
  do_work();
  return_work();
}

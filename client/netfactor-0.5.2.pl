#!/usr/bin/perl

# Mar 2 2002 - Chris - changed code to resolve punt now that it has a dynamic IP.


use Config;
use Socket;

$| = 1;

# Version and things
$VERSION = .5;
$HOSTNAME = `uname -n | awk -F. '{print $1}'`;
chomp($HOSTNAME);
$WORK_FILE = "${HOSTNAME}.work.$$";

# network info
#$SERVER = "punt.frogstar.net";
$SERVER = "localhost";
$PORT = 9999;
$SLEEP_TIME = 180;
 
# Paths to the factoring binaries
$BASIC="./basic";
$GP="/usr/local/bin/gp";
$ECM="/usr/local/bin/ecm";

# Who I am
my $WHO = "chris";

# The methods available to me
#my @METHODS_AVAILABLE = ("BASIC", "MPQS", "ECM");
my @METHODS_AVAILABLE = ("ECM");

# The project I want to front on
my $PROJECT = "FactorBase";

# How long to keep our head in the sand doing ecm
srand();
# 4 hours + a random number of seconds up to 60.
$ECM_CHECKIN_FREQ=int(rand(60)) + 14400;

# The built-up work array
my @WORK_OUT = ();
my @WORK_IN = ();
my $WORK_PROGRESS;

# A hash for statistics
my %FACTOR_COUNT;

my $START_TIME = time();

# All methods should call this function to record things to be reported
sub register_report() {
  my $report_line = shift(@_);

  @WORK_OUT = (@WORK_OUT, $report_line);
  &to_disk($report_line);
}


# All methods that find a factor should call this function, so all reporting is
# handled the same.
# Also does a register_report for the factor.
sub register_factor() {
  my ($num_id, $factor, $method, $notes) = @_;
  my $pretty_factor;

  $FACTOR_COUNT{$method}++;

  if(length($factor) > 10) {
    $pretty_factor = length($factor) . "d";
  } else {
    $pretty_factor = $factor;
  }

  &logit("$method found factor of $num_id: $pretty_factor");
  &register_report("REPORT_FACTOR $num_id $factor $method $notes");
}

##########

# Appends the work log with the results of a trial factorization attempt
# Call like factor_basic(num_id, n);
sub factor_basic() {
  my ($num_id, $n) = @_;
  my ($method, $factor, $notes);

  open(FACTOR_H, "nice -19 $BASIC $n|");
  while(<FACTOR_H>) {
    # Grab one factor at a time and register it
    chomp($_);
    ($method, $factor, $notes) = split(/\s+/, $_, 3);
    &register_factor($num_id, $factor, $method, $notes);
  }
  close(FACTOR_H);

  if($factor eq undef) {
    &register_report("REPORT_WORK $num_id $n BASIC");
  }
}

##########

sub factor_mpqs() {
  my ($num_id, $n) = @_;
  my ($factor, $power, $factor_count);

  $WORK_PROGRESS="REPORT_WORK $num_id $n MPQS ABORTED";

  open(FACTOR_H, "echo \'factorint($n, 14)\' | nice -19 $GP 2>&1|");
  while(<FACTOR_H>) {
    chomp($_);
    if ($_ =~ /\[(\d+)\s+(\d+)\]/) {
      $factor = $1;
      for($power=$2; $power > 0; $power--) {
        &register_factor($num_id, $factor, "MPQS", undef);
      }
    }
  }
  close(FACTOR_H);

  # This shouldn't happen, but oh well
  if($factor eq undef) {
    &register_report("REPORT_WORK $num_id $n MPQS");
  }

  $WORK_PROGRESS=undef;
}

##########

sub factor_ecm() {
  my ($num_id, $n, $notes) = @_;
  my ($b1, $max_curves);
  my ($sigma, $step, $factor);
  my ($curve_count, $start_time, $elapsed);

  if($notes =~ /B1=(\d+)/i) {
    $b1 = $1;
  } else {
    &logit("ECM paramaters malformed: $notes");
    return();
  }

  if($notes =~ /CURVES=(\d+)/i) {
    $max_curves = $1;
  } else {
    &logit("ECM paramaters malformed: $notes");
    return();
  }
  
  # gonna use this as a beginning time to do all the curve
  # averages, every time it reports its an overall average
  $start_time = time();
  
  $WORK_PROGRESS = "REPORT_WORK $num_id $n ECM B1=$b1 CURVES=0";

  # main for loop for N curves
  for($curve_count = 1; $curve_count <= $max_curves;$curve_count++) {
    $sigma = undef;
    $step = undef;
    $factor = undef;

    open(FACTOR_H, "echo $n | nice -19 $ECM $b1|");
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

    $elapsed = time() - $start_time; 
    $WORK_PROGRESS = "REPORT_WORK $num_id $n ECM B1=$b1 CURVES=$curve_count";

    # make things look nice.. i suppose
    print ".";
    if((($curve_count % 50) == 0) || $factor || ($curve_count == $max_curves)
      || ($elapsed >= $ECM_CHECKIN_FREQ)) {
      printf(" %d @ %0.2f sec/curve\n" ,$curve_count, $elapsed/$curve_count);
    }
    
    # check see if we are ready to get out of the loop
    # before maxcurves 
    if($factor || ($elapsed >= $ECM_CHECKIN_FREQ)) {
      last;
    }
  } # end of curve loop

  # For proper bookkeeping, we should report curves completed before
  # factors found.
  &register_report($WORK_PROGRESS);
  $WORK_PROGRESS = undef;
  
  if($factor) {
    &register_factor($num_id, $factor, "ECM", "B1=$b1 SIGMA=$sigma STEP=$step");
  }
}

##########

sub do_work() {
  my $work_line;
  my ($num_id, $n, $method, $notes);
  my ($num_length, $message);

  while(@WORK_IN) {
    $work_line = shift(@WORK_IN);
    
    ($num_id, $n, $method, $notes) = split(' ', $work_line, 4);
    
    $num_length = length($n);
    $message = "$method on ${num_id}.c${num_length}";
    if($notes && ($method eq "ECM")) {
      $message .= ": $notes";
    }
    &logit("$message");

    if("$method" eq "BASIC") {
      &factor_basic($num_id, $n, $notes);
    } elsif ("$method" eq "ECM") {
      &factor_ecm($num_id, $n, $notes);
    } elsif ("$method" eq "MPQS") {
      &factor_mpqs($num_id, $n, $notes);
    } else {
      &logit("Unknown method $method!");
    }
  }
}

##########

sub return_work() {
  my $method;
  my $message = undef;
  my $work_line;
  
  # if we got nothing, then why bother?
  if(@WORK_OUT){
    &logit("Returning " . ($#WORK_OUT+1) . " items to server...");
    &con();
    print S "REPORT $WHO $PROJECT\n";
    while($work_line = shift(@WORK_OUT)) {
      print S "$work_line\n";
    }
    print S "DONE\n";
    &discon();
  }else {
    &logit("No work to turn in.");
  }
  &flush_work_out();
}

##########

sub goget(){
  my $methods;

  $methods = join(' ', @METHODS_AVAILABLE);

  &logit("Requesting new work...");
  &con();
  print S "REQUEST $WHO:$MACHINE:$PROJECT $methods\n";
  
  # listen to our work list
  
  while($work = <S>){
    chop($work);
    if($work eq "DONE"){
      last;
    }
    @WORK_IN = (@WORK_IN, $work);
  }
  &discon();
}

##########

sub discon{
 print S "BYE\n";
 close(S);
}

##########

sub con{
  my ($iaddr, $paddr, $proto);
 
  $iaddr = gethostbyname($SERVER);
  $paddr = sockaddr_in($PORT,$iaddr);
  $proto = getprotobyname('tcp');
 
if (socket(S,AF_INET, SOCK_STREAM, $proto)) {
      ($DEBUG) ? &logit("Socket creation succeeded.\n"):undef;
  }

 unless (connect (S, $paddr)){
  &logit("connect failed: $!");
  &logit("sleeping for $SLEEP_TIME...");
  sleep($SLEEP_TIME);
  con();
  return;
 } else {
  ($DEBUG) ? &logit("connect success\n"):undef;
 }


  select(S);
  $| = 1;
  select(STDOUT);
 
  @gotten = (split /:/, <S>);
  chomp(@gotten);
  # Hmm. Skip this for now till the connect/disconn stuff is cleaner
  # &logit("Server MOTD: " . @gotten[2]);

  if($gotten[0] > $VERSION){
    &logit("---");
    &logit("Update your damn client to something over $gotten[0], we are $VERSION");
    &logit("---");
    close(S);
    exit();
  }
}

##########

sub logit{
  my $logln = shift(@_);
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time());

  printf("[%02d/%02d/%04d %02d:%02d] $HOSTNAME: $logln\n",
   ($mon+1), $mday, (1900+$year), $hour, $min);
}

##########

sub to_disk{
  open (F, ">>$WORK_FILE");
  print F shift(@_) . "\n";
  close(F);
} 

##########

sub from_disk (){
  my @work_files;
  my $work_file;

  opendir(RADDIR, ".") or die "cant open dir: $!";
  @work_files = grep { /^${HOSTNAME}\.work\./ && -f "$_" } readdir(RADDIR);
  closedir RADDIR;

  foreach $work_file (@work_files) {
    # Don't suck in the current one.
    if($work_file eq $WORK_FILE) {
      next();
    }

    &logit("Reading work file ${work_file}...");
    open(W, "$work_file");
    while(<W>) {
      chomp($_);
      &register_report($_);
    }
    close(W);
    unlink($work_file);
  }
}

##########


sub flush_work_out(){
 unlink($WORK_FILE);
 @WORK_OUT = ();
}


##########

sub benchmark_ecm{

  $n = "7648989424484460137597549098798619849366147950925984062858968862860589";
  $b1 = 250000;
  $sigma = 12345;
  $length = length($n);
  
  
  &logit("Running ecm with B1 250k on a c$length sigma 12345");
 
  $start = time();
    open(FACTOR_H, "echo $n | nice -19 $ECM $b1 $sigma|");
    while(<FACTOR_H>) {
      chomp($_);
      if ($_ =~ /Step/) {
        &logit("$_");
      }
    }
    close(FACTOR_H);
   $end = time();
   
   $overall = $end - $start;
   
   &logit("$overall sec overall crude time");
}

##########
# "main type thing"
##########

my ($i, $name);

  if (! defined($Config{sig_name})) {
    die("Could not configure signals.\n");
  }
  $i = 0;
  foreach $name (split(' ',$Config{sig_name})) {
    $signo{$name} = $i;
    $signame[$i] = $name;
    $i++;
  }

###

$SIG{INT} = sub { 
  if(@ARGV[0] eq "-b"){
   exit();
  }

  &logit("");
  &logit("SIGINT... going the hell away...");
  &logit("");
  my $elapsed = (time() - $START_TIME) / 60;
  &logit("ground for $elapsed minutes");
  &logit("");

  # If there's any work in progress (like a few ECM curves done), enter
  # it into the work done array
  if($WORK_PROGRESS) {
    &register_report($WORK_PROGRESS);
    $WORK_PROGRESS = undef;
  }
  
  # Now return work if there is any
  &return_work();

  &logit("out");
  exit();
};

###

if(@ARGV[0] eq "-b"){
  &logit("benchmarking");
  &benchmark_ecm();
  exit();
}
 

# If any old work files exist, suck them in
&from_disk();

if(@WORK_OUT) {
  &logit("Returning old work from work files.");
  &return_work();
}


while(1) {
  &goget();
  my $method;

  if (!@WORK_IN) {
    &logit("No work to do.  Nap time...");
    sleep(240);
    next();
  }

  &logit("Received " . ($#WORK_IN + 1) . " items from server.");
  &do_work();
  &return_work();

  # Some handy stats.
  $message = "";
  foreach $method (sort(keys(%FACTOR_COUNT))) {
    $message .= "${method}:$FACTOR_COUNT{$method} ";
  }
  &logit("Stats $message");
}

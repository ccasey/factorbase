#!/usr/bin/perl

# netfactor.pl
use Config;
use Socket;
#require "factornet.pm";
#require "factorbase.pm";
$| = 1;

# Version and things
$VERSION = .2;
$WORK_FILE = $machine.".work.".$$;

# network info
$SERVER = "208.167.68.254";
$PORT = 9998;
$SLEEP_TIME = 10;
 
# Paths to the factoring binaries
$BASIC="./basic";
$GP="/usr/local/bin/gp";
$ECM="./ecm";

# Who I am
my $machine = `uname -n`;
chomp($machine);
my $who = "Chris";
#$who = $who . ":" . $machine;

# The methods available to me
my @methods_available = ("BASIC", "MPQS", "ECM");
#my @methods_available = ("ECM");
#my @methods_available = ("BASIC");

# The built-up work array
my @work_out = ();
my @work_in = ();

##########

# Appends the work log with the results of a trial factorization attempt
# Call like factor_basic(num_id, n);
sub factor_basic() {
  my ($num_id, $n) = @_;
  my $factor_count = 0;
  my $method;
  my $factor;

  open(FACTOR_H, "nice -19 $BASIC $n|");
  while(<FACTOR_H>) {
    chomp($_);
    # Grab one factor at a time and shove it into the work_out array
    ($method, $factor, $notes) = split(/\s+/, $_, 3);
    @work_out = (@work_out, "REPORT_FACTOR", $num_id, $factor, $method, $notes);
    &to_disk("REPORT_FACTOR $num_id $factor $method $notes");
    &logit("Factor of $num_id found by $method: $factor\n");
    $factor_count++;
  }
  close(FACTOR_H);

  # If we didn't find any factors, return the work done.
  # The undef is for "no notes"
  if($factor_count == 0) {
    @work_out = (@work_out, "REPORT_WORK", $num_id, $n, "BASIC", undef);
    
    # we really dont wanna do this... fuck it
    #&to_disk("REPORT_WORK $num_id $n BASIC undef");
  }
}

##########

sub factor_mpqs() {
  my ($num_id, $n) = @_;
  my $factor_count = 0;
  my $factor;
  my $power;

  open(FACTOR_H, "echo \'factorint($n, 14)\' | nice -19 $GP 2>&1|");
  while(<FACTOR_H>) {
    chomp($_);
    if ($_ =~ /\[(\d+)\s+(\d+)\]/) {
      $factor = $1;
      for($power=$2; $power > 0; $power--) {
        @work_out = (@work_out, "REPORT_FACTOR", $num_id, $factor, "MPQS", undef);
	&to_disk("REPORT_FACTOR $num_id $factor MPQS undef");
        &logit("Factor of $num_id found by MPQS: $factor\n");
        $factor_count++;
      }
    }
  }
  close(FACTOR_H);

  if($factor_count == 0) {
    @work_out = (@work_out, "REPORT_WORK", $num_id, $n, "MPQS", undef);
    &to_disk("REPORT_WORK $num_id $n MPQS undef");
  }
}

##########

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
    &logit("ECM paramaters malformed: $notes\n");
    return();
  }

  if($notes =~ /CURVES=(\d+)/i) {
    $max_curves = $1;
  } else {
    &logit("ECM paramaters malformed: $notes\n");
    return();
  }
  
  # how much is 20% of nothing?
  my $curve_run = 1;
  my $curve_fifth = $max_curves / 5;
   &logit("curve fifth is $curve_fifth\n");
  
  for($curve_count = 1; $curve_count <= $max_curves; $curve_count++) {
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

    # well, we dont like you that much
    if($curve_run++ >= $curve_fifth){
     &logit("$curve_count curves of $max_curves done\n");
     $curve_run = 1;

    }

  # keep track of where we are incase we die in the middle 
   $ecm_progress = "REPORT_WORK $num_id $n ECM B1=$b1 CURVES=$curve_count";
    
    if($factor) {
      last;
    }
  }

  # If no factor, the "for" loop incremented the curve count
  if(!$factor) {
    $curve_count--;
  }

  # For proper bookkeeping, we should report curves completed before
  # factors found.
  @work_out = (@work_out, "REPORT_WORK", $num_id, $n, "ECM", "B1=$b1 CURVES=$curve_count");
  $ecm_progress = NULL;
 
 &to_disk("REPORT_WORK $num_id $n ECM B1=$b1 CURVES=$curve_count");
  
  if($factor) {
    @work_out = (@work_out, "REPORT_FACTOR", $num_id, $factor, "ECM", "B1=$b1 SIGMA=$sigma STEP=$step");
    &to_disk("REPORT_FACTOR $num_id $factor ECM B1=$b1 SIGMA=$sigma STEP=$step");
    &logit("Factor of $num_id found by ECM: $factor\n");
  }
}

##########

sub do_work() {
  while(@work_in) {
  #&to_disk(join ' ',@_ . "\n");
  &logit(">> " . $machine . "\n");
    my $num_id = shift(@work_in);
    my $n = shift(@work_in);
    my $method = shift(@work_in);
    my $notes = shift(@work_in);
    &to_disk("$num_id $n $method $notes \n");

    if("$method" eq "BASIC") {
      &logit("Doing BASIC test on $num_id\n");
      &factor_basic($num_id, $n, $notes);
    } elsif ("$method" eq "ECM") {
      &logit("Doing ECM on $num_id: ($notes)\n");
      &factor_ecm($num_id, $n, $notes);
    } elsif ("$method" eq "MPQS") {
      &logit("Doing MPQS on $num_id\n");
      &factor_mpqs($num_id, $n, $notes);
    } else {
      &logit("Unknown method $method for $num_id = $n\n");
    }
  }
}

##########

sub return_work() {
  my $stuff_done_count = (($#work_out + 1)/5);
  
  # if we got nothing, then why bother?
  if(($stuff_done_count) || ($ecm_progress)){
   &con();
   print S "REPORT $who\n";
   if($stuff_done_count){
    &logit("Returning " . $stuff_done_count . " items to server...\n");
    while(@work_out) {
      my $report_type = shift(@work_out);
      my $num_id = shift(@work_out);
      my $n = shift(@work_out);
      my $method = shift(@work_out);
      my $notes = shift(@work_out);
      
      print S "$report_type $num_id $n $method $notes\n";
    }
   }else {
    &logit("No real work to turn in...\n");
   }

   if($ecm_progress){
    &logit("Turning in ecm work in progress...\n");
    print S "$ecm_progress \n";
   }else{
    &logit("No ecm work in progreass... \n");
   }
  
   @work_out = ();
   &logit("Cleaning work files...\n");
   &clean_disk();
  } else {
   &logit("Nothing to report to the server...\n");
  }
  
  
  print S "DONE\n";
  close(S);
}

##########

sub goget(){
  my $who = shift(@_);
  my @methods = @_;
  my $method;
  my @todo = ();

  $method = shift(@methods);
  for(@methods){
   $method = join ' ', $method, $_;
  }

  print S "REQUEST $who:$machine $method\n";
  
  # listen to our work list
  
  while($work = <S>){
   chop($work);
   if($work eq "DONE"){
    last;
   }
   my($num_id, $n, $method, $notes) = split / /, $work, 4;
   #print "- $num_id - $n - $method - $notes - \n";
    @todo = (@todo, $num_id, $n, $method, $notes);
   
  }
  close(S);
  return(@todo); 
  
}

##########

sub con{

 my ($iaddr, $paddr, $proto);
 
 $iaddr = inet_aton($SERVER);
 $paddr = sockaddr_in($PORT,$iaddr);
 $proto = getprotobyname('tcp');
 
 if (socket(S,AF_INET, SOCK_STREAM, $proto)) {
      ($DEBUG) ? &logit("Socket creation succeeded.\n"):undef;
  }

 unless (connect (S, $paddr)){
  &logit("connect failed: $!\n");
  &logit("sleeping for $SLEEP_TIME...\n");
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
  &logit("Server MOTD: " . @gotten[2] . "\n");
  if($gotten[0] > $VERSION){
   &logit("---\n");
   &logit("Update your damn client to something over $gotten[0], we are $VERSION\n");
   &logit("---\n");
   close(S);
   exit();
  }
}

##########

sub logit{
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time());
 my $logln = shift(@_);
# open CLOG, ">>$clientlogf";
#  print CLOG $logln;
# close(CLOG);
 print "[$mon/$wday/" . (1900+$year) . "-$hour:$min] " . $logln;
 
}

##########

sub to_disk{

 open (F, ">>$WORK_FILE");
  print F shift(@_) . "\n";
 close(F);

} 

##########

sub from_disk{

 my($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks);
 chomp($work_dir = `pwd`);
 opendir RADDIR, $work_dir or die "cant open dir: $!";
  @dirs = grep !/^\.\.?$/, readdir RADDIR;
 closedir RADDIR;
 &logit("looking for old work files...\n");
 foreach $d (@dirs){
  if($d =~ /.work./){
   @foo = stat $d;
   print $foo[3] . "\n";
  }
 }
}

##########

sub clean_disk{

 unlink $WORK_FILE;
 
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
 &logit("\n");
 &logit("\n");
 &logit("SIGINT... going the hell away... \n");
 &logit("\n");
 &logit("\n");
 sleep(1);
 &return_work();
 &logit("out\n\n");
 sleep(1);
 exit();
};

###

while(1) {
  
  #&from_disk();
  &logit("----------Getting work from server... $SERVER $PORT\n");
  &con();
  @work_in = ();
  @work_in = &goget($who, @methods_available);

  if (! @work_in) {
    &logit("No work to do.  Nap time... \n");
    sleep(240);
    next();
  }

  &logit("Received " . (($#work_in + 1)/4) . " items from server.\n");
  
  do_work();

  return_work();
}

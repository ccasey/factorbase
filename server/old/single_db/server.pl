#!/usr/bin/perl

# server.pl

use Socket;
#require "factornet.pm";
require "factorbase.pm";
###
  
 $PORT = 9998;
 $VERSION = .1; #	Mar-21-2000 server version
 $CCV = .2;	#	Mar-21-2000 current client version
 $CDIRECT = 0;	#	Mar-21-2000 server directive
 $MOTD	= "And the wine list please.";
 
 $DEBUG = 1;
 
 my @work_out = ();
 my @work_in = ();
 my $work_cnt = 0;
 my $fac_cnt = 0;
 
###

&make_socket();
&open_database();

# all talking to clients is within this for
for( ; $paddr = accept(C,S); close C){
 
  select(C);
  $| = 1;
  select(STDOUT);
  
  my ($foo,$bar) = sockaddr_in($paddr);
  my $caller = gethostbyaddr($bar,AF_INET);
  
  &logit("Connection from: $caller\n");
  
  # send the welcome message to client
  print C "$CCV:$CDIRECT:$MOTD\n";
  
  # get what client wants to do:
  # REPORT # 		- reporting # lines of work back to us
  # REQUEST # <type> 	- request # numbers for <type> testing
  # 			  (# and <type> are optional)
  # FACTOR
  
  
  $in = <C>;
  chop($in);
  
  if($in =~ /^REQUEST/){
   &logit("processing $in\n");
   
   my ($cruft, $who, @methods) = split /\s+/, $in;
   ($who, $machine) = split /:/, $who;
   ($DEBUG) ? &logit("$who requested work for $machine for methods: $methods[0] $methods[1] $methods[2]\n"):undef;
   
   # fix this mess later... this is stupid
   my @wrk = getwork($who, @methods);
   $num_wrk = @wrk;
   for(my $num = 0; $num < ($num_wrk/4); $num++){
    my $num_id = shift(@wrk);
    my $n = shift(@wrk);
    my $method = shift(@wrk);
    my $notes = shift(@wrk);
    unless($notes){
     $notes = "NULL";
    }
     
#    print "$num_id $n $method $notes\n";
    print C "$num_id $n $method $notes\n";
   }
   
   print C "DONE\n";
   &logit("done\n");
  }
  
  if($in =~ /^REPORT/){
   my ($cruft,$who) = split / /, $in;
   &logit("processing REPORT from $who\n");
   $cnt=0;
   @done = ();
   while($in = <C>){
    chomp($in);
    if($in =~ /^DONE/){
     last;
    }
    $cnt++;
    @done = (@done, $in);
   }
   &logit("processing $cnt items $#done\n");
   $work_cnt = 0;
   $fac_cnt = 0;
   foreach(@done){
    ($report_type,$num_id,$n,$method,$notes) = split / /, $_, 5;
    if($report_type eq "REPORT_WORK"){
      &process_work($num_id, $n, $method, $notes);
      $work_cnt++;
    }
    if($report_type eq "REPORT_FACTOR"){
     &add_divisor($num_id, $n, $method, undef, $who, $notes);
     $fac_cnt++;
    }
   }
   &logit("processed $work_cnt work, and $fac_cnt factors\n");
  }   
 
  &logit("Closing connection from: $caller\n----------\n");
  close(C);
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
sub make_socket{

 my ($proto, $paddr);
 
 $proto = getprotobyname('tcp');
 
 socket(S, PF_INET, SOCK_STREAM, $proto)
  || &logit("socket fail: $!\n");
  
 setsockopt(S, SOL_SOCKET, SO_REUSEADDR, pack("l", 1)) 
  || &logit("setsockopt fail: $!\n");

 bind(S, sockaddr_in($PORT, INADDR_ANY))
  || &logit("bind fail: $!\n");
  
 listen(S, 5)
  || &logit("listen fail: $!\n"); 

}

exit();

# Changelog:

# Mar-21-2000: "MOTD" Milestone Complete. - chriss

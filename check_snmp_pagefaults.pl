#!/usr/bin/perl -w 

############################## check_snmp_pagefaults.pl #################
my $Version='1.00';
# Date : Dec 15 2010
# Author  : Javier Vela ( jvdiago@dagorlad.es )
# Website : http://www.dagorlad.es/ |
# Licence : GPL - http://www.fsf.org/licenses/gpl.txt
# Checks memory page faults.
####################################################################
#
# Help : ./check_snmp_pagefaults.pl -h
#
##
use strict;
use Net::SNMP;
use POSIX;
use Getopt::Long;

use lib "/usr/local/argos/aplicaciones/nagios/libexec/";
use utils qw($TIMEOUT %ERRORS);


my $memoryPageFaults = "1.3.6.1.4.1.9600.1.2.46.12.0";
my $memoryPageIn = "1.3.6.1.4.1.9600.1.2.46.15.0";
my $memoryPageOut = "1.3.6.1.4.1.9600.1.2.46.16.0";
my $memoryPages = "1.3.6.1.4.1.9600.1.2.46.17.0";

my $returnstring = "";
my $perfdata = "| ";

my $host = 	undef;
my $community = undef;
my $warning = undef;
my @o_warnL = undef;
my $critical = undef;
my @o_critL = undef;
my $help = undef;
my $exit_val = undef;


Getopt::Long::Configure ("bundling");
GetOptions(
	'h' => \$help,
	'help' => \$help,
	'H:s' => \$host,
	'host:s' => \$host,
	'w:s' => \$warning,
	'warning:s' => \$warning,
	'c:s' => \$critical,
	'critical:s' => \$critical,
	'C:s' => \$community,
	'community:s' => \$community
);

sub nonum
{
  my $num = shift;
  if ( $num =~ /^(\d+\.?\d*)|(^\.\d+)$/ ) { return 0 ;}
  return 1;
}
sub print_usage
{
    print "Usage: $0 -H <Host> -C <COMMUNITY-STRING> -w <W1>,<W2>,<W3>,<W4> -c <C1>,<C2>,<C3>,<C4>\n";
}

# CHECKS
if ( defined($help) )
{
	print_usage();
	exit $ERRORS{"UNKNOWN"};
}
if ( !defined($host) )
{
	print "Need Host-Address!\n";
	print_usage();
	exit $ERRORS{"UNKNOWN"};
}
if ( !defined($warning) )
{
	print "Need warning value!\n";
	print_usage();
	exit $ERRORS{"UNKNOWN"};
}
if ( !defined($critical) )
{
	print "Need critical value!\n";
	print_usage();
	exit $ERRORS{"UNKNOWN"};
}
if ( !defined($community) )
{
	print "Need Community-String!\n";
	print_usage();
	exit $ERRORS{"UNKNOWN"};
}

@o_warnL=split(/,/ , $warning);
@o_critL=split(/,/ , $critical);

if (($#o_warnL != 3) || ($#o_critL != 3)){ 
	print "4 warnings and critical !\n";
	print_usage(); 
	exit $ERRORS{"UNKNOWN"}
}

for (my $i=0;$i<4;$i++) {
	if ( nonum($o_warnL[$i]) || nonum($o_critL[$i])){ 
		print "Numeric value for warning or critical !\n";
		print_usage(); 
		exit $ERRORS{"UNKNOWN"}
	}
        if ($o_warnL[$i] > $o_critL[$i]){ 
		print "warning <= critical ! \n";
		print_usage(); 
		exit $ERRORS{"UNKNOWN"}
	}
}


my ($session, $error) = Net::SNMP->session( -hostname  => $host, -version   => 2, -community => $community, -timeout   => $TIMEOUT);

if (!defined($session)) {
   printf("ERROR opening session: %s.\n", $error);
   exit $ERRORS{"CRITICAL"};
}

my @oidlists = ($memoryPageFaults,$memoryPageIn,$memoryPageOut,$memoryPages);
my $resultat = $session->get_request(-varbindlist => \@oidlists);

my @page = undef;
my @desc = qw(PageFaults MemoryIn MemoryOut Pages);

$page[0]=$$resultat{$memoryPageFaults};
$page[1]=$$resultat{$memoryPageIn};
$page[2]=$$resultat{$memoryPageOut};
$page[3]=$$resultat{$memoryPages};

for(my $j=0;$j<4;$j++){
    if (nonum($page[$j])){
	print "Wrong Value Returned: ".$page[$j]."\n";
	exit $ERRORS{"UNKNOWN"};
    }
}

$exit_val=$ERRORS{"OK"};
for (my $i=0;$i<4;$i++) {
  if ( $page[$i] > $o_critL[$i] ) {
   $exit_val=$ERRORS{"CRITICAL"};
  }
  if ( $page[$i] > $o_warnL[$i] ) {
     # output warn error only if no critical was found
     if ($exit_val eq $ERRORS{"OK"}) {
       $exit_val=$ERRORS{"WARNING"};
     }
  }
  $returnstring = $returnstring.$desc[$i].":".$page[$i]." ";
  $perfdata = $perfdata.$desc[$i]."=".$page[$i].";".$o_warnL[$i].";".$o_critL[$i]." ";
}

print $returnstring.$perfdata."\n";
exit $exit_val;

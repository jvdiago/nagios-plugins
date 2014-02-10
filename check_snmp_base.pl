#!/usr/bin/perl -w 

############################## check_snmp_base.pl #################
my $Version='1.00';
# Date : Nov 15 2010
# Author  : Javier Vela ( jvdiago@dagorlad.es )
# Website : http://www.dagorlad.es/ |
# Licence : GPL - http://www.fsf.org/licenses/gpl.txt
# Checks that the SNMP community works.
#####################################################################
#
# Help : ./check_snmp_base.pl -h
#
##

use strict;
use Net::SNMP;
use POSIX;
use Getopt::Long;

use lib "/usr/lib64/nagios/plugins/";
use utils qw($TIMEOUT %ERRORS);

my $TIMEOUT = 5;

my $oid = "1.3.6.1.2.1.1.1.0";

my $returnvalue = $ERRORS{"OK"};
my $returnstring = "";

my $host =      undef;
my $community = undef;
my $help = undef;
my $frequency = undef;

Getopt::Long::Configure ("bundling");
GetOptions(
        'h' => \$help,
        'help' => \$help,
        'H:s' => \$host,
        'host:s' => \$host,
        'C:s' => \$community,
        'community:s' => \$community,
        'f:s' => \$frequency
);

sub nonum
{
  my $num = shift;
  if ( $num =~ /^(\d+\.?\d*)|(^\.\d+)$/ ) { return 0 ;}
  return 1;
}
sub print_usage
{
    print "Usage: $0 -H <Host> -C <COMMUNITY-STRING> [-f <FRECUENCIA>]\n";
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
if ( !defined($community) )
{
        print "Need Community-String!\n";
        print_usage();
	exit $ERRORS{"UNKNOWN"};
}

my ($session, $error) = Net::SNMP->session( -hostname  => $host, -version   => 2, -community => $community, -timeout   => $TIMEOUT);

if (!defined($session)) {
   printf("ERROR opening session: %s.\n", $error);
   exit $ERRORS{"CRITICAL"};
}

my @oidlists = ($oid);
my $resultat = $session->get_request(-varbindlist => \@oidlists);

my $descr = $$resultat{$oid};

if ( !$descr )
{
        print "No data returned from ".$host;
        exit $ERRORS{"CRITICAL"};
}
else {
        print $descr."\n";
        exit $ERRORS{"OK"};
}


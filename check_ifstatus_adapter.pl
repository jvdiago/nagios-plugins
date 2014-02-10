#!/usr/bin/perl -w 

############################## check_ifstatus_adapter.pl #################
my $Version='1.00';
# Date : Nov 25 2010
# Author  : Javier Vela ( jvdiago@dagorlad.es )
# Website : http://www.dagorlad.es/ | 
# Licence : GPL - http://www.fsf.org/licenses/gpl.txt
# Based on the check_ifstatus by Christoph Kron 
# Checks if an adapter (by name) is UP.
##################################################################
##
## Help : ./check_ifstatus_adapter.pl -h
##

use strict;
use Net::SNMP;
use POSIX;
use Getopt::Long;

use lib "/usr/lib64/nagios/plugins/";
use utils qw($TIMEOUT %ERRORS);


my $ifDescr = '1.3.6.1.2.1.2.2.1.2';
my $ifAdminStatus = '1.3.6.1.2.1.2.2.1.7';
my $ifOperStatus = '1.3.6.1.2.1.2.2.1.8';

my %ifOperStatusTable =      ('1','up',
                         '2','down',
			 '3','testing',
	                 '4','unknown',	
			 '5','dormant',
			 '6','notPresent',
			 '7','lowerLayerDown');  # down due to the state of lower layer interface(s));


my $returnvalue = $ERRORS{"OK"};
my $returnstring = "";

my $host = 	undef;
my $community = undef;
my $help = undef;
my $adapter = undef;

Getopt::Long::Configure ("bundling");
GetOptions(
	'h' => \$help,
	'help' => \$help,
	'H:s' => \$host,
	'host:s' => \$host,
	'C:s' => \$community,
	'community:s' => \$community,
	'a:s' => \$adapter,
	'adapter:s' => \$adapter
);

sub nonum
{
  my $num = shift;
  if ( $num =~ /^(\d+\.?\d*)|(^\.\d+)$/ ) { return 0 ;}
  return 1;
}
sub print_usage
{
    print "Usage: $0 -H <Host> -C <COMMUNITY-STRING> -a <Adapter>\n";
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
if ( !defined($adapter) )
{
	print "Need Adapter!\n";
	print_usage();
	exit $ERRORS{"UNKNOWN"};
}


my ($session, $error) = Net::SNMP->session( -hostname  => $host, -version   => 2, -community => $community, -timeout   => $TIMEOUT);

if (!defined($session)) {
   printf("ERROR opening session: %s.\n", $error);
   exit $ERRORS{"CRITICAL"};
}

my @oidlists = undef;
my $resultat_request = undef;

my $resultat = $session->get_table($ifDescr);

if (!defined($resultat)){
   printf("ERROR opening session.\n");
   exit $ERRORS{"CRITICAL"};
}

my $return = $ERRORS{"OK"};
my $return_string = "";
my $adapter_name;
my $interface_id;

foreach my $key ( keys %$resultat) {
	undef @oidlists;
	undef $adapter_name;
	undef $interface_id;

	my @key_adapter = split("1.3.6.1.2.1.2.2.1.2.",$key);
        my $interface_id =  $key_adapter[1];
        my $adapter_name = $$resultat{$key};

	if($adapter_name eq $adapter)
	{
		if ( ! isdigit $interface_id )
		{
			print "Wrong interface ID value returned";
			exit $ERRORS{"UNKNOWN"};
		}
		else {
			my $adminStatus = $ifAdminStatus.'.'.$interface_id;
			my $operStatus = $ifOperStatus.'.'.$interface_id;

			undef @oidlists;
			undef $resultat_request;

			my @oidlists = ($adminStatus,$operStatus);
			my $resultat_request = $session->get_request(-varbindlist => \@oidlists);

			if ($$resultat_request{$operStatus} == '2'){
     				if($$resultat_request{$adminStatus} != '1')
     				{
          				$return_string = $adapter_name." is administratively DOWN. AdminStatus: ".$ifOperStatusTable{$$resultat_request{$adminStatus}}."\n";
					$return = $ERRORS{"OK"};
     				}else{
          				$return_string = $adapter_name." is DOWN. OperStatus: ".$ifOperStatusTable{$$resultat_request{$operStatus}}."\n";
					$return = $ERRORS{"CRITICAL"};
     				}
			}
			elsif ($$resultat_request{$operStatus} == '3'){
     				$return_string =  $adapter_name." is TESTING\n";
				if ($return eq $ERRORS{"OK"}){
					$return = $ERRORS{"WARNING"};
				}
			}elsif ($$resultat_request{$operStatus} == '4'){
     				$return_string =  $adapter_name." is UNKNOWN\n";
				if ($return eq $ERRORS{"OK"}){
					$return = $ERRORS{"UNKNOWN"};
				}
			}else{
     				$return_string = $adapter_name." is UP\n";
			}	
		}
		print $return_string;
		exit $return;
	}	
}

print "No Interface found witn name ".$adapter;
exit $ERRORS{"CRITICAL"};

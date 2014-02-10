#!/usr/bin/perl

############################## check_ndoutils.pl #################
my $Version='1.00';
# Date : Nov 15 2011
# Author  : Javier Vela ( jvdiago@dagorlad.es )
# Website : http://www.dagorlad.es/ |
# Licence : GPL - http://www.fsf.org/licenses/gpl.txt
# Checks the last update on a NDOUtils database.
#####################################################################
#
# Help : ./check_ndoutils.pl -h
#
##

use strict;
use POSIX;
use DBI;
use Config::Simple;
use DateTime::Format::Strptime;
use Getopt::Long;

use lib "/usr/lib64/nagios/plugins/";
use utils qw($TIMEOUT %ERRORS);
########## CONFIG ##############
my $NDO_CFG="/etc/nagios/ndo2db.cfg";
my $LOCALE = 'es_ES';
my $TIME_ZONE =  'Europe/Madrid';
########### FIN CONFIG ##########

our $NDO_USER;
our $NDO_PASS;
our $NDO_DB;
our $NDO_IP;
our $NDO_PORT;
our $NDO_EXT;

our $last_check_date;

sub loadConfig {
	my ($cfg) = @_;
	my %config;

	Config::Simple->import_from($cfg, \%config) or die "Error reading file: $Config::Simple::errstr";

	$NDO_USER = $config{'default.db_user'};
	$NDO_PASS = $config{'default.db_pass'};
	$NDO_DB = $config{'default.db_name'};
	$NDO_IP = $config{'default.db_host'};
	$NDO_PORT = $config{'default.db_port'};
	$NDO_EXT = $config{'default.db_ext'};
}

sub getLastCheckDate {
	my $dbh = DBI->connect("dbi:mysql:dbname=$NDO_DB;host=$NDO_IP;port=$NDO_PORT;", "$NDO_USER", "$NDO_PASS") or die "Could not connect to database: $DBI::errstr";
	my $sth=$dbh->prepare("select start_time from nagios_servicechecks ORDER BY start_time DESC limit 1 ;");
	$sth->execute() or die $sth->errstr();

	my $ndo_hashref = $sth->fetchrow_hashref();

	$sth->finish();
	$dbh->disconnect();

	return $ndo_hashref->{'start_time'};
}

my $help;
my $warning;
my $critical;

Getopt::Long::Configure ("bundling");
GetOptions(
'h' => \$help,
'help' => \$help,
'w:s' => \$warning,
'warning:s' => \$warning,
'c:s' => \$critical,
'critical:s' => \$critical,
);

sub print_usage
{
    print "Usage: $0 -w <Warning in minutes> -c <Critical in minutes>\n";
}

# CHECKS
if ( defined($help) )
{
print_usage();
exit $ERRORS{"UNKNOWN"};
}
if ( !defined($warning) )
{
print "Need warning Value!\n";
print_usage();
exit $ERRORS{"UNKNOWN"};
}
if ( !defined($critical) )
{
print "Need critical Value!\n";
print_usage();
exit $ERRORS{"UNKNOWN"};
}

#Catch if there are some error and raises CRTICAL status.
eval {&loadConfig($NDO_CFG);}; if ($@) { print $@; exit $ERRORS{"CRITICAL"};}

#Catch if there are some error and raises CRTICAL status.
eval {$last_check_date = &getLastCheckDate();}; if ($@) { print $@; exit $ERRORS{"CRITICAL"};}


print "$last_check_date\n";

my $now = time();
my $parser = DateTime::Format::Strptime->new( pattern => '%F %T', locale => $LOCALE, time_zone => $TIME_ZONE, on_error => 'croak', );
my $last_check_parse = $parser->parse_datetime($last_check_date) or die "Error parsing date: $parser->error()";
my $last_check = $last_check_parse->epoch();

my $difference = $now - $last_check;

my $exit_state = $ERRORS{"OK"};
my $error = "";

$difference = ceil($difference/60);

if ($difference > $critical){
	$exit_state = $ERRORS{"CRITICAL"};	
	$error = "ERROR: The last check in NDOUtils has $difference minutes\n";
}elsif ($difference > $warning){
	$exit_state = $ERRORS{"WARNING"};	
	$error = "WARNING: The last check in NDOUtils has $difference minutes\n";
}else{
	$exit_state = $ERRORS{"OK"};	
	$error = "OK: The last check in NDOUtils has $difference minutes\n";
}

print $error;
exit $exit_state;

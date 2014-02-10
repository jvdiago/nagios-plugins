#!/usr/bin/perl -s

############################## check_informix_tablespaces.pl #################
my $Version='1.00';
# Date : Dec 10 2010
# Author  : Javier Vela ( jvdiago@dagorlad.es )
# Website : http://www.dagorlad.es/ |
# Licence : GPL - http://www.fsf.org/licenses/gpl.txt
# Checks if the tablespaces of an Informix database.
####################################################################
#
# Help : ./check_informix_tablespaces.pl -h
#
##

use POSIX;
use DBI;
use Getopt::Long 2.16;

$ENV{INFORMIXDIR}="/opt/IBM/informix64";
$ENV{ODBCINI}="/etc/odbc.ini";
$ENV{LD_LIBRARY_PATH}="/opt/IBM/informix64/lib:/opt/IBM/informix64/lib/cli:/opt/IBM/informix64/lib/esql";

use lib "/usr/lib64/nagios/plugins/";

my $FICH = "/tmp/informix.".$$;

use utils qw(%ERRORS $TIMEOUT);
my $ERRORS =
{
        'OK'      => 0,
        'WARNING' => 1,
        'CRITICAL'=> 2,
        'UNKNOWN' => 3
};


sub usage
{
        print qq{Uso : $0 -db=<database_id> -w=<warning> -c=<critical> -d=<TB1,TB2,...>
  -db        : Database ID
  -w          : warning
  -c          : critical
  -d          : Excluded tablespaces 
}
}

sub check_arguments
{
        if (!$db || !$w || !$c )
        {
                print ("Wrong arguments !\n");
                &usage;
                exit $ERRORS->{'UNKNOWN'};
        }
}

if (defined($h))
{
        &usage;
        exit $ERRORS->{'OK'};
}

my @diskArray;

if ((defined ($d)) && ($d ne "")){
	@diskArray = split(/,/,join(',',$d));
}

#Ignored Tablespaces
push (@diskArray,"t_tmp2","t_tmp1","physdbs","logdbs");
undef %diskMap;
for (@diskArray) { $diskMap{$_} = 1 }

&check_arguments;

my $statement = "SELECT sd.name[1,18], ROUND(SUM(sc.chksize * ( SELECT sh_pagesize FROM sysshmvals)) / (1024*1024),0) mb_allocated, ROUND(SUM(sc.nfree * ( SELECT sh_pagesize FROM sysshmvals)) / (1024*1024),0) mb_free FROM sysdbspaces sd, syschunks sc WHERE sd.dbsnum = sc.dbsnum AND sd.is_sbspace = 0 AND sd.is_blobspace = 0 GROUP by sd.name ORDER by 1";

`echo '$statement' | isql -v $db -d# > $FICH 2>&1`;

my $ok_s = "OK: ";
my $warn_s = "WARN: ";
my $crit_s = "CRIT: ";
my $state = $ERRORS{"OK"};

open (FDISK,$FICH);
while (<FDISK>){
	chomp($_);
	if ($_ =~ m/.*?\[ISQL\]ERROR.*?/){
		print "$_\n";
		`rm -f $FICH`;
		exit $ERRORS{"CRITICAL"};
	}
	my @row = split("#");
	if ($#row eq 2){
		my ($dbname, $allocate, $free) = @row;
		$dbname =~ s/SQL>//g;
		$dbname =~ s/SQL//g;
		$dbname =~ s/^\s+//;
	        $dbname =~ s/\s+$//;

	        $perc_used = ceil((100*$allocate)/($allocate+$free));
		if ( ! exists($diskMap{$dbname}) ) {
			if ($perc_used > $c){
				$state = $ERRORS{"CRITICAL"};
				$crit_s .= "$dbname=$perc_used% > $c% ";
			}
			elsif ($perc_used > $w){

				if($state eq $ERRORS{"OK"}){
					$state = $ERRORS{"WARNING"};
				}
				$warn_s .= "$dbname=$perc_used% > $w% ";
		
			}else{
				$ok_s .= "$dbname=$perc_used% ";
		
			}
		}	
	} 
}
close(FDISK);

`rm -f $FICH`;

print "$ok_s $warn_s $crit_s\n";
exit $state;

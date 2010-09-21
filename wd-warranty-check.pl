#!/usr/bin/perl -w
# 2010/09/01 @ Zdenek Styblik
#
# Desc: check whether given HDD serial number is still under 
# warranty with Western Digital
#
# Warranty states:
# ---
# In Limited Warranty
# Out of Limited Warranty
# No Limited Warranty
# Out of Region
# SCSI Product
# Stolen Drive
# Invalid Serial Number
# Wrong Site ID in use
# Incomplete Info - Contact Us 
#
use strict;
use warnings;
use HTTP::Cookies;
use LWP::UserAgent;

sub help {
	printf("Western Digital HDD warranty checker.\n");
	printf("Usage: wd-warranty-check.pl <S/N>; for one number\n");
	printf("Usage: wd-warranty-check.pl -l; for continuous checks\n\n");
	return 0;
} # sub help

sub checkWarranty {
	my $browser = shift || undef;
	my $hddSN = shift || undef;
	if (!$browser || !$hddSN) {
		printf("Browser/HDD SerNum is undefined.\n");
		return 254;
	} # if !$hddSN
	if ($hddSN !~ /^[A-Za-z0-9]+$/) {
		printf("HDD S/N has invalid format.\n");
		return 253;
	} # if $hddSN
	printf("Checking warranty ...\n");
	my $req1 = HTTP::Request->new(
		POST => 'http://websupport.wdc.com/warranty/serialinput.asp',
	);
	$req1->content_type('application/x-www-form-urlencoded');
	$req1->content('NoErrorMessage=false&ispostback=y&cmd=continue'
		.'&countryobjid=268435464&seriallist='.$hddSN
		.'&btncontinue=Continue');
	my $response = $browser->request($req1);

	unless ($response->is_redirect) {
		printf("Something went wrong here (S/N is probably incorrect).\n");
		printf("Error: %s\n", $response->status_line);
		return 252;
	} # $response->is_redirect
	my $location = 'http://websupport.wdc.com/warranty/'
		.$response->header("location");
	my $response2 = $browser->get($location);

	my $rc = 200;
	my $state = "Unknown error";
	my @content = $response2->content;
	for my $line (@content) {
		if ($line =~ m/In Limited Warranty/) {
			$state = "is still under warranty";
			$rc = 0;
		} elsif ($line =~ m/Out of Limited Warranty/) {
			$state = "is NOT under warranty";
			$rc = 1;
		} elsif ($line =~ m/Invalid Serial Numbers/) {
			$state = "seems to be invalid";
			$rc = 2;
		} elsif ($line =~ m/Out of Region/i) {
			$state = "is out of region";
			$rc = 3;
		} elsif ($line =~ m/SCSI Product/i) {
			$state = "is SCSI product";
			$rc = 4;
		} # if $line =~ ...
		printf("Drive with SN %s %s.\n", $hddSN, $state);
	} # for my $line
	undef($req1);
	undef($response);
	undef($response2);
	return $rc;
} # sub checkWarranty

sub checkWarrantyLoop {
	my $browser = shift || undef;
	unless ($browser) {
		printf("Browser not defined.\n");
		return 254;
	}
	printf("Continuous WD S/N check. Type 'Q' to quit.\n");
	while (1 > 0) {
		printf("Enter WD S/N: ");
		my $hddSN = <STDIN>;
		if (!$hddSN) {
			printf("\n");
			next;
		} # if !$hddSN
		chomp($hddSN);
		if ($hddSN eq 'Q') {
			last;
		} # if $hddSN
		&checkWarranty($browser, $hddSN);
	} # while true
	return 0;
} # sub checkLoop

### MAIN ###
my $numParams = $#ARGV + 1;
if ($numParams == 0) {
	printf("Not enough parameters given.\n");
	&help;
	exit 1;
}

my $param = $ARGV[0] || -1;

if ($param eq '-h' || $param eq '--help') {
	&help;
	exit 1;
} # if $param eq ...


my $browser = LWP::UserAgent->new;
$browser->cookie_jar(
	HTTP::Cookies->new(
		file => "lwpcookies.txt",
		autosave => 1,
	)
);
$browser->agent("FooBar/0.1a");

my $respInit1 = $browser->get(
	'http://websupport.wdc.com/'
);

unless ($respInit1->is_success) {
	printf("1st response failed.\n");
	exit 254;
} # unless $respInt1

#my $foo = $browser->get(
#	'http://websupport.wdc.com/warranty/serialinput.asp?custtype=end'
#	.'&requesttype=warranty&lang=en'
#);

#printf("%s\n", $foo->as_string) unless $foo->is_success;

my $reqA = HTTP::Request->new(
		POST => 'http://websupport.wdc.com/warranty/serialinput.asp',
	);
$reqA->content_type('application/x-www-form-urlencoded');
$reqA->content('NoErrorMessage=false&ispostback=y&cmd=changecountry'
	.'&custtype=end&requesttype=warranty&countryobjid=268435464'
	.'&seriallist=');
my $respInit2 = $browser->request($reqA);
unless ($respInit2->is_success) {
	printf("2nd init response failed.\n");
	exit 254;
} # unless $respInit2

if ($param eq '-l') {
	&checkWarrantyLoop($browser);
} else {
	if ($param !~ /^[A-Za-z0-9]+$/) {
		printf("Invalid parameter given.\n");
		exit 2;
	} # if $param !~ ...
	&checkWarranty($browser, $param);
} # if $ARGV

undef($browser);

### EOF ###

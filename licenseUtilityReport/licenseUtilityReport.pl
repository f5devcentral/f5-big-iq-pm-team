#! /usr/bin/perl -w

#################################################################################
# Copyright 2018 by F5 Networks, Inc.
#
#Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
#You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#Unless required by applicable law or agreed to in writing, software
#distributed under the License is distributed on an "AS IS" BASIS,
#WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#See the License for the specific language governing permissions and
#limitations under the License.
#################################################################################

# set the version of this script
my $program = $0;
$program = `basename $program`;
chomp $program;
my $version = "v1.2";

## CHANGE QUEUE
# 03/07/2018: v1.0  r.jouhannet@f5.com     Initial version
# 03/08/2018: v1.1  r.jouhannet@f5.com     Add crontab help, fix Use of uninitialized value $opt_r line 347
#                                           Replace Finished with Successful in Table Count, change date format in getTimeStamp2()
#                                           Fix login() when password contains double !!, update the help.
# 07/18/2018: v1.2  r.jouhannet@f5.com     remove authentication (script HAVE TO BE execute on the BIG-IQ locally)

## DESCRIPTION
# Written for BIG-IQ 5.2 and up.
# Utility Billing Report - Generate a usage report for your utility license(s) and provide to F5 Networks Inc. for billing purposes.
# This script generate the utility billing report based of a list of regKey.
#
# Make sure you can access api.f5.com port 443 if automatic reporting is chosen (nslookup api.f5.com, ping api.f5.com, telnet api.f5.com 443)
# 
# The script should be installed under /shared/scripts:
# mkdir /shared/scripts
# chmod +x /shared/scripts/licenseUtilityReport.pl
#
# Make sure you test the script before setting it up in cronab. It is also recommended to test the script in crontab.
# Configure the script in crontab and set a time in the next 3 min: e.g. if it is 8am, set it to run 8:03am
# 3 8 * * * /usr/bin/perl /shared/scripts/licenseUtilityReport.pl -k DRLPZ-JISKU-VPUPT-HZMMV-LERVPYQ
# 
#┌───────────── minute (0 - 59)
#│ ┌───────────── hour (0 - 23)
#│ │ ┌───────────── day of month (1 - 31)
#│ │ │ ┌───────────── month (1 - 12)
#│ │ │ │ ┌───────────── day of week (0 - 6) (Sunday to Saturday;
#│ │ │ │ │                                       7 is also Sunday on some systems)
#│ │ │ │ │";
#│ │ │ │ │";
#* * * * *
#
my $dir = "/shared/scripts";

use JSON;     # a Perl library for parsing JSON - supports encode_json, decode_json, to_json, from_json
use Time::HiRes qw(gettimeofday);
use Data::Dumper qw(Dumper);    # for debug
use File::Find;
use File::Temp qw(tempfile);
use LWP;
use LWP::Simple;

#use strict;
use warnings;

my $section_head = "###########################################################################################";
my $table_head = "#------------------------------------------------------------------------------------------";
my $overallStartTime = gettimeofday();

my $col1Fmt = "%-18s";
my $colFmt = "%-15s";

chdir($dir) or die "Can't chdir to $dir $!";

# log file
my $log = "licenseUtilityReport.log";
unlink glob $log;
open (LOG, ">$log") || die "Unable to write the log file, '$log'\n";
&printAndLog(STDOUT, 1, "#\n# Program: $program  Version: $version\n");

# report file (for manual option)
my $timestamp2 = getTimeStamp2();
$reportfile = "F5_Billing_License_Report.$timestamp2.txt";
if (-e "tmp.csv"){
	# remove report if it exists (in case the user ran the script 2 times in the same min.
	unlink glob $reportfile;
}

# get input from the caller
use Getopt::Std;

my %usage = (
    "h" =>  "Help",
    "c" =>  "Path to CSV file with all regKey(s) - REQUIRED if not using -k",
    "k" =>  "regKey(s) separated by , - REQUIRED if not using -c",
    "r" =>  "Report option automatic or manual - OPTIONAL (default is automatic)",
);
# Use this to determine the order of the arg help output
my @usage = ("h","c","k","r","q");
our($opt_h,$opt_c,$opt_k,$opt_r,$opt_q);
getopts('hc:q:k:r:v');
if (defined $opt_h) {
    print "\nGeneration of Utility Billing Report using BIG-IQ's API.\n";
    print "\nThe regkey listed in the csv file or in the command line are the registration key associated with the license pool you wish to report on.";
    print "\nReports can be automatically submitted to F5 or manually created:\n";
    print " - Automatic report submission requires BIG-IQ to access api.f5.com.\nBIG-IQ makes a REST call over SSL to api.f5.com to upload the report.\n";
    print " - Manual report submission is used in cases where BIG-IQ cannot reach api.f5.com.\nIn this workflow, the customer generates the report, extracts it, then emails it to F5 (filename F5_Billing_License_Report.<date>.txt).\n";
    print "\nThis script only applies to utility-type licenses used for F5's subscription and/or ELA programs.\n";
    print "\nAllowed command line options:\n";
    foreach my $opt (@usage) {
        print ("\t-$opt\t$usage{$opt}\n");
    }
    print "\n- Command line example automatic report:\n";
    print "# ./licenseUtilityReport.pl -k DRLPZ-JISKU-VPUPT-HZMMV-LERVPYQ,GYCWI-FOUEZ-YMWPX-LYROB-PXTKMTG\n";
    print "\n- CSV file example manual report:\n";
    print "# ./licenseUtilityReport.pl -c listregkey.csv -r manual\n";
	print "# cat listregkey.csv\n";
	print "  DRLPZ-JISKU-VPUPT-HZMMV-LERVPYQ\n";
    print "  GYCWI-FOUEZ-YMWPX-LYROB-PXTKMTG\n";
	print "\nCrontab example (every 1st of the month at 10am):\n";
	print "# crontab -e (edit: type o to add a new line, then ESC and :x to save and quit)\n";
	print "# crontab -l (list)\n";
	print "0 10 1 * * /usr/bin/perl /shared/scripts/licenseUtilityReport.pl -k DRLPZ-JISKU-VPUPT-HZMMV-LERVPYQ,GYCWI-FOUEZ-YMWPX-LYROB-PXTKMTG\n";
	print "\n0 10 1 * * /usr/bin/perl /shared/scripts/licenseUtilityReport.pl -c /shared/script/listregkey.csv -r manual\n\n";
	print "\n┌───────────── minute (0 - 59)";
	print "\n│ ┌───────────── hour (0 - 23)";
	print "\n│ │ ┌───────────── day of month (1 - 31)";
	print "\n│ │ │ ┌───────────── month (1 - 12)";
	print "\n│ │ │ │ ┌───────────── day of week (0 - 6) (Sunday to Saturday;";
	print "\n│ │ │ │ │                                       7 is also Sunday on some systems)";
	print "\n│ │ │ │ │";
	print "\n│ │ │ │ │";
	print "\n* * * * *\n\n";
	print "/!\\ NOTE /!\\: if manual report is selected, do not forget to delete the old reports after submission to F5\n\n";
    exit;
}


# useful stuff for JSON
my $contType = "Content-Type: application/json";
# not needed as authentication has been removed in version 1.2, script needs to be executed locally on the BIG-IQ
#my $bigiqCreds = "admin:admin";
#if (defined $opt_q) {
#    $bigiqCreds = "$opt_q";
#}

# create browser for LWP requests
my $browser = LWP::UserAgent->new;

# See if we got the input we needed, bail with an error if we didn't
if (!defined $opt_c && !defined $opt_k) {
    &printAndLog(STDERR, 1, "\nPlease use -h for help\nPlease use -k <regkey>,<regkey> or -c to provide the path to the .csv file.\n");
    &gracefulExit(1);
}


# ======================================================
# Import the .csv file, validate it or parse keys in command line
# ======================================================

# If no CSV file but regKey defined in the command line, create a temporary file with all the regKey.
if (!defined $opt_c && defined $opt_k) {
	$opt_c = "tmp.csv";
	open (FILE, ">$opt_c") || die "Unable to write the report file, '$opt_c'\n";
	my @array = split(',', $opt_k); 
	foreach my $ln (@array ) {
		print FILE "$ln\n";
	}
	close FILE;
}

# parse the regKey
my ($regKey);
# read the CSV file
open (FILE, "$opt_c") || die "## ERROR: Unable to read the .csv file, '$opt_c'\n";
my @csvLns = <FILE>;
close FILE;
my @regKeys;

my $index = 0;
foreach my $ln (@csvLns) {
	chomp $ln;
	$ln =~ s/[\cM\cJ]+//g;  # some editors tack multiple such chars at the end of each line
	$ln =~ s/^\s+//;        # trim leading whitespace
	$ln =~ s/\s+$//;        # trim trailing whitespace

	# skip blank lines
	if ($ln eq '') {
		next;
	}

	# skip comments
	if ($ln =~ /^\s*#/) {
		next;
	}

	# parse line
	my ($mregKey) = split(/\s*,\s*/, $ln);

	# remember parameters for each device (in file order)
	$regKeys[$index]{"regKey"} = $mregKey;
	$index++;
	#&printAndLog(STDOUT, 1, "DEBUG $index $mregKey\n");
}



#======================================================
# Make sure the BIG-IQ API is available
# Check for available over timeout period (120 sec)
# Exit if not available during this period
#======================================================
my $timeout = 120;
my $perform_check4life = 1;
my $check4lifeStart = gettimeofday();

while($perform_check4life) {
    my $timestamp = getTimeStamp();
    my $response = $browser->get("https://localhost/info/system");
    if ($response->is_success && $response->content_type eq "application/json") {
        my $jsonWorker = JSON->new->allow_nonref;
        my $isAlive = $jsonWorker->decode($response->content);

        # Check for API availability
        if ((defined $isAlive->{"available"}) && ($isAlive->{"available"} eq "true")) {
            &printAndLog(STDOUT, 1, "#\n# BIG-IQ UI is available: $timestamp\n");
            $perform_check4life = 0;
            last;
        } else {
            &printAndLog(STDOUT, 1, "# BIG-IQ UI is not yet available: $timestamp\n");
        }
    }
    
    # Exit on timeout
    if ((gettimeofday() - $check4lifeStart) > $timeout) {
        &printAndLog(STDERR, 1, "## ERROR: The BIG-IQ UI is still not available.  Try again later...\n");
        &gracefulExit(1);
    }
    sleep 10;
}


#======================================================
# Check the BIG-IQ version
#======================================================

my $url = 'http://localhost:8100/shared/resolver/device-groups/cm-shared-all-big-iqs/devices?$select=version';
my $resp = getRequest($url, "check version");
my $bqVersion = $resp->{"items"}[0]->{"version"};

&printAndLog(STDOUT, 1, "BIG-IQ version: $bqVersion\n");

if ($bqVersion lt "5.2.0") {
        &printAndLog(STDERR, 1, "## ERROR: not supported in version '$bqVersion'.\n");
        &gracefulExit(1);
}

#======================================================
# Log start time
#======================================================

my $overallStart = gettimeofday();
&printAndLog(STDOUT, 1, "#\n# $section_head\n");
my $timestamp = getTimeStamp();
&printAndLog(STDOUT, 1, "#\n# Start Utility License Report using BIG-IQ's API: $timestamp\n");


# Initialize regKey status table
my %regKeyStatus;
$regKeyStatus{"all"}{"FINISHED"} = 0;
$regKeyStatus{"all"}{"FAILED"} = 0;


#======================================================
# Manual or Automatic report option
#======================================================

my $manuallySubmitReport;
 
if (defined $opt_r) {
    if ($opt_r eq "manual") {
        $manuallySubmitReport = "true";
		&printAndLog(STDOUT, 1, "\nOption: manually submit report to F5.\n");
	}
	else
	{
		$manuallySubmitReport = "false";
		$opt_r = "automatic";
		&printAndLog(STDOUT, 1, "\nOption: automatically submit report to F5.\n");
	}
}
else
{
		$manuallySubmitReport = "false";
		$opt_r = "automatic";
		&printAndLog(STDOUT, 1, "\nOption: automatically submit report to F5. (default)\n");
}


#======================================================
# Main loop
#======================================================

my $loopForCount = 1;

for $regKey (@regKeys) {

    my $done = 0;
	my $loopWhileCount = 0;
	my $successStatus = 0;
	my $mregKey = $regKey->{"regKey"};
    &printAndLog(STDOUT, 1, "\n#$loopForCount Generating the Report Request for $mregKey\n");
	
	# Step 1: Generating the Report Request
	my %postBodyHash = ("regKey"=>$mregKey, "manuallySubmitReport"=>$manuallySubmitReport);
	
  	my $postBody = encode_json(\%postBodyHash);
    my $url = 'http://localhost:8100/cm/device/licensing/utility-billing-reports';
    my $reportTask = postRequest($url, $postBody, "Generating the Report Request $mregKey");
   	my $reportStatus = $reportTask->{"status"};
    my $reportLink = $reportTask->{"selfLink"};
    # replacing https://localhost/mgmt with http://localhost:8100 (no authentication needed)
    my $tmp1 = "https://localhost/mgmt";
    my $tmp2 = "http://localhost:8100";
    $reportLink =~ s/$tmp1/$tmp2/;
	$timestamp = getTimeStamp();
	# &printAndLog(STDOUT, 1, "$timestamp: $reportStatus\n");
	my $timestamp = getTimeStamp();
	if (not defined $reportStatus) {
		$done = 1;
	}
	else
	{	
		&printAndLog(STDOUT, 1, "$timestamp: $reportStatus\n");
	}
	
	my $regKeyStart = gettimeofday();
	# Step 2: Polling for report completion 9 in a loop, max try 5 times, wait 1sec between each pooling
    while (not $done)
    {
		my $url = $reportLink;
		my $reportTask = getRequest($url, "Get report completion details for $mregKey");
		my $reportStatus = $reportTask->{"status"};
		$reportLink = $reportTask->{"selfLink"};
        # replacing https://localhost/mgmt with http://localhost:8100 (no authentication needed)
        my $tmp1 = "https://localhost/mgmt";
        my $tmp2 = "http://localhost:8100";
        $reportLink =~ s/$tmp1/$tmp2/;
		$timestamp = getTimeStamp();
		# &printAndLog(STDOUT, 1, "$timestamp: $reportStatus\n");

		if ($loopWhileCount++ > 5)
        {
            &printAndLog(STDOUT, 1, "Exiting with max tries\n");
            last;
        }
	    # "status":"FAILED": show error
        if ($reportStatus eq "FAILED")
        {
            my $errorMessage = $reportTask->{"errorMessage"};
            &printAndLog(STDOUT, 1, "$errorMessage\n");
            $done = 1;
        }
		# "status":"FINISHED" : if manual, save the report, if automatic, the request has been sent to api.f5.com
        if ($reportStatus eq "FINISHED")
        {
			if ($opt_r eq "manual") {
				my $reportUri = $reportTask->{"reportUri"};
				#&printAndLog(STDOUT, 1, "$reportUri\n");
                # replacing https://localhost/mgmt with http://localhost:8100 (no authentication needed)
                my $tmp1 = "https://localhost/mgmt";
                my $tmp2 = "http://localhost:8100";
                $reportUri =~ s/$tmp1/$tmp2/;
				my $reportTask = getRequest($reportUri, "Get Manual Report for $mregKey");
				#print Dumper $reportTask;
				open (FILE, ">>$reportfile") || die "Unable to write the report file, '$reportfile'\n";
				print FILE Dumper($reportTask);
				close FILE;
				&printAndLog(STDOUT, 1, "Report manually added to local file.\n");
			}
			else
			{
				&printAndLog(STDOUT, 1, "Report automatically submitted to F5.\n");
			}
            $successStatus = 1;
            $done = 1;
        }

		sleep 1;
    }  #end while task
	
	$loopForCount++;	
	
    # We need to be successful before we increment the success count, otherwise we increment the FAILED
    if ($successStatus eq 1)
    {
        $regKeyStatus{"all"}{"FINISHED"}++;
    }
    else
    {
        $regKeyStatus{"all"}{"FAILED"}++;
    }
} # end

$timestamp = getTimeStamp();
&printAndLog(STDOUT, 1, "\n# End:  $timestamp\n");

#======================================================
# Show results.
#======================================================

showTotals();

#======================================================
# Finish up
#======================================================
&gracefulExit(0);

#======================================================
# getRequest - A subroutine for making GET requests
#======================================================

sub getRequest {
    my ($url, $message) = @_;

    # log the URL
    print LOG "GET $url\n";

    # make the get request, including the auth header
    my %headers = (
        'User-Agent' => 'bulkDiscovery',
        'Connection' => 'keep-alive',
    );
    my $response = $browser->get($url, %headers);

    # log status
    print LOG $response->status_line . "\n";

   
    # if non-auth error - exit
    if ($response->is_error)
    {
        &printAndLog(STDERR, 1, "GET request failed, exiting\n");
        &gracefulExit(1);
    }

    if ($response->content_type eq "application/json") {
        my $jsonWorker = JSON->new->allow_nonref;                  # create a new JSON object which converts non-references into their values for encoding
        my $jsonHash = $jsonWorker->decode($response->content);    # converts JSON string into Perl hash(es)
        my $showRet = $jsonWorker->pretty->encode($jsonHash);      # re-encode the hash just so we can then pretty print it (hack-tacular!)
        return $jsonHash;
    }
	# for json file to download
	elsif ($response->content_type eq "application/octet-stream") {
		my $jsonWorker = JSON->new->allow_nonref;                  # create a new JSON object which converts non-references into their values for encoding
        my $jsonHash = $jsonWorker->decode($response->content);    # converts JSON string into Perl hash(es)
        my $showRet = $jsonWorker->pretty->encode($jsonHash);      # re-encode the hash just so we can then pretty print it (hack-tacular!)
        return $jsonHash;
	}
    else
    {
        &printAndLog(STDERR, 1, "GET request - unknown response - exiting\n");
        &printAndLog(STDERR, 1, $response->content_type . "\n");
        &printAndLog(STDERR, 1, $response->content . "\n");
        #&gracefulExit(1);
    }
}


#======================================================
# postRequest - A subroutine for making POST requests
#======================================================

sub postRequest {
    my ($url, $jsonPostData, $message) = @_;
    return postOrPatchRequest ($url, "POST", $jsonPostData, $message);
}

#======================================================
# patchRequest - A subroutine for making PATCH requests
#======================================================

sub patchRequest {
    my ($url, $jsonPostData, $message) = @_;
    return postOrPatchRequest ($url, "PATCH", $jsonPostData, $message);
}

sub postOrPatchRequest {
    my ($url, $verb, $jsonPostData, $message) = @_;

    #log the url & post data
    print LOG "$verb $url\n";
    print LOG maskPasswords("$jsonPostData\n");

    my %headers = (
        'User-Agent' => 'utilityLicenseReport',
        'Connection' => 'keep-alive'
    );

    my $req = HTTP::Request->new($verb, $url);
    $req->header(%headers);
    $req->content($jsonPostData);
    my $response = $browser->request($req);

    # if non-auth error - exit
    if ($response->is_error)
    {
        print STDERR "$verb $url\n";
        print STDERR maskPasswords("$jsonPostData\n");

        &printAndLog(STDERR, 1, "$verb error - exiting\n");
        if ($response->content_type eq "application/json") {
            &prettyPrintAndLogJson (STDERR, 1, $response->content);
        }
        else {
            &printAndLog(STDERR, 1, $response->content);
    }
        #&gracefulExit(1);	# should it really exit?
    }

    if ($response->content_type eq "application/json") {
        my $jsonWorker = JSON->new->allow_nonref;                  # create a new JSON object which converts non-references into their values for encoding
        my $jsonHash = $jsonWorker->decode($response->content);    # converts JSON string into Perl hash(es)

        my $showRet = $jsonWorker->pretty->encode($jsonHash);      # re-encode the hash just so we can then pretty print it (hack-tacular!)
        my $maskln = &maskPasswords($showRet);                     # remove any passwords before logging
	print LOG $maskln;

        return $jsonHash;
    }
    else
    {
        &printAndLog(STDERR, 1, "$verb Request - unknown response - exiting\n");
        &printAndLog(STDERR, 1, $response->content_type . "\n");
        &printAndLog(STDERR, 1, $response->content);
        #&gracefulExit(1);	# should it really exit?
    }
}



#======================================================
# A subroutine for total counts.
#======================================================

sub showTotals {

    my $string = sprintf "#\n# %-10s %-10s", "Successful", "Failed";

    &printAndLog(STDOUT, 1, "$string\n");        
    &printAndLog(STDOUT, 1, "$table_head\n");  
    $string = sprintf "# %-10s %-10s", $regKeyStatus{"all"}{"FINISHED"}, $regKeyStatus{"all"}{"FAILED"};
	&printAndLog(STDOUT, 1, "$string\n");
	&printAndLog(STDOUT, 1, "$table_head\n");
	if ( $manuallySubmitReport eq "true") {
    	&printAndLog(STDOUT, 1, "# Utility License Report file: $reportfile\n\n");  
	}
}

#======================================================
# A subroutine to take a string and return a copy with all
# the passwords masked out.
#======================================================
sub maskPasswords {
    my ($pwStr) = @_;

    $pwStr =~ s/"password":".*?"/"password":"XXXXXX"/g;
    $pwStr =~ s/"adminPassword":".*?"/"adminPassword":"XXXXXX"/g;
    $pwStr =~ s/"rootPassword":".*?"/"rootPassword":"XXXXXX"/g;

    return $pwStr;
}

#======================================================
# A subroutine for both printing to whatever file is given
# and printing the same thing to a log file.
# This script does a lot, so it may be useful to keep a log.
#======================================================
sub printAndLog {
    my ($FILE, $printToo, @message) = @_;

    my $message = join("", @message);
    print $FILE $message if ($printToo);
    print LOG $message;
}


#======================================================
# pretty format, mask passwords, and log a json string
#======================================================
sub prettyPrintAndLogJson {
    my ($FILE, $printToo, $jsonString) = @_;

    my $jsonWorker = JSON->new->allow_nonref; 
    my $jsonHash = $jsonWorker->decode($jsonString);
    my $showRet = $jsonWorker->pretty->encode($jsonHash);
    my $maskln = &maskPasswords($showRet);
    &printAndLog($FILE, $printToo, "$maskln\n");
}

#======================================================
# Print the log file and then exit, so the user knows which log
# file to examine.
#======================================================
sub gracefulExit {
    my ($status) = @_;
    #&printAndLog(STDOUT, 1, "\n# Utility License Report log file: $log\n");    
    close LOG;
	if (-e "tmp.csv"){
		# remove temporary file
		unlink glob "tmp.csv";
	}
    exit($status);
}

#======================================================
# Pretty-print the time: 03/07/2018 11:29:10
#======================================================
sub getTimeStamp {
    my ($Second, $Minute, $Hour, $Day, $Month, $Year, $WeekDay, $DayOfYear, $IsDST) = localtime(time); 
    my $time_string = sprintf ("%02d/%02d/%02d %02d:%02d:%02d",$Month+1,$Day,$Year+1900,$Hour,$Minute,$Second);
    return ($time_string);
}

#======================================================
# Pretty-print the time: 20182902_1022 (for log/report files)
#======================================================
sub getTimeStamp2 {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
    my $nice_timestamp = sprintf ( "%02d%02d%04d_%02d%02d",$mon+1,$mday,$year+1900,$hour,$min);
    return $nice_timestamp;
}

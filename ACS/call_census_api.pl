#-----------------------------------------------------------------------#
# Call the census API using options for year, acs type, variable names
# options -a acs_type -y acs_year -v concept_name
# P. Viechnicki, 6/30/14
# Simplified 10/7/14: pull all tracts for all counties
# debugged and refactored 13 sept 2016
#-----------------------------------------------------------------------#

use lib '../general_utils'; #Where we store general modules
use Getopt::Std; #lib to parse simple options
#use LWP 5.64; #For get method
use LWP;
use cenvarParse; #lib of code to parse the variables xml file
use Fips;
use strict;
my $browser = LWP::UserAgent->new;

my $usage = "call_census_api.pl -k [KEY FILE] -a [acs1|acs3|acs5] -y [ACS_YEAR] -v [ACS CONCEPT NAME] -c [FIPS_COUNTY] -s [FIPS_STATE] -g [COUNTY|TRACT] -h SHOW_HELP";

#Get and parse options
my %opts = ();
getopts('k:a:y:v:c:s:g:h', \%opts);
if ($opts{'h'})
{
    die $usage;
}
if (!$opts{'k'})
{
    die "must specify ACS key file with -k option";
}
if ($opts{'a'} !~ /acs[135]/)
{
    die "-a ACS_TYPE option must be acs1, acs3, or acs5";
}
if (($opts{'y'} < 2001) or ($opts{'y'} > 2014))
{
    die "ACS_YEAR option must be between 2001 and 2014";
}
if (!$opts{'v'})
{
    die "No topic/concept specified for variables to extract.";
}
#Request either a specific county or a specific state, not both
if ($opts{'c'} && $opts{'s'})
{
    die "Please request either a single county or a single state, not both.";
}

#Check that we're requesting the correct geography

my %states;
my %counties;
if (!$opts{'c'})
{
    #Fill in wildcard if no county fips specified
    $opts{'c'} = '*';
    $counties{'*'} = 'All';
}
else
{
    #Else look up info for the county specified with -c option
    my %temp = Fips::getCountyInfo($opts{'c'});
    if ($temp{$opts{'c'}} eq 'Not Found')
    {
	die "No county found with code $opts{'c'}";
    }
    else
    {
	%counties = %temp;
	#Also get the state info for the requested county
	%states = Fips::getStateInfo(substr($opts{'c'}, 0, 2));
	
    }

}

if (!$opts{'s'})
{
    #If we've already filled out our list for states, skip
    if (!%states)
    {
	#%states = Fips::getAllStateInfo(); #Only needed for tracts
	#Fill in wildcard for all states
	$opts{'s'} = '*';
	$states{'*'} = 'All';
    }
}
else
{
    my %temp = Fips::getStateInfo($opts{'s'});
    if ($temp{$opts{'s'}} eq 'Not Found')
    {
	die "Incorrect state code entered: $opts{'s'}";
    }
    else
    {
	%states = %temp;
	%counties = ('*'=>'All');
    }
}

my $tracts = '*';
if ($opts{'g'} !~ /county|tract/i)
{
    die "Incorrect geography $opts{'g'} requested with -g option: should be COUNTY or TRACT."
}


#Call the cenvar Parse module, get var names and labels
my %variable_list =();
my $xml_url = "c:\\data\\AmericanCommunitySurvey\\acs_1yr_2012_var.xml";

#Parse the xml file containing ACS variable names and labels
# to pull out variables matching your topic string
if (!cenvarParse::parseVars($xml_url, $opts{'v'}, \%variable_list))
{
    die "Couldn't parse cenvars XML file.";
}

#I stored my key at "C:\\data\\Census-Data\\census_api_key.txt";
my $keyfile = $opts{'k'};
my $key = '';
&readKeyFile($keyfile, \$key);

#Open datafile for writing
my $datafilename = $opts{'a'}."_".$opts{'y'}."_".$opts{'v'}.".json";
open (DATAFILE, ">", $datafilename) || die "Couldn't open file $datafilename: $!";

#Concat the url from the key and the options
my $url = "http://api.census.gov/data/";
$url .= "$opts{'y'}/$opts{'a'}?get=";
$url .= join(',', keys(%variable_list));
$url .= "&key=$key";

if ($opts{'g'} =~ /tract/i)
{
    my $states_no = 1;
    if ($opts{'s'} eq '*')
    {
	#Replace wildcard with list of states
	%states = ();
	%states = Fips::getAllStateInfo();
    }
    foreach my $state (keys(%states))
    {
	my $tracts_url = $url . "&for=tract:$tracts&in=state:$state";
	my $response = $browser->get($tracts_url);
	die "Can't get $tracts_url -- ", $response->status_line unless $response->is_success;

	if ($states_no == 1)
	{
	    print DATAFILE $response->content;
	}
	else
	{
	    #suppress headers and insert comma for states 2 - n
	    my $buf = '';
	    $buf = $response->content;
	    &stripHeaders(\$buf); #Remove the variable names from states 2-n
	    
	    print DATAFILE $buf;
	}
	++$states_no;
    }

}
elsif ($opts{'g'} =~ /county/i)
{
    my $counties_url = $url;
    my $states_no = 1;
    foreach my $state (keys(%states))
    {
	foreach my $county (keys(%counties))
	{
	    my $short_county_code;
	    if ($county ne '*')
	    {
		$short_county_code = substr($county, 2, 3);
	    }
	    else
	    {
		$short_county_code = '*';
	    }
	    $counties_url .= "&for=county:$short_county_code&in=state:$state";
	    #die $counties_url;
	    #Now that we've composed the url for the API call, execute it
	    my $response = $browser->get($counties_url);
	    die "Can't get $counties_url -- ", $response->status_line unless $response->is_success;

	    if ($states_no == 1)
	    {
		#First time, print headers and data
		print DATAFILE $response->content;
		
	    }
	    else
	    {
		#Second time, just print data
		my $buf = '';
		$buf = $response->content;
		&stripHeaders(\$buf); #Remove variable names and other cruft from
		#states 2 - n
		print DATAFILE $buf;
	    }
	}
    ++$states_no;
    } #For each state in list
}


#Write out JSON results, and variable names and labels in .dict file
my $dictfilename = $opts{'a'}."_".$opts{'y'}."_".$opts{'v'}.".dict";

open (DICTFILE, ">", $dictfilename) || die "Couldn't open file $dictfilename: $!";

foreach my $varname (keys(%variable_list))
{
    print DICTFILE "$varname|";
    print DICTFILE $variable_list{$varname}, "\n";
}
close DATAFILE;
close DICTFILE;




#--------------------------------------------------#
# Read file with list of counties                  #
# write results to array ref                       #
# return 1 (success) or 0 (failure)                #
#--------------------------------------------------#

sub readCountiesList
{
    my $filename = $_[0];
    my $hashref = $_[1];

    #Check args
    if (!$filename || !$hashref)
    {
	return 0;
    }

    open (INFILE, "<", $filename) || die "Couldn't open counties file $filename: $!";

    my @fields = ();
    my $lineno = 0;
    my $county;
    my $state;

    while (<INFILE>)
    {
	next if (++$lineno == 1); #Header row
	chop $_;
	$_ =~ s/\cM//g;
	@fields = split (/\|/, $_);
	if ($#fields != 2)
	{
	    print STDERR "Warning, incorrect number of fields found in counties file at line $lineno: $#fields\n";
	}
	else
	{
	    $state = $fields[0];
	    $county = $fields[1];
	    push @{$$hashref{$state}}, $county;
	}
    }
    return 1;
}

#----------------------------------------------------------------------#
#Pass in a ref to a scalar containing json results
# edit it to remove header row
# not worrying too much about the brackets since we're stripping them
# in the make_sql_insert.pl program anyway.
#----------------------------------------------------------------------#
sub stripHeaders
{
    my $scalarref = shift;
    $$scalarref =~ s/\[\[.*\],//;
}

#----------------------------------------------------------------------#
# Pass in the path to the key file and the ref to the scalar var
# where we'll store the value.  Open file, read, store in variable
#----------------------------------------------------------------------#
sub readKeyFile
{
    my $keyPath = shift;
    my $keyScalarref = shift;

    #Open the key file, snarf key into var
    open(FH, $keyPath) || die "Couldn't open key file $keyPath: $!\n";
    my ($data, $n); 
    while (($n = read FH, $data, 1) != 0) 
    { 
	if ($data !~ /[\n\cM]/)
	{
	    $$keyScalarref .= $data; 
	}
    } 
    close(FH);
    return 0;
}

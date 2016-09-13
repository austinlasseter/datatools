#------------------------------------------------------------------#
# Reads a JSON data file from the ACS API
# and writes out a sql insert statement into the table you specify
# with the -t option
# P. Viechnicki 7/17/14
# updated 8/18 to include a -g option for county/tract geography
#------------------------------------------------------------------#

use Getopt::Std; #lib to parse simple options
use strict;
#Check for correct usage
my $usage = "make_sql_insert.pl -t Tablename -y ACS_YEAR -a ACS_TYPE -g [COUNTY|TRACT] -h SHOW_HELP INPUTFILE";

my %opts = ();
getopts('a:y:t:g:h', \%opts);
if ($opts{'h'})
{
    die $usage;
}
      
my $table_name = $opts{'t'};
my $acs_year = $opts{'y'};
if (($acs_year < 2010 ) or ($acs_year > 2014))
{
    die "ACS year must be between 2010 and 2014";
}
my $acs_type = $opts{'a'};

#Check geography option which will control handling of tract, county column
if ($opts{'g'} !~ /COUNTY|TRACT/i)
{
    die "Incorrect geography $opts{'g'} requested with -g option -- should be COUNTY or TRACT";
}

#Read in var names from line 1, save in list
my $line_no = 0;
my @column_names = ();
while (<>)
{
    chop $_;
    $_ =~ s/\cM//;
    $_ =~ s/[\[\]]//g; #Strip out brackets
    $_ =~ s/"//g; #Strip out quotes
    my @fields = ();
    @fields = split (/,/, $_);

    if ($line_no == 0)
    {
	foreach my $field_name (@fields)
	{
	    push (@column_names, uc($field_name));
	}
	push (@column_names, ('ACS_YEAR', 'ACS_TYPE', 'GEOID'));
    }
    else
    {
	my %key_value_pairs = ();
	foreach my $n (0..$#fields)
	{
	    #Store in hash of keys and values
	    $key_value_pairs{$column_names[$n]} = $fields[$n];
	}
	
#For lines 2 - end construct GEOID
	$key_value_pairs{'ACS_YEAR'} = $acs_year;
	$key_value_pairs{'ACS_TYPE'} = $acs_type;

	if ($opts{'g'} =~ /county/i)
	{
	    $key_value_pairs{'GEOID'} = $key_value_pairs{'STATE'}.$key_value_pairs{'COUNTY'};
	}
	else
	{
	    $key_value_pairs{'GEOID'} = $key_value_pairs{'STATE'}.$key_value_pairs{'COUNTY'}.$key_value_pairs{'TRACT'};
	}

#Write out sql insert statement
	print "INSERT INTO $table_name (";
	foreach my $n (0 .. ($#column_names-1))
	{
	    print "$column_names[$n], ";
	}
	print $column_names[$#column_names];
	print ") VALUES (";
	foreach my $n (0..($#column_names - 1))
	{
	    #Sadly, special handling required for tract, county and state vars,
	    # since they are char variables
	    if ($column_names[$n] =~ /STATE|COUNTY|TRACT|ACS_TYPE|GEOID/i)
	    {
		print "\'", $key_value_pairs{$column_names[$n]}, "\', ";
	    }
	    else
	    {
		print $key_value_pairs{$column_names[$n]}, ", ";
	    }
		
	}
	print '\'', $key_value_pairs{$column_names[$#column_names]}, '\'';
	print ")\;\n";
    }
    ++$line_no;
}



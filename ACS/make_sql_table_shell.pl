#------------------------------------------------------------------#
# Reads a file of variable names and labels from the ACS API
# and writes out a sql make table statement with comments
# P. Viechnicki 7/2/14, updated 7/17/14
# updated 8/18/14 to require -g switch for county or tract geography
#------------------------------------------------------------------#

use Getopt::Std; #lib to parse simple options
#Check for correct usage
$usage = "make_sql_table_shell.pl -t Tablename -g [COUNTY|TRACT] -h SHOW_HELP INPUTFILE";

my %opts = ();
getopts('t:g:h', \%opts);
if ($opts{'h'})
{
    die $usage;
}
if ($opts{'g'} !~ /COUNTY|TRACT/i)
{
    die "Incorrect geography requested with -g option $opts{'g'} - must be COUNTY or TRACT";
}
      
$table_name = $opts{'t'};

#Headers for all tables
print "CREATE TABLE $table_name\n(\n";
print "ROWID SERIAL,\n";
print "GEOID VARCHAR(20) NOT NULL,\n";
#Distinguish between tracts and counties
if ($opts{'g'} =~ /TRACT/i)
{
    #if -g option = tracts, include column for same
    print "TRACT VARCHAR(8) NOT NULL,\n";
}
print "COUNTY VARCHAR(5) NOT NULL,\n";
print "STATE VARCHAR(5) NOT NULL,\n";
print "ACS_TYPE CHAR(4),\n";
print "ACS_YEAR INTEGER,\n";

#Read in var names and labels into a list of lists
$line_no = 0;
while (<>)
{
    chop $_;
    $_ =~ s/\cM//;
    @fields = ();
    @fields = split (/\|/, $_);
    $lines[$line_no] =  [@fields];
    ++$line_no;
}

#Write out a statement creating each variable, assuming each is an integer
#Have to supress comma for last line
foreach $line_no (0..$#lines)
{
    $line_ref = $lines[$line_no];
    print "\t$$line_ref[0] INTEGER,\n";
}
print "PRIMARY KEY (ROWID)\n";
print ")\;\n";

#Write out a comment on each variable giving its description
foreach $line_ref (@lines)
{
    print "COMMENT ON COLUMN $table_name\.$$line_ref[0] IS \'$$line_ref[1]\'\;\n";
}


#-----------------------------------------------------------------
# Parse the xml file with variable names for ACS
# You pass it a string to match the variable concept
# and it returns a hash of variable names and descriptions
# P. Viechnicki, 6/30/14
#-----------------------------------------------------------------


package cenvarParse;

use strict;
use warnings;
use LWP::Simple; # Get URLs
use XML::LibXML;

sub parseVars($$+)
{
# args file URL, concept name
    if ($#_ != 2) { return 0; }

    my $url = $_[0];
    my $concept_name = $_[1]."_";
    my $aref = $_[2];

    my $parser = XML::LibXML->new();
    my $doc = $parser->parse_file($url);

    my $query  = '//concept/variable';
    my $result;

    #Results of query are list of node objects
    foreach $result ($doc->findnodes($query))
	{
	    #For each node that matches the variable name we passed in
	    #Pull out its attribues using the getAttributes method
	    my @attributes = $result->getAttributes();
	    #The first attribute is the variable name, the second
	    # is the variable concept label
	    my $varname = $attributes[0]->getValue();
	    my $var_concept = $attributes[1]->getValue();
	    my $label = $result->textContent();
	    if ($varname =~ /$concept_name/)
	    {
		$$aref{$varname}=$label;
	    }
	}

    return 1;
}
1;


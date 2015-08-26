#!/usr/bin/perl -w

use DBI;
use  DBD::Oracle;
use utf8;
use locale;

# set character encoding for stdout to utf8
binmode(STDOUT, ":utf8");

#************************************************************************************
# Set up environment and make sure it is clean
#************************************************************************************


$ENV{'PATH'} = '/bin:/usr/sbin';
delete @ENV{'ENV', 'BASH_ENV'}; 
$ENV{'NLS_LANG'} = 'AMERICAN_AMERICA.AL32UTF8';

my($dbh, $sth, $sql);

$input = '/cgi/includes/connects/afton_iii_iiidba_perl.inc';
#$input = 'afton_iii_iiidba_perl.inc';

open (INFILE, "<$input") || die &mail_error("Can't open hidden file\n");
  while (<INFILE>){
    chomp;
    @pair = split("=", $_);
    $mycnf{$pair[0]} = $pair[1];
  }

close(INFILE);

my $host = $mycnf{"host"};
my $sid = $mycnf{"sid"};
my $username = $mycnf{"user"};
my $password = $mycnf{"password"};

# untaint all of the db connection variables
if ($host =~ /^([-\@\w.]+)$/) {
     $host=$1;
} else {     
     die "Bad data in $host";
}  

if ($sid =~ /^([-\@\w.]+)$/) {
     $sid=$1;
} else {     
     die "Bad data in $sid";
}  

if ($username =~ /^([-\@\w.]+)$/) {
     $username=$1;
} else {     
     die "Bad data in $username";
}  


$database_session = DBI->connect("dbi:Oracle:host=$host;sid=$sid", $username, $password)
        or die &mail_error("Unable to connect: $DBI::errstr");

# So we don't have to check every DBI call we set RaiseError.
$database_session->{RaiseError} = 1;

#create lists of bnums, broken down into 200K chunks

#start file name numbering with 0 to match with indexes in shell script array
#  which matches with output folders.
$file_num = 0;

# SQL query
# Gets bnums for all records with a cat date and one of the following material types:
#   a - printed matl
#   c - printed music (includes bound monographs of music)
#   e - print map (includes atlases)
#   p - mixed mat - (includes bound monographs with supplementary materials in other formats -- make sure to just send info about the appropriate items)
#   t - manuscript - (includes theses)
# And where bib location is NOT multi and is NOT:
#    dg - Davis Library Microforms
#    dr - Davis Library Bindery
#    dy - Davis Library Equipment
#    eb - Electronic Book
#    ed - Documenting the American South
#    er - Electronic Resource
#    es - Electronic Streaming Media
#    yh - Latin American Film Library 
$sql = "select b.rec_key, 
               b.mat_type
        from biblio2base b 
        where 
        b.mat_type in ('a', 'c', 'e', 'p', 't') 
        and 
        b.cat_date is not null
        and 
        b.location not in ('dg   ', 'dr   ', 'dy   ', 'eb   ', 'ed   ', 'es   ', 'yh   ', 'wa   ')";

$bnum_rows = 0;

$statement_handle = $database_session->prepare($sql);

$statement_handle->execute();

my( $rec_key, $mat_type);
$statement_handle->bind_columns( undef, \$rec_key, \$mat_type);

# open file to write output 
$path = "hbnumin_" . $file_num . ".txt";

open(OUTFILE, ">:utf8", "$path") or die &mail_error("Couldn't open $path for output: $!\n");

#cycle through results

while ($statement_handle->fetch()) {

    print OUTFILE "$rec_key\t$mat_type\n";
	$bnum_rows ++;

	if ($bnum_rows == 200000){
		close OUTFILE;
		print "Wrote bnum list to $path\n";# print to stdout
		$file_num ++;
                $path = "hbnumin_" . $file_num . ".txt";
		open(OUTFILE, ">:utf8", "$path") or die &mail_error("Couldn't open $path for output: $!\n");
 		$bnum_rows = 0;
            }
} #end while $statement_handle


# close statement handle, database handle, and output file.
$statement_handle->finish();
close(OUTFILE);
$database_session->disconnect();

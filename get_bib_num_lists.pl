#!/usr/bin/perl -w

use DBI;
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
db_connect('sierra');


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
# And where the sole bib location is NOT:
#    dg - Davis Library Microforms
#    dr - Davis Library Bindery
#    dy - Davis Library Equipment
#    eb - Electronic Book
#    ed - Documenting the American South
#    er - Electronic Resource
#    es - Electronic Streaming Media
#    yh - Latin American Film Library 
$mil_sql = "select b.rec_key, 
               b.mat_type
        from biblio2base b 
        where 
        b.mat_type in ('a', 'c', 'e', 'p', 't') 
        and 
        b.cat_date is not null
        and 
        b.location not in ('dg   ', 'dr   ', 'dy   ', 'eb   ', 'ed   ', 'es   ', 'yh   ', 'wa   ')";

$sql = "select distinct 'b' || rm.record_num,
                    bp.material_code
            from sierra_view.bib_record b
              inner join sierra_view.bib_record_location bl on bl.bib_record_id = b.id
              inner join sierra_view.bib_record_property bp on bp.bib_record_id = bl.bib_record_id
              inner join sierra_view.record_metadata rm on rm.id = b.id
            where bp.material_code in ('a', 'c', 'e', 'p', 't')
              and b.cataloging_date_gmt is not null
              and bl.location_code not in ('dg', 'dr', 'dy', 'eb', 'ed', 'es', 'yh', 'wa')";

$bnum_rows = 0;

$sth = $dbh->prepare($sql);

$sth->execute();

my( $rec_key, $mat_type);
$sth->bind_columns( undef, \$rec_key, \$mat_type);

# open file to write output 
$path = "hbnumin_" . $file_num . ".txt";

open(OUTFILE, ">:utf8", "$path") or die &mail_error("Couldn't open $path for output: $!\n");

#cycle through results

while ($sth->fetch()) {

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
} #end while $sth


# close statement handle, database handle, and output file.
$sth->finish();
close(OUTFILE);
$dbh->disconnect();



# ripped verbatim from args_extract.pl (except for using the fullextract
# sierra .inc file)
# extract_holdings_data_from_bibs.pl is using a modified version
# to pass 'use strict'
sub db_connect{
    my $db_mode = $_[0];
    if ($db_mode eq 'mill') {
        use  DBD::Oracle;
        $input = '/htdocs/connects/afton_iii_iiidba_perl.inc';

        open (INFILE, "<$input") || die &mail_error("Can't open Mill DB connects file\n");

        while (<INFILE>) {
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


        $dbh = DBI->connect("dbi:Oracle:host=$host;sid=$sid", $username, $password)
            or die &mail_error("Unable to connect: $DBI::errstr");

        # So we don't have to check every DBI call we set RaiseError.
        $dbh->{RaiseError} = 1;
    } elsif ($db_mode eq 'sierra') {
        use DBD::Pg;
        $input = '/scripts/endeca/bnums_test/afton_iii_sierra_perl2.inc';

        open (INFILE, "<$input") || die &mail_error("Can't open Sierra DB connects file\n");

        while (<INFILE>) {
            chomp;
            @pair = split("=", $_);
            $mycnf{$pair[0]} = $pair[1];
        }

        close(INFILE);

        my $host = $mycnf{"host"};
        my $port = $mycnf{"port"};
        my $dbname = $mycnf{"dbname"};
        my $username = $mycnf{"user"};
        my $password = $mycnf{"password"};

        # untaint all of the db connection variables
        if ($host =~ /^([-\@\w.]+)$/) {
            $host=$1;
        } else {
            die "Bad data in $host";
        }

        if ($port =~ /^([-\@\w.]+)$/) {
            $port=$1;
        } else {
            die "Bad data in $port";
        }

        if ($dbname =~ /^([-\@\w.]+)$/) {
            $dbname=$1;
        } else {
            die "Bad data in $dbname";
        }

        if ($username =~ /^([-\@\w.]+)$/) {
            $username=$1;
        } else {
            die "Bad data in $username";
        }


        $dbh = DBI->connect("dbi:Pg:host=$host;port=$port;dbname=$dbname", $username, $password)
            or die &mail_error("Unable to connect: $DBI::errstr");

        # So we don't have to check every DBI call we set RaiseError.
        $dbh->{pg_enable_utf8} = 1;
        $dbh->{RaiseError} = 1;
    }
}
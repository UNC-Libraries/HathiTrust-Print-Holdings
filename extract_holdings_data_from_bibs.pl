#!/usr/bin/perl
#
# Summary: Given a list of bnums (with material type) as input, determines whether data
#          should be included in HathiTrust holdings output. If so, outputs HT-required
#          data to the appropriate file.
#
# Usage: perl extract_holdings_data_from_bibs.pl [bnum file] [/dir/to/write/output/]
#
# Authors: Kristina Spurgin (June 2015 - )
#
# Dependencies:
#    /htdocs/connects/afton_iii_iiidba_perl.inc
#
# Important usage notes:
# UTF8 is the biggest factor in this script.  in addition to the use utf8
# declaration at the head of the script, we must also explicitly set the mode of
# any output to utf8.

#***********************************************************************************
# Declarations
#***********************************************************************************
use warnings;
use strict;

use Data::Dumper;

use DBI;
use  DBD::Oracle;
use utf8;
use locale;
use Net::SSH2;
use List::Util qw(first);

# set character encoding for stdout to utf8
binmode(STDOUT, ":utf8");

#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Faux "global" variables
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
my @excluded_item_locations = (
    'aadaa', #	Art Library CD-ROM
    'aadab', #	Art Library Compact Disc
    'aadac', #	Art Library Computer Disk 3 1/2
    'aadad', #	Art Library Digital Video Disc
    'aadae', #	Art Library Interactive Multimedia
    'aadaf', #	Art Library Microfiche
    'aadag', #	Art Library Microfilm
    'aadah', #	Art Library Videocassette
    'aana', # 	Art Library Vase Room
    'aaraa', #	Art Library Cage Kit
    'bbdaa', #	Science Library Annex Media Collection
    'bbdab', #	Science Library Annex Cassette
    'bbdac', #	Science Library Annex Computer Disk 3 1/2
    'bbdad', #	Science Library Annex Computer Disk 5 1/4
    'bbdae', #	Science Library Annex Interactive Multimedia
    'bbdaf', #	Science Library Annex Microfiche
    'bbdag', #	Science Library Annex Microfilm
    'bbdah', #	Science Library Annex Record
    'bbdaj', #	Science Library Annex Slide
    'bbdak', #	Science Library Annex Videocassette
    'bbdfa', #	Science Library Annex Office CD-ROM
    'bbdfb', #	Science Library Annex Office Computer Disk 3 1/2
    'bbdfc', #	Science Library Annex Office Digital Video Disc
    'bbdfd', #	Science Library Annex Office Interactive Multimedia
    'ccdaa', #	Kenan Science Library CD-ROM
    'ccdab', #	Kenan Science Library Cassette
    'ccdac', #	Kenan Science Library Microcard
    'ccdad', #	Kenan Science Library Microfiche
    'ccdae', #	Kenan Science Library Microfilm
    'dccb', # 	Davis Library Reference Desk Microfiche
    'dccda', #	Davis Library Reference Microcoard
    'dccdb', #	Davis Library Reference Microfiche
    'dccdc', #	Davis Library Reference Microfilm
    'dcce', # 	Davis Library Reference Fascicle File
    'dclka', #	Davis Library Reference Row 10 Microfiche
    'dclqa', #	Davis Library Reference Row 14 Microfiche
    'dcpfa', #	Davis Library Reference Federal Documents CD-ROM
    'dcpfb', #	Davis Library Reference Federal Documents Microfiche
    'dcpfc', #	Davis Library Reference Federal Documents Videocassette
    'dcpfi', #	Davis Ref Federal Documents Internet Resource
    'dcpwa', #	Davis Library Reference International Documents CD-ROM
    'dcpwb', #	Davis Library Reference International Docs Computer Disk 3 1/2
    'dcpwc', #	Davis Library Reference International Docs Microfiche
    'dcya', # 	Davis Library Reference Electronic Resources
    'dcyab', #	Davis Library Reference Electronic Resources CD-ROM
    'dcyac', #	Davis Library Reference Electronic Resources Computer Disk
    'dcyad', #	Davis Library Reference Electronic Resource Computer Disk 3 1/2
    'dcyae', #	Davis Library Reference Electronic Resources Computer Disk 5 1/4
    'dcyaf', #	Davis Library Reference Electronic Resources Interactive Multimedia
    'dcyag', #	Davis Library Reference E-Docs Archive CD-ROM
    'dcyb', # 	Davis Library Reference Electronic Archive
    'dcyba', #	Davis Library Reference Electronic Archive Computer Disk
    'dcybb', #	Davis Library Reference Electronic Archive Computer Disk 3 1/2
    'dcybc', #	Davis Library Reference Electronic Archive Computer Disk 5 1/4
    'dcybd', #	Davis Library Reference Electronic Archive Interactive Multimedia
    'dcyea', #	Davis Library Reference E-Docs
    'dcyeb', #	Davis Library Reference E-Docs CD-ROM
    'dcyec', #	Davis Library Reference E-Docs Computer Disk 3 1/2
    'dcyef', #	Davis Library Reference E-Docs Archive
    'dcyfa', #	Davis Library Reference Federal Internet Resource
    'ddcca', #	Davis Library (Non-circulating) Microfilm
    'dddae', #	Davis Library Video CD
    'dg', # 	Davis Library Microforms
    'dga9', # 	Not Yet Determined Microforms
    'dga', #@ 	Staff Use Only Microforms
    'dgaa', #	Staff Use Only Microfilm Master
    'dgab', #	Staff Use Only Microfilm Print Master
    'dgda', # 	Davis Microforms Coll
    'dgdaa', #	Davis Library Microfilm
    'dgdab', #	Davis Library Microcard
    'dgdac', #	Davis Library Microfilm Serial
    'dgdad', #	Davis Library Microform
    'dgdae', #	Davis Library Microfiche
    'dgdaf', #	Davis Library Microprint
    'dgdb', # 	Davis Library Microforms Folio
    'dgdba', #	Davis Library Microfilm Folio
    'dgdbb', #	Davis Library Microfiche Folio
    'dgdc', # 	Davis Library Microforms Folio-2
    'dgdca', #	Davis Library Microfilm Folio-2
    'dgdda', #	Davis Library Microfilm Use Copy
    'dgta', # 	Davis Library MNF (Ask at Circ Desk)
    'dgz', #	Davis Library Microforms Non-scoped
    'dndaa', #	Storage--Use Request Form Microfiche
    'dndab', #	Storage--Use Request Form Microfilm
    'dngaa', #	Storage(MFM)--Use Request Form Microfiche
    'dngab', #	Storage(MFM)--Use Request Form Microfilm
    'dngba', #	Storage(MFC)--Use Request Form Microfiche
    'dngbb', #	Storage(MFC)--Use Request Form Microfilm
    'dngca', #	Storage(MFD)--Use Request Form Microcard
    'dvtaa', #	Davis Library Preservation Microfilm
    'dy', # 	Davis Library Equipment
    'dyca', # 	Davis Library Laptop Storage
    'dywa', # 	Davis Library Wireless Card
    'dyz', #	Davis Library Equipment Non-Scoped
    'eb', # 	Electronic Book
    'ebna', # 	Electronic Book netLibrary
    'ebnb', # 	Electronic Book
    'ebz', #	Electronic Book Non-Scoped
    'ed', # 	Documenting the American South
    'edas', # 	Documenting the American South
    'edas', #@	Documenting the American South (staff us only)
    'er', # 	Electronic Resource
    'erda', # 	Electronic Resource--Lexis
    'erdb', # 	Electronic Resource--InfoTrac
    'erra', # 	Electronic Resource
    'errd', #	Online Data Set
    'erri', # 	Electronic Resource--Internet
    'erri', #@	Electronic Resource--Internet Do not Catalog
    'errs', #	Online Data Set
    'errw', #	Online Data Set
    'erz', #	Electronic Resources non-scoped
    'es', #	Electronic Streaming Media
    'estr', #	Electronic Streaming Media
    'ggla', # 	Geological Sciences Library Map Room Vertical File
    'gglaa', #	Geological Sciences Library Map Room Vertical File Map
    'gglb', # 	Geological Sciences Library Map Room
    'gglba', #	Geological Sciences Library Map Room Map
    'hhga', # 	Highway Safety Research Center Library Microfiche Documents
    'hhla', # 	Highway Safety Research Center Library Audiovisual Collection
    'hhya', # 	Highway Safety Research Center Library Electronic Access Local
    'hhyb', # 	Highway Safety Research Center Library Electronic Access Remote
    'jjdaa', #	Maps Collection CD-ROM
    'jjdab', #	Maps Collection Computer Disk 3 1/2
    'jjdac', #	Maps Collection Computer Disk 5 1/4
    'jjdad', #	Maps Collection Digital Video Disc
    'jjdae', #	Maps Collection Microfiche
    'jjdb', # 	Maps Collection Folio
    'jjdc', # 	Maps Collection Folio-2
    'jjdd', # 	Maps Collection Folio Oversize
    'jjde', # 	Maps Collection Folio 2 Oversize
    'jjdh', # 	Maps Collection Oversize Maps
    'jjea', # 	Maps Collection Horizontal Files
    'jjeb', # 	Maps Collection Vertical Files
    'jjeba', #	Maps Collection Vertical Files Microfiche
    'jjec', # 	Maps Collection Lateral File
    'jjed', # 	Maps Collection Historical Horizontal File
    'jjee', # 	Maps Collection Historical Vertical File
    'jjga', # 	Maps Collection Microforms
    'jjnb', # 	Maps Collection Annex Oversize Maps
    'jjnc', # 	Maps Collection Annex Oversize Volumes
    'jjnd', # 	Maps Collection Annex Horizontal Files
    'jjne', # 	Maps Collection Annex Vertical Files
    'jjraa', #	Maps Collection Cage Microfiche
    'jjya', # 	Maps Collection Electronic Resource
    'kdav', # 	Law Library Audio-Visual Documents Collection
    'kdcd', # 	Law Library CD-ROM Documents Collection
    'kdfc', # 	Law Library Microfiche Documents Collection
    'kdvd', # 	Law Library DVD Documents Collection
    'knav', # 	Law Library Audio-Visual
    'kncd', # 	Law Library CD-ROM
    'knfc', # 	Law Library Microfiche
    'knfci', #	Law Library Microfiche Index
    'knfm', # 	Law Library Microfilm
    'knfmi', #	Law Library Microfilm Index
    'knlv', # 	Law Library Leisure Video
    'knsc', # 	Law Library Software Collection
    'knvd', # 	Law Library DVD
    'kwec', # 	Law Library Electronic Instruction Center
    'kwer', # 	Law Library Electronic Resource
    'kwer2', #	Law Library Electronic Book
    'kweu', # 	Law Library Computer Lab
    'llbaa', #	Information & Library Science Library Reserve Microfilm
    'lldaa', #	Information & Library Science Library AV Cassette
    'lldab', #	Information & Library Science Library Cassette
    'lldad', #	Information & Library Science Library Computer Disk 3 1/2
    'lldae', #	Information & Library Science Library Computer Disk 5 1/4
    'lldaf', #	Information & Library Science Library Filmstrip
    'lldag', #	Information & Library Science Library Game
    'lldah', #	Information & Library Science Library Kit
    'lldaj', #	Information & Library Science Library Microfiche
    'lldak', #	Information & Library Science Library Microfilm
    'lldam', #	Information & Library Science Library Motion Picture
    'lldan', #	Information & Library Science Library Slide
    'lldao', #	Information & Library Science Library Sound Filmstrip
    'lldap', #	Information & Library Science Library Sound Slide Set
    'lldaq', #	Information & Library Science Library Videocassette
    'lldar', #	Information & Library Science Library Videotape
    'llha', # 	Information & Library Science Library Newsletter File
    'llla', # 	Information & Library Science Library A/V
    'lllaa', #	Information & Library Science Library AV Cassette
    'lllab', #	Information & Library Science Library AV Compact Disc
    'lllac', #	Information & Library Science Library AV Videocassette
    'lllad', #	Information & Library Science Library AV Cassette
    'lllae', #	Information & Library Science Library A/V Computer Software
    'lllaf', #	Information & Library Science Library AV Videocassette
    'mmbaa', #	Music Library Reserve Videocassette
    'mmea', # 	Music Library F-File
    'mmga', # 	Music Library Microfilm
    'mmgb', # 	Music Library Microfiche
    'mmgc', # 	Music Library Microcard
    'noha', # 	Health Sciences Library Educational Media
    'nohas', #	Health Sciences Library Slides
    'nohbo', #	HSL Historical Collection Artifacts
    'nohbs', #	HSL Historical Collection Sound Recordings
    'nohbt', #	HSL Historical Collection Visual Media
    'nohe', # 	Electronic Resource
    'noheb', #	Health Sciences Library Electronic Book
    'nohm', # 	Health Sciences Library Microfiche
    'nohmf', #	Health Sciences Library Microfilm
    'qqdaa', #	Math/Physics Library CD-ROM
    'qqdab', #	Math/Physics Library Cassette
    'qqdac', #	Math/Physics Library Computer Disk 3 1/2
    'qqdad', #	Math/Physics Library Computer Disk 5 1/2
    'qqdae', #	Math/Physics Library DVD
    'qqdaf', #	Math/Physics Library Microfiche
    'qqdag', #	Math/Physics Library Microfilm
    'qqdah', #	Math/Physics Library Sound Slide Set
    'qqdaj', #	Math/Physics Library Videocassette
    'qqdam', #	Math/Physics Library Videodisc
    'qqka', # 	Math/Physics Library Machine-Readable Data File
    'qqkaa', #	Math/Physics Library CD-ROM
    'qqkab', #	Math/Physics Library Computer Disk 3 1/2
    'qqkac', #	Math/Physics Library DVD
    'trsc', # 	NC Central
    'trsd', # 	Duke
    'trss', # 	NC State
    'truls', #	Media Resource Center Remote Storage
    'uadaa', #	Undergrad Library CD-ROM
    'uadac', #	Undergrad Library Interactive Multimedia
    'uadai', #	Undergrad Library Popular Reading (Entry Level)
    'ulbaa', #	Media Resources Center Reserve Videocassette
    'ulbab', #	Media Resources Center Reserve Compact Disc
    'ulbr', #	Media Resources Center Blu-ray Disc
    'ulcaa', #	Media Resources Center Reference CD-ROM
    'uldab', #	Media Resources Center Audiocassette
    'uldac', #	Media Resources Center Cassette
    'uldad', #	Media Resources Center CD-ROM
    'uldae', #	Media Resources Center Compact Disc
    'uldaf', #	Media Resources Center DVD-ROM
    'uldag', #	Media Resources Center Digital Videodisc
    'uldah', #	Media Resources Center Electronic Resource
    'uldaj', #	Media Resources Center Filmstrip
    'uldak', #	Media Resources Center Interactive Multimedia
    'uldal', #	Media Resources Center Library Use Only
    'uldam', #	Media Resources Center Kit
    'uldan', #	Media Resources Center Laser Disc
    'uldao', #	Media Resources Center Motion Picture
    'uldap', #	Media Resources Center Record
    'uldaq', #	Media Resources Center Slides
    'uldar', #	Media Resources Center Sound Cassette
    'uldas', #	Media Resources Center Sound Disc
    'uldat', #	Media Resources Center Sound Filmstrip
    'uldau', #	Media Resources Center Sound Recording
    'uldav', #	Media Resources Center Sound Slide Set
    'uldaw', #	Media Resources Center Video CD
    'uldax', #	Media Resources Center Video Digital Disc
    'ulday', #	Media Resources Center Videocamera
    'uldaz', #	Media Resources Center Videocassette
    'uldc', # 	Media Resources Center Equipment
    'uldd', # 	Media Resources Center Audiobooks
    'vadaa', #	School of Government Library CD-ROM
    'vadab', #	School of Government Library Microcard/fiche
    'wbcc', # 	North Carolina Collection Online
    'wbdaa', #	North Carolina Collection Cassette
    'wbdab', #	North Carolina Collection Game
    'wbdac', #	North Carolina Collection Map Folio
    'wbdad', #	North Carolina Collection Maps
    'wbdae', #	North Carolina Collection Microcard
    'wbdaf', #	North Carolina Collection Microfiche
    'wbdag', #	North Carolina Collection Microfilm
    'wbdah', #	North Carolina Collection Microform
    'wbdaj', #	North Carolina Collection Record
    'wbdak', #	North Carolina Collection Sheet
    'wbdam', #	North Carolina Collection Videocassette
    'wbdba', #	North Carolina Collection Folio Microfilm
    'wbga', # 	North Carolina Collection Photo Archives
    'wbpaa', #	North Carolina Collection State Docs Collection Microfiche
    'wbpab', #	North Carolina Collection State Docs Collection Online
    'wbwaa', #	North Carolina Collection Wolfe Microfilm
    'wcdg', # 	Rare Book Collection LP Record
    'wcdh', # 	Rare Book Collection Audiocassette
    'wcdj', # 	Rare Book Collection CD
    'wcdk', # 	Rare Book Collection Photos
    'wcdl', #	Rare Book Collection Newspapers
    'wcdm', # 	Rare Book Collection DVD
    'wcdn', # 	Rare Book Collection Videocassettes
    'wcdt', #	Rare Book Collection Tabloids
    'wchq', # 	Rare Book Collection Beats Photos
    'wcpe', # 	Rare Book Collection Patton Photos
    'wcrp', #	Rare Book Collection 45RPMs
    'xcac', #	Carolina Population Center Library Electronic Resources Internet CPC
    'xcad', #	Carolina Population Center Library Electronic Resource
    'xcea', #	Carolina Population Center Library Reports, Offprints, Papers
    'xceb', #	Carolina Population Center Library Area Files Cabinets
    'yadaa', #	K-12 International Resource Library Videocassettes
    'yccaa', #	Graduate Funding Information Center Reference CD-ROM
    'yccab', #	Graduate Funding Information Center Reference Cassette
    'yccac', #	Graduate Funding Information Center Reference Kit
    'yccad', #	Graduate Funding Information Center Reference Video
    'yccae', #	Graduate Funding Information Center Reference Videocassette
    'yccaf', #	Graduate Funding Information Center Reference DVD
    'yccag', #	Graduate Funding Information Center Reference Non-Music CD
    'ycdaa', #	Graduate Funding Information Center Cassette
    'ycdab', #	Graduate Funding Information Center Kit
    'ycdac', #	Graduate Funding Information Center Video
    'ycdad', #	Graduate Funding Information Center Videocassette
    'ycdae', #	Graduate Funding Information Center Library CD-Rom
    'ycdaf', #	Graduate Funding Information Center Library DVD
    'ycdag', #	Graduate Funding Information Center Non-Music CD
    'ydka', # 	Park Library Posters
    'ydla', # 	Park Library Multimedia
    'ydya', #	Park Library Electronic Resource
    'yhda', #	Latin American Film Library
    'yhdc', #	Latin American Film Library Reference
    'yhz', #	Latin American Film Library nonscoped
);

my %excluded_item_location_lookup;
foreach (@excluded_item_locations) {
    $excluded_item_location_lookup{$_} = 1;
};

my %item_type_decision_lookup = (
     0   => 'y', #Book
     1   => 'y', #Non-circ book
     2   => 'y', #Serial
     3   => 'y', #Non-circ serial
     4   => 'n', #Art original
     5   => 'n', #Art Reproduction
     6   => 'n', #A-V
     7   => 'y', #Braille
     8   => 'n', #Broadside
     9   => 'n', #CD-ROM
     10  => 'n', #Chart
     11  => 'n', #Computer file
     12  => 'n', #Database
     13  => 'n', #Misc
     14  => 'n', #Diskette
     15  => 'n', #Drawing
     16  => 'n', #Filmstrip
     17  => 'n', #Flash card
     18  => 'n', #Game
     19  => 'n', #Globe
     20  => 'y', #Government Document
     21  => 'n', #Interactive
     22  => 'y', #Juvenile - books are included
     23  => 'n', #Kit
     24  => 'y', #Manuscript
     25  => 'y', #Map - Atlases are coded this way
     26  => 'n', #Microcard
     27  => 'n', #Microfiche
     28  => 'n', #Microfilm
     29  => 'n', #Microform
     30  => 'n', #Microslide
     31  => 'n', #Model
     32  => 'n', #Motion picture
     33  => 'y', #New book
     34  => 'y', #Other - Includes missing monograph volumes, etc.
     35  => 'n', #Pamphlet
     36  => 'n', #Photograph
     37  => 'n', #Picture
     38  => 'y', #Picture book
     39  => 'n', #Postcard
     40  => 'n', #Poster
     41  => 'n', #Print
     42  => 'n', #Realia
     43  => 'y', #Reference
     44  => 'y', #2 Hour
     45  => 'y', #Score
     46  => 'n', #Slide
     47  => 'n', #Software
     48  => 'n', #Sound cassette
     49  => 'n', #Sound CD
     50  => 'n', #Sound recording
     51  => 'n', #Technical drawing
     52  => 'y', #Thesis
     53  => 'n', #Toy
     54  => 'n', #Transparency
     55  => 'n', #Uncataloged material - If uncataloged, should not have OCLC number
     56  => 'n', #Video cartridge
     57  => 'n', #Video cassette
     58  => 'n', #Video disc
     59  => 'n', #Video recording
     60  => 'n', #DVD
     61  => 'n', #Laptop
     62  => 'n', #Browse - don't include things we don't own... 
     63  => 'n', #Key
     64  => 'n', #Wireless NIC
     65  => 'n', #Carrel Key
     66  => 'n', #Serial temp - no items of this type in catalog 2013-09-25, can't evaluate
     67  => 'n', #Microfilm (Master)
     68  => 'n', #Microfilm (Print-M)
     69  => 'n', #Microfilm (Use)
     70  => 'n', #Blu-ray
     71  => 'y', #2 Hour in Library Use Only
     72  => 'y', #24 Hour
     73  => 'y', #7 Day
     74  => 'y', #1 Day
     75  => 'y', #3 Day
     76  => 'n', #Streaming Video
     77  => 'n', #R&IS Gadget
     78  => 'y', #Artist's Book
     79  => 'y', #Auction Catalog
     80  => 'y', #4 Hour
     81  => 'y', #4 Hour in Library Use Only
     82  => 'n', #3 Hour In MRC Use Only - probably will be weeded out by format, but they may have books...
     83  => 'y', #3 Hour In Library Use Only
     116 => 'n', #Non coop - no items of this type in catalog 2013-09-25, can't evaluate
);

my %item_status_decision_lookup = (
     '' => 'CH', #Blank, assumed available
     ' ' => 'CH', #Blank, assumed available
     '!' => 'CH', #On holdshelf
     '$' => 'LM', #Lost and paid
     '%' => 'CH', #ILL/INN-Reach
     '-' => 'CH', #Available
     a   => 'CH', #Contact MRC to reserve
     b   => 'CH', #Backlogged
     c   => 'LM', #Claims lost
     d   => 'LM', #Declared lost
     e   => 'CH', #In process at the LSC
     f   => 'LM', #Never received
     g   => 'CH', #Ask the MRC
     j   => 'CH', #Contact LAFL for status
     m   => 'LM', #Missing
     n   => 'LM', #Billed
     o   => 'CH', #Lib use only
     p   => 'CH', #In process
     r   => 'CH', #In repair
     s   => 'LM', #On search
     t   => 'CH', #In transit
     u   => 'CH', #Staff use only
     w   => 'WD', #Withdrawn
     z   => 'LM', #Clms retd
);

#************************************************************************************
# Set up environment and make sure it is clean
#************************************************************************************
$ENV{'PATH'} = '/bin:/usr/sbin';
delete @ENV{'ENV', 'BASH_ENV'};
$ENV{'NLS_LANG'} = 'AMERICAN_AMERICA.AL32UTF8';

my($db_handle, $statement_handle, $sql);

my $input = '/htdocs/connects/afton_iii_iiidba_perl.inc';
my %mycnf;

open (INFILE, "<$input") || die("Can't open hidden file\n");
  while (<INFILE>){
    chomp;
    my @pair = split("=", $_);
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


$db_handle = DBI->connect("dbi:Oracle:host=$host;sid=$sid", $username, $password)
        or die("Unable to connect: $DBI::errstr");

# So we don't have to check every DBI call we set RaiseError.
$db_handle->{RaiseError} = 1;

my $start_time = get_timestamp();


#set bnum list
#####################
my $bnum_file = $ARGV[0];
#####################

# set up files to write output
# HT wants separate files for single-volume monographs, multi-volume monographs, and serials 
# the single most crucial part of this script is to specify the output format as utf8
my $mono_path = $ARGV[1] . "/svmonos.txt";
my $mvmono_path = $ARGV[1] . "/mvmonos.txt";
my $serial_path = $ARGV[1] . "/serials.txt";
my $exclude_path = $ARGV[1] . "/exclude.txt";
my $warning_path = $ARGV[1] . "/warning.txt";
my $done_path = $ARGV[1] . "/done.txt";
my $stat_path = $ARGV[1] . "/stat.txt";

my $filenum = $ARGV[1];
$filenum =~ s/hout_([0-9]+)/$1/;

my $log_path = $filenum . ".out";

open(SVMONOS, ">>:utf8", $mono_path) or die("Couldn't open $mono_path for output: $!\n");
open(MVMONOS, ">>:utf8", $mvmono_path) or die("Couldn't open $mvmono_path for output: $!\n");
open(SERIALS, ">>:utf8", $serial_path) or die("Couldn't open $serial_path for output: $!\n");
open(EXCLUDES, ">>:utf8", $exclude_path) or die("Couldn't open $exclude_path for output: $!\n");
open(WARNING, ">>:utf8", $warning_path) or die("Couldn't open $warning_path for output: $!\n");
open(DONE, ">>:utf8", $done_path) or die("Couldn't open $done_path for output: $!\n");
open(STAT, ">>:utf8", $stat_path) or die("Couldn't open $stat_path for output: $!\n");
open(LOGFILE, ">>:utf8", $log_path) or die("Couldn't open $log_path for output: $!\n");

print LOGFILE "$ARGV[0]: Started $start_time\n";

# get number of lines in file (for realtime progress reporting)
my $number_of_bnums = 0;
open(BNUMS, $bnum_file) or die "Can't open `$bnum_file': $!";
while (sysread BNUMS, my $buffer, 4096) {
    $number_of_bnums += ($buffer =~ tr/\n//);
    }
close BNUMS;

#******************************************
# Get MARC data for deduped bnum file
#******************************************
open (BNUMS, "<$bnum_file") || die("Can't open bnum file: $bnum_file\n");

my $on_bnum = 0;

BIB: while (<BNUMS>){
    chomp;
    my ($bnum, $mat_type) = split(/\t/, $_) ;
    $on_bnum++;
    print DONE "$bnum\n";
    #Print progress line
    if ($on_bnum % 1000 == 0) {
        my $progress = 100 * $on_bnum / $number_of_bnums;
        print LOGFILE "$ARGV[0]: $on_bnum of $number_of_bnums ($progress%) complete.\n";
    }

    #set up bib-level HT output values for future use
    my $HT_category = '';
    my $HT_OCLCnum = '';
    my $HT_holding_status = '';
    my $HT_condition = '';
    my $HT_item_data = '';
    my $HT_issn = '';
    my $HT_gov_doc = '';

    #get basic bib data to start
    my %basic_bib_data = get_basic_bib_data($bnum);
    my $ldr = $basic_bib_data{'ldr'};
    my $b001 = $basic_bib_data{'b001'};
    my $b007 = $basic_bib_data{'b007'};
    my $b008 = $basic_bib_data{'b008'};
    my $b022 = $basic_bib_data{'b022'};
    my $b035 = $basic_bib_data{'b035'};
    my $b074 = $basic_bib_data{'b074'};
    my $b245 = $basic_bib_data{'b245'};
    my $b300 = $basic_bib_data{'b300'};
    my $b338 = $basic_bib_data{'b338'};
    my $b915 = $basic_bib_data{'b915'};
    my $b919 = $basic_bib_data{'b919'};

    my $rec_type = '';

    #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    #check for certain values in 915
    #BROWSE = leased print books
    #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    if ($b915 =~ m/browse/i) {
        print EXCLUDES "$bnum\t\tIneligible based on 915 value\t$b915\n";
        next BIB;
    }

    #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    #check for certain values in 919
    #dwsgpo = online gov docs, many otherwise coded as print
    #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    if ($b919 =~ m/dwsgpo/i) {
        print EXCLUDES "$bnum\t\tIneligible based on 919 value\t$b919\n";
        next BIB;
    }

    #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    #check for OCLC number
    #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    my $oclc_num = get_oclc_number(no_subfield_a($b001), $b035);
    if ($oclc_num eq 'none') {
            print EXCLUDES "$bnum\t\tNo OCLC number\t\n";
            next BIB;
        }
    else {
        $HT_OCLCnum = $oclc_num;
    }

    #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    #check for archival control in leader
    #exclude records coded a - HT doesn't want records for archival collections
    #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    my $control_type = substr($ldr, 8, 1);
    if ($control_type eq 'a') {
        print EXCLUDES "$bnum\t\tArchival control\t\n";
        next BIB;
    }

    #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    #check bibliographic level in leader
    #after exclusion logic, another process comes round and uses this
    # to figure out what HT category to put each included bib in.
    #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    my $blvl = substr($ldr, 7, 1);
    my $blvl_cat = '';
    my %blvl_decisions = (
        a => 'no',
        b => 'no',
        c => 'mono',
        d => 'no',
        i => 'mono',
        m => 'mono',
        s => 'ser',
        );

    if (exists $blvl_decisions{$blvl}){
        $blvl_cat = $blvl_decisions{$blvl};
    }
    else {
        print EXCLUDES "$bnum\t\tInvalid blvl in LDR\t$blvl\n";
        next BIB;
    }

    if ($blvl_cat eq 'no'){
        print EXCLUDES "$bnum\t\tIneligible blvl from LDR\t$blvl\n";
        next BIB;
    }

    #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    #check for indications of microform format in bib record
    #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    if ($b245 =~ m/\|h\s*\[micro/){
        print EXCLUDES "$bnum\t\tMicroform GMD\t\n";
        next BIB;
    }

    if ($b338 =~ m/aperture card|micro(fiche|film|opaque)/i){
        print EXCLUDES "$bnum\t\tMicroform 338\t\n";
        next BIB;
    }

    if ($b007 =~ m/^h/){
        print EXCLUDES "$bnum\t\tMicroform 007\t\n";
        next BIB;
    }

    #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    #Check record type from leader
    #Returns list: type code, decision
    #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    my $rec_type_code = substr($ldr, 6, 1);

    my %rec_type_decisions = (
        a => 'ok',
        c => 'ok',
        d => 'ok',
        e => 'ok',
        f => 'no',
        g => 'no',
        i => 'no',
        j => 'no',
        k => 'no',
        m => 'no',
        o => 'no',
        p => 'ok',
        r => 'no',
        t => 'ok',
    );

    my $rec_type_decision;
    if (exists $rec_type_decisions{$rec_type_code}){
        $rec_type_decision = $rec_type_decisions{$rec_type_code};
    }
    else {
        print EXCLUDES "$bnum\t\tInvalid record type (from LDR)\t$rec_type_code\n";
        next BIB;
    }

    if ($rec_type_decision eq 'ok') {
        $rec_type = $rec_type_code;
    }
    elsif ($rec_type_decision eq 'no') {
        print EXCLUDES "$bnum\t\tIneligible record type (from LDR)\t$rec_type_code\n";
        next BIB;
    }

    #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    #Check physical description terms
    #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    my $desc = get_subfield_a($b300);
    if (   $desc =~ m/box(?:es|)/i
        || $desc =~ m/items?/i
        || $desc =~ m/pamphlets?/i
        || $desc =~ m/pieces?/i
        || $desc =~ m/sheets?/i) {
             print EXCLUDES "$bnum\t\tPhysical description\t$desc\n";
             next BIB;
         }

    #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    # The bib has passed all initial tests!
    # Count attached items and holdings records
    #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    my $num_holdings;
    my $num_items = count_items($bnum);
    if ($num_items == 0) {
        $num_holdings = count_holdings($bnum);
        if ($num_holdings == 0) { #no items, no holdings
            print EXCLUDES "$bnum\t\tNo items or holdings attached\t\n";
            next BIB;
        }
    }

    #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    #Set gov doc indicator (from bib) on every eligible bib
    #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    $HT_gov_doc = is_fed_gov_doc($b074);

    #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    # If it is a serial that has at least one attached item or holdings record
    # We don't even need to look at items and holdings!
    #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    if ($blvl_cat eq 'ser') {
        $HT_category = 'serial';

        #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
        #Get ISSN
        #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
        my $issn = get_subfield_a($b022);
        if ($issn) {
            $HT_issn = $issn;
        }

        print SERIALS "$HT_OCLCnum\t$bnum\t$HT_issn\t$HT_gov_doc\n";
        next BIB;
    } #END serials processing loop!

    #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    # For monographs, figure out if it's single-volume or multi-volume
    # This requires looking at item record data
    #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    my %item_data;
    if ($num_items > 0) {
        %item_data = get_item_data($bnum);

        #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
        # There may be no *elible* item records gathered, so check
        #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
        my $num_eligible_items = scalar keys %item_data;

        if ($num_eligible_items == 0) {
            print EXCLUDES "$bnum\t\tNo eligible items (has ineligible items)\t\n";
            next BIB;
        }

        #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
        # Otherwise, we are ready to determine whether we have a single-volume
        #  or multi-volume monograph on this bib.
        #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
        elsif ($num_eligible_items == 1) {
            $HT_category = 'sv mono';
        }
        # Counts unique volume designation values if >1 eligible items
        # Categorizes as multivolume if there are >1 unique volume designations on all eligible items
        else {
            my @vols;
            foreach my $key(keys %item_data){
                push(@vols, $item_data{$key}{ivolume});
            }
            my $num_uniq_vols = count_uniq_array_elements(@vols);
            if ($num_uniq_vols == 1) {
                $HT_category = 'sv mono';
            }
            elsif ($num_uniq_vols > 1) {
                $HT_category = 'mv mono';
            }
            else {
                print WARNING "$bnum\t\tPossible trouble with counting unique volume designations\t\n";
            }
        }
    }
    else {
        print EXCLUDES "$bnum\t\tNo attached items\t\n";
        next BIB;
    }

    #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    # Set fed gov doc indicator from item location for monographs
    #  if it isn't already set from bib.
    #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    if ($HT_gov_doc == 0) {
        my @locs;
        foreach my $key(keys %item_data){
            push(@locs, $item_data{$key}{ilocation});
        }

        my %federal_doc_item_locations = (
            dcpf => 1,
            dcpf9 => 1,
            vapa => 1,
        );

        foreach my $loc(keys %federal_doc_item_locations){
            if (grep(/^$loc$/, @locs)) {
                $HT_gov_doc = 1;
            }
        }
    }

    #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    # Print HT data to appropriate monograph files!
    #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    foreach my $item(keys %item_data){
        my $holdstat = $item_data{$item}{holdingsstatus};
        my $condition = $item_data{$item}{condition};
        my $volnum = $item_data{$item}{ivolume};
        if ($HT_category eq 'sv mono') {
            print SVMONOS "$HT_OCLCnum\t$bnum\t$holdstat\t$condition\t$HT_gov_doc\n";
        }
        elsif ($HT_category eq 'mv mono') {
            print MVMONOS "$HT_OCLCnum\t$bnum\t$holdstat\t$condition\t$volnum\t$HT_gov_doc\n";
        }
    }
} #END BIB processing loop

close(BNUMS);
$db_handle->disconnect();
close(SVMONOS);
close(MVMONOS);
close(SERIALS);
close(EXCLUDES);
close(WARNING);
my $end_time = get_timestamp();
print LOGFILE "$ARGV[0]: Finished $end_time\n";
print STAT "$ARGV[0]\t$number_of_bnums\t$start_time\t$end_time\n";
close(STAT);
close(LOGFILE);

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# SUBROUTINES
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#Counts number of internal notes in item record containing string: brittle
sub count_brittle_item_notes {
    my $inum = $_[0];
    my $note_count = '';
    my $mil_note_count_query = "select count(rec_data)
                            from var_fields2
                            where rec_key = '$inum'
                            and iii_tag = 'x'
                            and upper(rec_data) like '%BRITTLE%'"; #CONVERTED
    my $note_count_query = "select count(field_content)
                            from sierra_view.varfield
                            where record_id = '$i_id'
                            and varfield_type_code = 'x'
                            and upper(field_content) like '%BRITTLE%'";
    my $note_count_handle = $db_handle->prepare($note_count_query);
    $note_count_handle->execute();
    my $note_count_temp;
    $note_count_handle->bind_columns (undef, \$note_count_temp );

    while ($note_count_handle->fetch()){
        $note_count = $note_count_temp;
    }
    return $note_count;
}

sub count_holdings {
    my $bnum = $_[0];
    my $holdings_count = '';
    my $mil_holdings_count_query = "select count (lr.link_rec) from link_rec2 lr, holdings2base h
                            where lr.rec_key = '$bnum'
                            and (lr.link_rec like 'c%')
                            and lr.link_rec = h.rec_key"; #CONVERTED -- are there cases where linking's emssed up?'
    my $holdings_count_query = "select count (bl.holding_record_id)
                            from sierra_view.bib_record_holding_record_link bl
                            where bl.bib_record_id = '$bib_id'";
    my $holdings_count_handle = $db_handle->prepare($holdings_count_query);
    $holdings_count_handle->execute();
    my $holdings_count_temp;
    $holdings_count_handle->bind_columns (undef, \$holdings_count_temp );

    while ($holdings_count_handle->fetch()){
        $holdings_count = $holdings_count_temp;
    }
    return $holdings_count;
}

sub count_items {
    my $bnum = $_[0];
    my $item_count = '';
    my $mil_item_count_query = "select count (lr.link_rec) from link_rec2 lr, item2base i
                            where lr.rec_key = '$bnum'
                            and (lr.link_rec like 'i%')
                            and lr.link_rec = i.rec_key"; #CONVERTED -- are there cases where linking's emssed up?'
    my $item_count_query = "select count (bl.item_record_id)
                            from sierra_view.bib_record_item_record_link bl
                            where bl.bib_record_id = '$bib_id'";
    my $item_count_handle = $db_handle->prepare($item_count_query);
    $item_count_handle->execute();
    my $item_count_temp;
    $item_count_handle->bind_columns (undef, \$item_count_temp );

    while ($item_count_handle->fetch()){
        $item_count = $item_count_temp;
    }
    return $item_count;
}

sub count_uniq_array_elements {
    my @array = @_;
    return scalar keys %{{ map {$_ => 1 } @array }};
}

sub decide_item_code2 {
    my $code = $_[0];
    my $decision;
    my %code_table = (
        '' => 'y',
        ' ' => 'y',
        '-' => 'y',
        n => 'y', #Suppress
        b => 'y', #Bound with
        l => 'y', #Linked
        t => 'n', #To be linked
        );
    if (exists $code_table{$code}){
        $decision = $code_table{$code};
    }
    else {
        $decision = 'invalid';
    }
    return $decision;
}

sub decide_item_type {
    my $code = $_[0];
    my $decision;
    if (exists $item_type_decision_lookup{$code}) {
        $decision = $item_type_decision_lookup{$code};
    }
    else {
        $decision = 'invalid';
    }
    return $decision;
}

sub get_basic_bib_data {
    my $bnum = $_[0];
    my $iii_tag = '';
    my $marc_tag = '';
    my $rec_data = '';
    my $bib_id = '';
    $bib_id = get_sierra_rec_id($rec_key);

    my %basic_bib_data = (
                          'bnum' => $bnum,
                          'ldr'  => '',
                          'b001' => '',
                          'b007' => '',
                          'b008' => '',
                          'b022' => '',
                          'b035' => '',
                          'b074' => '',
                          'b245' => '',
                          'b300' => '',
                          'b338' => '',
                          'b915' => '',
                          'b919' => '',
                          );

    my $mil_query = "select iii_tag, marc_tag, rec_data
                 from var_fields2 where
                 rec_key = '$bnum'
                 and
                   (iii_tag = '_'
                    or marc_tag in ('001', '007', '008', '245', '300', '338', '915', '919')
                    or (marc_tag = '035' and rec_data like '%|a(OCoLC)%')
                    or (marc_tag in ('022', '074') and rec_data like '%|a%')
                   )"; #CONVERTED
    my $query =
        "select varfield_type_code, marc_tag, field_content
        from sierra_view.varfield
        where record_id = '$bib_id'
            and (varfield_type_code = '_'
                or marc_tag in ('001', '007', '008', '245', '300', '338', '915', '919')
                or (marc_tag = '035' and field_content like '%|a(OCoLC)%')
                or (marc_tag in ('022', '074') and field_content like '%|a%')
            )";

    my $query_handle = $db_handle->prepare($query);
    $query_handle->execute();
    $query_handle->bind_columns (undef, \$iii_tag, \$marc_tag, \$rec_data );

    while ($query_handle->fetch()) {
        if ($marc_tag) {
            if ($basic_bib_data{'b' . $marc_tag} eq '') {
                $basic_bib_data{'b' . $marc_tag} = trim($rec_data);
            }
        }
        else {
            $basic_bib_data{'ldr'} = $rec_data;
        }
    }
    return %basic_bib_data;
} #end sub get_basic_bib_data

sub get_sierra_rec_id {
    my $the_key = $_[0];
    $the_key =~ s/^.//s;
    my $rec_id_sql = "select id from sierra_view.record_metadata
                     where record_num = '$the_key' and record_type_code = 'b'";
    my $rec_id_sth = $db_handle->prepare($rec_id_sql);
    $rec_id_sth->execute();
    my $the_id;
    $rec_id_sth->bind_columns (undef, \$the_id );
    while ($rec_id_sth->fetch()) {
    }
    $rec_id_sth->finish();
    return $the_id;
}

sub get_item_data {
    my $bnum = $_[0];
    my %item_hash; #gathered data for all items on this bib
    my $mil_iquery = "select i.rec_key,
                         i.copy_num,
                         i.icode2,
                         i.i_type,
                         i.location,
                         i.status,
                         i.imessage
                  from link_rec2 l,
                       item2base i
                  where l.rec_key = '$bnum'
                  and i.rec_key = l.link_rec"; #CONVERTED
    my $iquery = "select 'i' || rm.record_num,
                    i.record_id,
                    i.copy_num,
                    i.icode2,
                    i.itype_code_num,
                    i.location_code,
                    i.item_status_code,
                    i.item_message_code
                from sierra_view.item_record i
                    inner join sierra_view.bib_record_item_record_link bl on bl.item_record_id = i.id
                    inner join sierra_view.record_metadata rm on rm.id = i.id
                where bl.bib_record_id = '$bib_id'";

    my $iquery_handle = $db_handle->prepare($iquery);
    $iquery_handle->execute();
    my ($inum, $i_id, $copy_num, $icode2, $itype, $ilocation, $istatus, $imessage, $inote, $ivolume) = '';
    $iquery_handle->bind_columns (undef, \$inum, \$i_id, \$copy_num, \$icode2, \$itype, \$ilocation, \$istatus, \$imessage );

  ITEM: while ($iquery_handle->fetch()) {
        #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
        # Test item eligibility based on item code 2 value
        #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
        if ($icode2 eq '^@') {
            $icode2 = '-';
        }
        my $icode2_decision = decide_item_code2($icode2);
        if ($icode2_decision eq 'n') {
            print EXCLUDES "$bnum\t$inum\tIneligible item code 2\t$icode2\n";
            next ITEM;
        }
        elsif ($icode2_decision eq 'invalid') {
            print EXCLUDES "$bnum\t$inum\tInvalid item code 2\t$icode2\n";
            next ITEM;
        }

        #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
        # Test item eligibility based on item type value
        #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
        my $itype_decision = decide_item_type($itype);
        if ($itype_decision eq 'n') {
            print EXCLUDES "$bnum\t$inum\tIneligible item type\t$itype\n";
            next ITEM;
        }
        elsif ($itype_decision eq 'invalid') {
            print EXCLUDES "$bnum\t$inum\tInvalid item type\t$itype\n";
            next ITEM;
        }

        #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
        # Test item eligibility based on item location value
        #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
        $ilocation = trim($ilocation);
        if (exists $excluded_item_location_lookup{$ilocation}) {
            print EXCLUDES "$bnum\t$inum\tIneligible item location\t$ilocation\n";
            next ITEM;
        }

        #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
        #This item is eligible for inclusion.
        #Set the pieces of data we got from item2base
        #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
        $item_hash{$inum}{itype} = $itype;
        $item_hash{$inum}{icode2} = $icode2;
        $item_hash{$inum}{ilocation} = $ilocation;
        $item_hash{$inum}{copy_num} = $copy_num;
        $item_hash{$inum}{condition} = '';
        $item_hash{$inum}{ivolume} = '';

        #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
        #Set condition indicator
        #If item location is trbrs, we will already know it is brittle
        #If item location is not trbrs, query for any notes containing the string brittle
        #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
        if ($ilocation eq 'trbrs') {
            $item_hash{$inum}{condition} = 'BRT';
        }
        else {
             my $brittle_note_count = count_brittle_item_notes($inum);
             if  ($brittle_note_count > 0) {
                 $item_hash{$inum}{condition} = 'BRT';
             }
        }

        #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
        # if condition isn't already set to BRT, check item message for d (damaged)
        #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
        if ($item_hash{$inum}{condition} ne 'BRT' && $imessage eq 'd') {
            $item_hash{$inum}{condition} = 'BRT';
        }

        #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
        # Set holdings status
        #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
        if (exists $item_status_decision_lookup{$istatus}) {
            $item_hash{$inum}{holdingsstatus} = $item_status_decision_lookup{$istatus};
        }
        else {
            $item_hash{$inum}{holdingsstatus} = 'CH';
            print WARNING "$bnum\t$inum\tInvalid item status\t$istatus\n";
        }

        #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
        #Set item volume designator, if present
        #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
        my $vol = get_item_volume($inum);

        if ($vol) {
            $item_hash{$inum}{ivolume} = trim($vol);
        }
    } #END ITEM processing
    return %item_hash;
} #end get_item_data

sub get_item_volume {
    my $inum = $_[0];
    my $ivol = '';
    my $mil_ivol_query = "select rec_data
                            from var_fields2
                            where rec_key = '$inum'
                            and iii_tag = 'v'
                            and rownum = 1"; #converted
    my $ivol_query = "select field_content
                            from sierra_view.varfield
                            where record_id = '$i_id'
                            and varfield_type_code = 'v'
                            limit 1";
    my $ivol_handle = $db_handle->prepare($ivol_query);
    $ivol_handle->execute();
    my $ivol_t;
    $ivol_handle->bind_columns (undef, \$ivol_t );

    while ($ivol_handle->fetch()){
        $ivol = $ivol_t;
    }
    return $ivol;
}

sub get_oclc_number {
    my $b001 = $_[0];
    my $b035 = $_[1];
    my $oclc_number = '';

    #If the 001 value is digits only, or has OCLC prefix, return it as OCLC number
    #If the 001 value has other alphabetic prefix or suffix, it is considered not to be an OCLC number
    if ($b001 =~ /^(o(c[mn]|[ln])|)\d+$/) {
            $oclc_number = $b001;
        }
    #If there is no 001, and 035 is not empty
    #Assign the first 035 |a with OCLC code as OCLC number...
    elsif ($b035) {
        $b035 =~ s/(\|a\(OCoLC\))(\d+).*/$2/;
        $oclc_number = $b035;
    }
    #If neither of the above conditions is met, OCLC number = none
    else {$oclc_number = 'none';}
    return $oclc_number;
}

sub get_subfield_a {
    my $data = $_[0];
    $data =~ s/^\|a([^|]*)\|?.*/$1/;
    return $data;
}

sub is_excluded_item_location {

}

sub is_fed_gov_doc {
    my $gpo_num = get_subfield_a($_[0]);
    if ($gpo_num) {
        return 1
    }
    else {
        return 0
    }
}

sub no_subfield_a {
    my $data = $_[0];
    $data =~ s/^\|a(.*)$/$1/;
    return $data;
}

# Remove leading and trailing whitespace
sub trim{
  my $incoming = $_[0];
  $incoming =~ s/^\s+//g;
  $incoming =~ s/\s+$//g;
  return $incoming;
}

sub get_timestamp {
my ($sec, $min, $hour, $day, $month, $year) = (localtime)[0..5];
$year += 1900;
$month++;
$month = (length($month) == 1 ? "0" . $month : $month );
$day = (length($day) == 1 ? "0" . $day : $day );
$min = (length($min) == 1 ? "0" . $min : $min );
$hour = (length($hour) == 1 ? "0" . $hour : $hour );
$sec = (length($sec) == 1 ? "0" . $sec : $sec );

return "$month/$day/$year $hour:$min:$sec"
}

exit;

# HathiTrust-Print-Holdings
Produce print holdings reports in format required by HathiTrust by querying III Millennium Oracle database

HathiTrust is now requiring at least annual submission of our print holdings data. 

Information about the reasons they require this, and the data format they require are [http://www.hathitrust.org/print_holdings here].

Submitting this data more frequently than annually could be in our interest; submission of information on our lost, damaged, or brittle print holdings may gain us online access to material we currently cannot access. 

To extract this data manually even once a year would be onerous and error-prone. The benefits of submitting the information more frequently further call for an automated process (script(s) that will extract this data from the III Oracle database and mash it into Hathi's required format). 

This page documents: 
* What the scripts do (high level)
* How to run them
* The detailed logic and development of these scripts

## About the scripts
The scripts fall into '''two categories''':
* logic/data scripts -- Perl scripts that connect to the III Oracle catalog database, extract data, and process it into the format HT requires, based on specified logic. The user doesn't interact directly with these scripts. 
* control scripts -- shell scripts used to run/control the logic/data scripts. The user interacts directly with these scripts.

## Control script details
### control.sh
This is the main control script. It:
* cleans any previous holdings processing files out of the hathi directory on the server
* runs get_bib_num_lists.pl to produce the text files of candidate bnums
* runs holdings_process.pl on each candidate bnum text file
** controls how many instances of the script are running concurrently
** makes sure the output of each instance of the script is written to a separate directory

This script runs for a long time (about 5.5 hours when run on 2015-05-18). 

### check_progress.sh
control.sh runs in the background for a long time. 

check_progress.sh is used to check on the progress of control.sh. It produces on on-screen list of all the bnum files on which processing has been started, and tells you the percent complete for each bnum file.

### prep_for_hathi.sh
Used after control.sh is completely finished and all data has been extracted. 

* Combines all the data from the individual holdings_process.pl instances into files placed in holdings_final directory
* Renames the files that will be submitted, according to Hathi's specifications

### holdings_cleanup.sh
Used after the final files from holdings_final have been transferred to the Common drive and checked. 

Deletes all the holdings-processing directories and data files produced by the holdings processing workflow. 

## Logic/data script details
From HT's specs: 
: We would like holdings information for book or book-like materials (e.g., pamphlets, bound newspapers or manuscripts) in print that have OCLC numbers and are cataloged as a single unit. We do not want holdings records either for analyzed articles, or for microform, eBooks, or other non-print materials.

### Tables and views used
The '''biblio2base''' view of the database contains the III fixed field data (and limited other information) about each bib record in the catalog. For our purposes, the relevant columns are: bnum, cat date, 2-letter location code, III material type, and III bib_lvl. 

The '''var_fields2''' table stores every variable field of every record in the catalog. Each row in this table is one field from a record. 

The '''item2base''' view contains III fixed field data (and limited other information) about each item record in the catalog. For our purposes, the most relevant columns are: inum, item type, location, copy no., item message (may include d = damaged), status (includes codes relevant to holdings reporting)

### High-level strategy
Because of the architecture of the III Oracle DB, a multi-pass approach at identifying the qualifying records and extracting the necessary data is required.

We need to pull some data from the bib record and some from the item record. 

Because there are fewer bib records, and they contain more information about format, we will start with the bib record. 

#### get_bib_num_lists.pl script
* '''Create list(s) of candidate bnums [[Holdings_data_for_HathiTrust#Details_on_further_screening_of_each_bib_record_in_bnum_list_for_inclusion_eligibility|Details on this step]]'''
** Pull basic info from biblio2base database view
** Create list of bibs that may meet HT's parameters, based on: 
*** presence of CAT DATE
*** appropriate III material type code
*** single-value bib location is NOT inappropriate

Running this script produces text files containing up to 200,000 candidate bnums each. The holdings_process.pl script is then run once per bnum file, using the bnum file as input. 


#### extract_holdings_data_from_bibs.pl script
This script is run on each bnum file output by get_bib_num_lists.pl. It examines each bib record listed. If appropriate, it outputs the HT-requested data to three separate text files (serials, svmonos, and mvmonos). It also appends information on excluded records to an excludes text file. 

Multiple instances of this script can be running concurrently (each using a different bnum file as input). The number of instances that can run concurrently depends on the condition of server on which the processes are running, and what other processes are running at the same time. See the details on the control scripts for how to change the number of concurrent processes. 

Because the script appends data to the text files it outputs, instances running concurrently should be writing to files in discrete locations. The result files are concatenated once all bnum files have been processed.
 
* '''Initial assessment of bib record inclusion eligibility [[Holdings_data_for_HathiTrust#Details_on_further_screening_of_each_bib_record_in_bnum_list_for_inclusion_eligibility|Details on this step]]'''
** Pulls selected data from var_fields2 database table
** Exclude based on:
*** presence of certain values in 915 or 919
*** lack of OCLC number
*** presence of archival control
*** inappropriate bibliographic level 
*** microform format bib record
*** inappropriate record type
*** presence of certain values in physical description (indicating non-book-like materials)

Data on bib records excluded at this point are written to the excludes text file.


* '''For all bibs that passed all eligibility tests, count attached item records'''
** If 0 item records, count attached holdings records
*** If 0 items and 0 holdings records, skip this bib record, writing reason to EXCLUDES file


* '''Set gov doc indicator on any remaining eligible bib, based on presence of 074 field in bib record'''


* '''If eligible bib is a serial record, write data to serials.txt output file'''
** "Serial-ness" is indicated by serial coding in the blvl (in leader)
** All HT-requested data on serials can be pulled from the bib record and is written out here without doing processing of item data (very intensive for a lot of serials records!) 


* '''For each eligible non-serial bib with at least one attached item record, get info on eligible items [[Holdings_data_for_HathiTrust#Getting_item_info|Details on this step]]'''
** Query item2base view for basic info on all attached items
** Determine eligibility of item based on: 
*** item code 2
*** item type
*** item location
** If item is NOT eligible, write to excludes file


* '''For each eligible item, set condition'''
** If item location is trbrs, code as BRT
** If item location is NOT trbrs, code as BRT if number of internal item notes containing the string "brittle" (case-insensitive) is greater than 0
** If item condition isn't already set to BRT, code it as BRT if item message is coded "d"


* '''For each eligible item, set holdings status [[Holdings_data_for_HathiTrust#Setting_holdings_status_for_eligible_items|Details on this step]]'''


* '''For each eligible item, check for presence of volume designator and set accordingly.'''


* '''Data on all eligible items is passed back to part of script that is processing the BIB RECORD'''


* '''If bib has NO eligible items attached, write to excludes file and skip to next bib.'''


* '''Categorize bibs with at least one eligible item as single- or multi-volume monographs'''
** If there is only one eligible item, code as single volume monograph
** If number of eligible items is greater than one: 
*** code as single volume monograph if there are no volume designators on the items, or if all the volume designators are the same (assumed to be multiple copies of same volume)
*** code as multi volume monograph if there are at least 2 different volume designators


* '''If gov doc indicator has not already been set from the bib data, try to set it from the item data'''
** Set to gov doc if any attached item has location code dcpf, dcpf9, or vapa


* '''Write appropriate data on the bib to svmonos or mvmonos text file'''

### Details on development of initial list of candidate bnums
* Queries biblio2base
* Creates txt files
* Each txt file contains up to 200,000 lines
* Each line consists of one record's bnum, cat date, and III material type code
#### Get bnums of all bib records where there is a CAT DATE...
If there is no CAT DATE, it is assumed it has not been cataloged, and thus will not have an OCLC#, which is one of HT's requirements.

#### ...and where the III Material type (mat_type) code is appropriate...
With the knowledge that III mat_type does not always match the MARC mat_type, and neither of these may accurately reflect the actual material type of the described resource. I know, for instance, that NCC does not code its microforms as such in the III mat_type. 

Mat_Types that are inappropriate indicate this is a material type outside HT's parameters: 
* b - archival matl
* d - ms music (appears to mainly be individual scores, photocopies, etc)
* f - ms map (appears to mainly be individual maps)
* g - proj medium
* i - spoken record
* j - sound record
* k - 2-D graphic
* m - computer file
* o - kit
* r - 3-d object
* z - ebooks
* 9 - audiobook
* h - microfilm (but NCC (and others?!) don't code mattype for microfilm... will also have to look at 007 h and/or item location)
* w - web resource
* y - map cd
* 1 - microfiche
* 2 - VHS tape
* 3 - slides
* 4 - non-music cass
* 5 - music cassette
* 6 - music lp
* 0 - motion picture
* s - e-journal
* 7 - geospatial data
* 8 - statistical data
* n - audio player
* ' ' - blank - there were only 3 that had cat dates and I cleaned them up
* - - blank (dash) cleaned up the ones that had a cat date.

Appropriate (possibly) codes:
* a - printed matl
* c - printed music (includes bound monographs of music)
* e - print map (includes atlases)
* p - mixed mat - (includes bound monographs with supplementary materials in other formats -- make sure to just send info about the appropriate items)
* t - manuscript - (includes theses)

#### ...and where the bib location is not one of the following obviously inappropriate codes
* dg - Davis Library Microforms
* dr - Davis Library Bindery
* dy - Davis Library Equipment
* eb - Electronic Book
* ed - Documenting the American South
* er - Electronic Resource
* es - Electronic Streaming Media
* yh - Latin American Film Library
* wa - Archival materials (Wilson Library)

This excludes bib records that have only a single location, which is in the above list. Bib records with multiple locations are included for further analysis.

### Details on further screening of each bib record in bnum list for inclusion eligibility
#### Query var_fields2 for select MARC fields
* Leader
* 001
* 007
* 008
* 022 (ISSN)
* 035
* 074 (GPO Item Number)
* 245
* 300
* 338
* 915
* 919

#### Exclude Documents without Shelves and BROWSE collection bibs
Check for "dwsgpo" in the 919 or "BROWSE" in the 915. 

Exclude bib if present. 

* dwsgpo = online gov docs, many otherwise coded as print
* BROWSE = leased print books -- we do not own them

#### Check for OCLC number
All included holdings must have an OCLC number. 

* Is there an 001 value?
** 1. Yes -- Does it have any alphabetical prefix (besides ocl, ocm, ocn, or on) or suffix?
*** 1Y. Yes -- 001 value is not considered an OCLC number. Skip to 2.
*** 1N. No -- This is considered the OCLC number. Continue with next tests.
** 2. No -- Does it have an 035 value with |a(OCoLC) ? 
*** 2Y. Yes -- Remove subfield delimiter and OCLC prefix from first subfield a with (OCoLC). This is considered the OCLC number. Continue with next tests.
*** 2N. No -- Considered to have NO OCLC number. Write bnum and "no OCLC number" to exceptions file and skip to next bib record.

#### Check Type of control from leader
If a (Archival), do not include. HT doesn't want to know about archival collections.

#### Check bibliographic level from leader
Decisions per value:

* a - Monographic component part - Do not include
* b - Serial component part - Do not include
* c - Collection - Treat as monograph (looks to include more stuff like bound collections of scores, and multi-volume sets than anything like serials.)
* d - Subunit - Do not include
* i - Integrating resource - Treat as monograph
* m - Monograph/Item - Treat as monograph
* s - Serial - Treat as serial

#### Check for microform format
Unfortunately, a large number of microform records are not coded as such in the mattype (and other fixed fields). Look for indication that record is for microform. If present, skip to next record.

Look for: 
* GMD beginning with micro
* 338 containing any of the RDA carrier type terms for microforms (as of 2015-06-22)
* an 007 beginning with h

There's another chance to exclude microforms later, based on item type.

#### Check record type from leader
Decisions per value (logic mirrors that from III material type decisions made in compiling bnum lists).

If decision is "OK," continue on to next test. If decision is "NO," skip to next bib record.

* a - Language material - OK
* c - Notated music - OK
* d - Manuscript notated music - OK
* e - Cartographic material - OK
* f - Manuscript cartographic material - NO
* g - Projected medium - NO
* i - Nonmusical sound recording - NO
* j - Musical sound recording - NO
* k - Two-dimensional nonprojectable graphic - NO
* m - Computer file - NO
* o - Kit - NO
* p - Mixed materials - OK
* r - Three-dimensional artifact or naturally occurring object - NO
* t - Manuscript language material - OK

#### Check $a of physical description (300 field)
If description uses the following term(s), exclude and skip to the next bib: 
* box
* item
* pamphlet
* piece
* sheet



#### Getting item info
##### Initial data from item2base view
* rec_key (item2base) or link_rec (link_rec2) -- item record number
* copy_num
* icode2
* i_type
* location
* status
* imessage

##### Tests for whether this item data is needed
###### Item code 2
* - => 'y',
* n => 'y', #Suppress
* b => 'y', #Bound with
* l => 'y', #Linked
* t => 'n', #To be linked

If y, go ahead to next test. 

If n, skip to next item. Write reason to EXCLUDES.

###### Item type
If y, go ahead to next test.

If n, skip to next item. Write reason to EXCLUDES. 

* 0   => 'y', #Book
* 1   => 'y', #Non-circ book
* 2   => 'y', #Serial
* 3   => 'y', #Non-circ serial
* 4   => 'n', #Art original
* 5   => 'n', #Art Reproduction
* 6   => 'n', #A-V
* 7   => 'y', #Braille
* 8   => 'n', #Broadside
* 9   => 'n', #CD-ROM
* 10  => 'n', #Chart
* 11  => 'n', #Computer file
* 12  => 'n', #Database
* 13  => 'n', #Misc
* 14  => 'n', #Diskette
* 15  => 'n', #Drawing
* 16  => 'n', #Filmstrip
* 17  => 'n', #Flash card
* 18  => 'n', #Game
* 19  => 'n', #Globe
* 20  => 'y', #Government Document
* 21  => 'n', #Interactive
* 22  => 'y', #Juvenile - books are included
* 23  => 'n', #Kit
* 24  => 'y', #Manuscript
* 25  => 'y', #Map - Atlases are coded this way
* 26  => 'n', #Microcard
* 27  => 'n', #Microfiche
* 28  => 'n', #Microfilm
* 29  => 'n', #Microform
* 30  => 'n', #Microslide
* 31  => 'n', #Model
* 32  => 'n', #Motion picture
* 33  => 'y', #New book
* 34  => 'y', #Other - Includes missing monograph volumes, etc.
* 35  => 'n', #Pamphlet
* 36  => 'n', #Photograph
* 37  => 'n', #Picture
* 38  => 'y', #Picture book
* 39  => 'n', #Postcard
* 40  => 'n', #Poster
* 41  => 'n', #Print
* 42  => 'n', #Realia
* 43  => 'y', #Reference
* 44  => 'y', #2 Hour
* 45  => 'y', #Score
* 46  => 'n', #Slide
* 47  => 'n', #Software
* 48  => 'n', #Sound cassette
* 49  => 'n', #Sound CD
* 50  => 'n', #Sound recording
* 51  => 'n', #Technical drawing
* 52  => 'y', #Thesis
* 53  => 'n', #Toy
* 54  => 'n', #Transparency
* 55  => 'n', #Uncataloged material - If uncataloged, should not have OCLC number
* 56  => 'n', #Video cartridge
* 57  => 'n', #Video cassette
* 58  => 'n', #Video disc
* 59  => 'n', #Video recording
* 60  => 'n', #DVD
* 61  => 'n', #Laptop
* 62  => 'n', #Browse - don't include things we don't own... 
* 63  => 'n', #Key
* 64  => 'n', #Wireless NIC
* 65  => 'n', #Carrel Key
* 66  => 'n', #Serial temp - no items of this type in catalog 2013-09-25, can't evaluate
* 67  => 'n', #Microfilm (Master)
* 68  => 'n', #Microfilm (Print-M)
* 69  => 'n', #Microfilm (Use)
* 70  => 'n', #Blu-ray
* 71  => 'y', #2 Hour in Library Use Only
* 72  => 'y', #24 Hour
* 73  => 'y', #7 Day
* 74  => 'y', #1 Day
* 75  => 'y', #3 Day
* 76  => 'n', #Streaming Video
* 77  => 'n', #R&IS Gadget
* 78  => 'y', #Artist's Book
* 79  => 'y', #Auction Catalog
* 80  => 'y', #4 Hour
* 81  => 'y', #4 Hour in Library Use Only
* 82  => 'n', #3 Hour In MRC Use Only - probably will be weeded out by format, but they may have books...
* 83  => 'y', #3 Hour In Library Use Only
* 116 => 'n', #Non coop - no items of this type in catalog 2013-09-25, can't evaluate

###### Item location
If location matches a value in this list, skip to next item and write reason to EXCLUDES. 

If location doesn't match a value in this list, record item data in item data hash. Query var_fields2 to get volume data and internal notes.

* 'aadaa', #	Art Library CD-ROM
* 'aadab', #	Art Library Compact Disc
* 'aadac', #	Art Library Computer Disk 3 1/2
* 'aadad', #	Art Library Digital Video Disc
* 'aadae', #	Art Library Interactive Multimedia
* 'aadaf', #	Art Library Microfiche
* 'aadag', #	Art Library Microfilm
* 'aadah', #	Art Library Videocassette
* 'aana', # 	Art Library Vase Room
* 'aaraa', #	Art Library Cage Kit
* 'bbdaa', #	Science Library Annex Media Collection
* 'bbdab', #	Science Library Annex Cassette
* 'bbdac', #	Science Library Annex Computer Disk 3 1/2
* 'bbdad', #	Science Library Annex Computer Disk 5 1/4
* 'bbdae', #	Science Library Annex Interactive Multimedia
* 'bbdaf', #	Science Library Annex Microfiche
* 'bbdag', #	Science Library Annex Microfilm
* 'bbdah', #	Science Library Annex Record
* 'bbdaj', #	Science Library Annex Slide
* 'bbdak', #	Science Library Annex Videocassette
* 'bbdfa', #	Science Library Annex Office CD-ROM
* 'bbdfb', #	Science Library Annex Office Computer Disk 3 1/2
* 'bbdfc', #	Science Library Annex Office Digital Video Disc
* 'bbdfd', #	Science Library Annex Office Interactive Multimedia
* 'ccdaa', #	Kenan Science Library CD-ROM
* 'ccdab', #	Kenan Science Library Cassette
* 'ccdac', #	Kenan Science Library Microcard
* 'ccdad', #	Kenan Science Library Microfiche
* 'ccdae', #	Kenan Science Library Microfilm
* 'dccb', # 	Davis Library Reference Desk Microfiche
* 'dccda', #	Davis Library Reference Microcoard
* 'dccdb', #	Davis Library Reference Microfiche
* 'dccdc', #	Davis Library Reference Microfilm
* 'dcce', # 	Davis Library Reference Fascicle File
* 'dclka', #	Davis Library Reference Row 10 Microfiche
* 'dclqa', #	Davis Library Reference Row 14 Microfiche
* 'dcpfa', #	Davis Library Reference Federal Documents CD-ROM
* 'dcpfb', #	Davis Library Reference Federal Documents Microfiche
* 'dcpfc', #	Davis Library Reference Federal Documents Videocassette
* 'dcpfi', #	Davis Ref Federal Documents Internet Resource
* 'dcpwa', #	Davis Library Reference International Documents CD-ROM
* 'dcpwb', #	Davis Library Reference International Docs Computer Disk 3 1/2
* 'dcpwc', #	Davis Library Reference International Docs Microfiche
* 'dcya', # 	Davis Library Reference Electronic Resources
* 'dcyab', #	Davis Library Reference Electronic Resources CD-ROM
* 'dcyac', #	Davis Library Reference Electronic Resources Computer Disk
* 'dcyad', #	Davis Library Reference Electronic Resource Computer Disk 3 1/2
* 'dcyae', #	Davis Library Reference Electronic Resources Computer Disk 5 1/4
* 'dcyaf', #	Davis Library Reference Electronic Resources Interactive Multimedia
* 'dcyag', #	Davis Library Reference E-Docs Archive CD-ROM
* 'dcyb', # 	Davis Library Reference Electronic Archive
* 'dcyba', #	Davis Library Reference Electronic Archive Computer Disk
* 'dcybb', #	Davis Library Reference Electronic Archive Computer Disk 3 1/2
* 'dcybc', #	Davis Library Reference Electronic Archive Computer Disk 5 1/4
* 'dcybd', #	Davis Library Reference Electronic Archive Interactive Multimedia
* 'dcyea', #	Davis Library Reference E-Docs
* 'dcyeb', #	Davis Library Reference E-Docs CD-ROM
* 'dcyec', #	Davis Library Reference E-Docs Computer Disk 3 1/2
* 'dcyef', #	Davis Library Reference E-Docs Archive
* 'dcyfa', #	Davis Library Reference Federal Internet Resource
* 'ddcca', #	Davis Library (Non-circulating) Microfilm
* 'dddae', #	Davis Library Video CD
* 'dg', # 	Davis Library Microforms
* 'dga9', # 	Not Yet Determined Microforms
* 'dga', #@ 	Staff Use Only Microforms
* 'dgaa', #	Staff Use Only Microfilm Master
* 'dgab', #	Staff Use Only Microfilm Print Master
* 'dgda', # 	Davis Microforms Coll
* 'dgdaa', #	Davis Library Microfilm
* 'dgdab', #	Davis Library Microcard
* 'dgdac', #	Davis Library Microfilm Serial
* 'dgdad', #	Davis Library Microform
* 'dgdae', #	Davis Library Microfiche
* 'dgdaf', #	Davis Library Microprint
* 'dgdb', # 	Davis Library Microforms Folio
* 'dgdba', #	Davis Library Microfilm Folio
* 'dgdbb', #	Davis Library Microfiche Folio
* 'dgdc', # 	Davis Library Microforms Folio-2
* 'dgdca', #	Davis Library Microfilm Folio-2
* 'dgdda', #	Davis Library Microfilm Use Copy
* 'dgta', # 	Davis Library MNF (Ask at Circ Desk)
* 'dgz', #	Davis Library Microforms Non-scoped
* 'dndaa', #	Storage--Use Request Form Microfiche
* 'dndab', #	Storage--Use Request Form Microfilm
* 'dngaa', #	Storage(MFM)--Use Request Form Microfiche
* 'dngab', #	Storage(MFM)--Use Request Form Microfilm
* 'dngba', #	Storage(MFC)--Use Request Form Microfiche
* 'dngbb', #	Storage(MFC)--Use Request Form Microfilm
* 'dngca', #	Storage(MFD)--Use Request Form Microcard
* 'dvtaa', #	Davis Library Preservation Microfilm
* 'dy', # 	Davis Library Equipment
* 'dyca', # 	Davis Library Laptop Storage
* 'dywa', # 	Davis Library Wireless Card
* 'dyz', #	Davis Library Equipment Non-Scoped
* 'eb', # 	Electronic Book
* 'ebna', # 	Electronic Book netLibrary
* 'ebnb', # 	Electronic Book
* 'ebz', #	Electronic Book Non-Scoped
* 'ed', # 	Documenting the American South
* 'edas', # 	Documenting the American South
* 'edas', #@	Documenting the American South (staff us only)
* 'er', # 	Electronic Resource
* 'erda', # 	Electronic Resource--Lexis
* 'erdb', # 	Electronic Resource--InfoTrac
* 'erra', # 	Electronic Resource
* 'errd', #	Online Data Set (No restrictions)
* 'erri', # 	Electronic Resource--Internet
* 'erri', #@	Electronic Resource--Internet Do not Catalog
* 'errs', #	Online Data Set (Spruce)
* 'errw', #	Online Data Set (Willow)
* 'erz', #	Electronic Resources non-scoped
* 'es', #	Electronic Streaming Media
* 'estr', #	Electronic Streaming Media
* 'ggla', # 	Geological Sciences Library Map Room Vertical File
* 'gglaa', #	Geological Sciences Library Map Room Vertical File Map
* 'gglb', # 	Geological Sciences Library Map Room
* 'gglba', #	Geological Sciences Library Map Room Map
* 'hhga', # 	Highway Safety Research Center Library Microfiche Documents
* 'hhla', # 	Highway Safety Research Center Library Audiovisual Collection
* 'hhya', # 	Highway Safety Research Center Library Electronic Access Local
* 'hhyb', # 	Highway Safety Research Center Library Electronic Access Remote
* 'jjdaa', #	Maps Collection CD-ROM
* 'jjdab', #	Maps Collection Computer Disk 3 1/2
* 'jjdac', #	Maps Collection Computer Disk 5 1/4
* 'jjdad', #	Maps Collection Digital Video Disc
* 'jjdae', #	Maps Collection Microfiche
* 'jjdb', # 	Maps Collection Folio
* 'jjdc', # 	Maps Collection Folio-2
* 'jjdd', # 	Maps Collection Folio Oversize
* 'jjde', # 	Maps Collection Folio 2 Oversize
* 'jjdh', # 	Maps Collection Oversize Maps
* 'jjea', # 	Maps Collection Horizontal Files
* 'jjeb', # 	Maps Collection Vertical Files
* 'jjeba', #	Maps Collection Vertical Files Microfiche
* 'jjec', # 	Maps Collection Lateral File
* 'jjed', # 	Maps Collection Historical Horizontal File
* 'jjee', # 	Maps Collection Historical Vertical File
* 'jjga', # 	Maps Collection Microforms
* 'jjnb', # 	Maps Collection Annex Oversize Maps
* 'jjnc', # 	Maps Collection Annex Oversize Volumes
* 'jjnd', # 	Maps Collection Annex Horizontal Files
* 'jjne', # 	Maps Collection Annex Vertical Files
* 'jjraa', #	Maps Collection Cage Microfiche
* 'jjya', # 	Maps Collection Electronic Resource
* 'kdav', # 	Law Library Audio-Visual Documents Collection
* 'kdcd', # 	Law Library CD-ROM Documents Collection
* 'kdfc', # 	Law Library Microfiche Documents Collection
* 'kdvd', # 	Law Library DVD Documents Collection
* 'knav', # 	Law Library Audio-Visual
* 'kncd', # 	Law Library CD-ROM
* 'knfc', # 	Law Library Microfiche
* 'knfci', #	Law Library Microfiche Index
* 'knfm', # 	Law Library Microfilm
* 'knfmi', #	Law Library Microfilm Index
* 'knlv', # 	Law Library Leisure Video
* 'knsc', # 	Law Library Software Collection
* 'knvd', # 	Law Library DVD
* 'kwec', # 	Law Library Electronic Instruction Center
* 'kwer', # 	Law Library Electronic Resource
* 'kwer2', #	Law Library Electronic Book
* 'kweu', # 	Law Library Computer Lab
* 'llbaa', #	Information & Library Science Library Reserve Microfilm
* 'lldaa', #	Information & Library Science Library AV Cassette
* 'lldab', #	Information & Library Science Library Cassette
* 'lldad', #	Information & Library Science Library Computer Disk 3 1/2
* 'lldae', #	Information & Library Science Library Computer Disk 5 1/4
* 'lldaf', #	Information & Library Science Library Filmstrip
* 'lldag', #	Information & Library Science Library Game
* 'lldah', #	Information & Library Science Library Kit
* 'lldaj', #	Information & Library Science Library Microfiche
* 'lldak', #	Information & Library Science Library Microfilm
* 'lldam', #	Information & Library Science Library Motion Picture
* 'lldan', #	Information & Library Science Library Slide
* 'lldao', #	Information & Library Science Library Sound Filmstrip
* 'lldap', #	Information & Library Science Library Sound Slide Set
* 'lldaq', #	Information & Library Science Library Videocassette
* 'lldar', #	Information & Library Science Library Videotape
* 'llha', # 	Information & Library Science Library Newsletter File
* 'llla', # 	Information & Library Science Library A/V
* 'lllaa', #	Information & Library Science Library AV Cassette
* 'lllab', #	Information & Library Science Library AV Compact Disc
* 'lllac', #	Information & Library Science Library AV Videocassette
* 'lllad', #	Information & Library Science Library AV Cassette
* 'lllae', #	Information & Library Science Library A/V Computer Software
* 'lllaf', #	Information & Library Science Library AV Videocassette
* 'mmbaa', #	Music Library Reserve Videocassette
* 'mmea', # 	Music Library F-File
* 'mmga', # 	Music Library Microfilm
* 'mmgb', # 	Music Library Microfiche
* 'mmgc', # 	Music Library Microcard
* 'noha', # 	Health Sciences Library Educational Media
* 'nohas', #	Health Sciences Library Slides
* 'nohbo', #	HSL Historical Collection Artifacts
* 'nohbs', #	HSL Historical Collection Sound Recordings
* 'nohbt', #	HSL Historical Collection Visual Media
* 'nohe', # 	Electronic Resource
* 'noheb', #	Health Sciences Library Electronic Book
* 'nohm', # 	Health Sciences Library Microfiche
* 'nohmf', #	Health Sciences Library Microfilm
* 'qqdaa', #	Math/Physics Library CD-ROM
* 'qqdab', #	Math/Physics Library Cassette
* 'qqdac', #	Math/Physics Library Computer Disk 3 1/2
* 'qqdad', #	Math/Physics Library Computer Disk 5 1/2
* 'qqdae', #	Math/Physics Library DVD
* 'qqdaf', #	Math/Physics Library Microfiche
* 'qqdag', #	Math/Physics Library Microfilm
* 'qqdah', #	Math/Physics Library Sound Slide Set
* 'qqdaj', #	Math/Physics Library Videocassette
* 'qqdam', #	Math/Physics Library Videodisc
* 'qqka', # 	Math/Physics Library Machine-Readable Data File
* 'qqkaa', #	Math/Physics Library CD-ROM
* 'qqkab', #	Math/Physics Library Computer Disk 3 1/2
* 'qqkac', #	Math/Physics Library DVD
* 'trsc', # 	NC Central
* 'trsd', # 	Duke
* 'trss', # 	NC State
* 'truls', #	Media Resource Center Remote Storage
* 'uadaa', #	Undergrad Library CD-ROM
* 'uadac', #	Undergrad Library Interactive Multimedia
* 'uadai', #	Undergrad Library Popular Reading (Entry Level)
* 'ulbaa', #	Media Resources Center Reserve Videocassette
* 'ulbab', #	Media Resources Center Reserve Compact Disc
* 'ulbr', #	Media Resources Center Blu-ray Disc
* 'ulcaa', #	Media Resources Center Reference CD-ROM
* 'uldab', #	Media Resources Center Audiocassette
* 'uldac', #	Media Resources Center Cassette
* 'uldad', #	Media Resources Center CD-ROM
* 'uldae', #	Media Resources Center Compact Disc
* 'uldaf', #	Media Resources Center DVD-ROM
* 'uldag', #	Media Resources Center Digital Videodisc
* 'uldah', #	Media Resources Center Electronic Resource
* 'uldaj', #	Media Resources Center Filmstrip
* 'uldak', #	Media Resources Center Interactive Multimedia
* 'uldal', #	Media Resources Center Library Use Only
* 'uldam', #	Media Resources Center Kit
* 'uldan', #	Media Resources Center Laser Disc
* 'uldao', #	Media Resources Center Motion Picture
* 'uldap', #	Media Resources Center Record
* 'uldaq', #	Media Resources Center Slides
* 'uldar', #	Media Resources Center Sound Cassette
* 'uldas', #	Media Resources Center Sound Disc
* 'uldat', #	Media Resources Center Sound Filmstrip
* 'uldau', #	Media Resources Center Sound Recording
* 'uldav', #	Media Resources Center Sound Slide Set
* 'uldaw', #	Media Resources Center Video CD
* 'uldax', #	Media Resources Center Video Digital Disc
* 'ulday', #	Media Resources Center Videocamera
* 'uldaz', #	Media Resources Center Videocassette
* 'uldc', # 	Media Resources Center Equipment
* 'uldd', # 	Media Resources Center Audiobooks
* 'vadaa', #	School of Government Library CD-ROM
* 'vadab', #	School of Government Library Microcard/fiche
* 'wbcc', # 	North Carolina Collection Online
* 'wbdaa', #	North Carolina Collection Cassette
* 'wbdab', #	North Carolina Collection Game
* 'wbdac', #	North Carolina Collection Map Folio
* 'wbdad', #	North Carolina Collection Maps
* 'wbdae', #	North Carolina Collection Microcard
* 'wbdaf', #	North Carolina Collection Microfiche
* 'wbdag', #	North Carolina Collection Microfilm
* 'wbdah', #	North Carolina Collection Microform
* 'wbdaj', #	North Carolina Collection Record
* 'wbdak', #	North Carolina Collection Sheet
* 'wbdam', #	North Carolina Collection Videocassette
* 'wbdba', #	North Carolina Collection Folio Microfilm
* 'wbga', # 	North Carolina Collection Photo Archives
* 'wbpaa', #	North Carolina Collection State Docs Collection Microfiche
* 'wbpab', #	North Carolina Collection State Docs Collection Online
* 'wbwaa', #	North Carolina Collection Wolfe Microfilm
* 'wcdg', # 	Rare Book Collection LP Record
* 'wcdh', # 	Rare Book Collection Audiocassette
* 'wcdj', # 	Rare Book Collection CD
* 'wcdk', # 	Rare Book Collection Photos
* 'wcdl', #	Rare Book Collection Newspapers
* 'wcdm', # 	Rare Book Collection DVD
* 'wcdn', # 	Rare Book Collection Videocassettes
* 'wcdt', #	Rare Book Collection Tabloids
* 'wchq', # 	Rare Book Collection Beats Photos
* 'wcpe', # 	Rare Book Collection Patton Photos
* 'wcrp', #	Rare Book Collection 45RPMs
* 'xcac', #	Carolina Population Center Library Electronic Resources Internet CPC
* 'xcad', #	Carolina Population Center Library Electronic Resource
* 'xcea', #	Carolina Population Center Library Reports, Offprints, Papers
* 'xceb', #	Carolina Population Center Library Area Files Cabinets
* 'yadaa', #	K-12 International Resource Library Videocassettes
* 'yccaa', #	Graduate Funding Information Center Reference CD-ROM
* 'yccab', #	Graduate Funding Information Center Reference Cassette
* 'yccac', #	Graduate Funding Information Center Reference Kit
* 'yccad', #	Graduate Funding Information Center Reference Video
* 'yccae', #	Graduate Funding Information Center Reference Videocassette
* 'yccaf', #	Graduate Funding Information Center Reference DVD
* 'yccag', #	Graduate Funding Information Center Reference Non-Music CD
* 'ycdaa', #	Graduate Funding Information Center Cassette
* 'ycdab', #	Graduate Funding Information Center Kit
* 'ycdac', #	Graduate Funding Information Center Video
* 'ycdad', #	Graduate Funding Information Center Videocassette
* 'ycdae', #	Graduate Funding Information Center Library CD-Rom
* 'ycdaf', #	Graduate Funding Information Center Library DVD
* 'ycdag', #	Graduate Funding Information Center Non-Music CD
* 'ydka', # 	Park Library Posters
* 'ydla', # 	Park Library Multimedia
* 'ydya', #	Park Library Electronic Resource
* 'yhda', #	Latin American Film Library
* 'yhdc', #	Latin American Film Library Reference
* 'yhz', #	Latin American Film Library nonscoped

### Setting holdings status for eligible items
'''HT codes'''
* CH = current holding
* LM = lost or missing
* WD = withdrawn

Blank item status codes are set to CH.

'''Item status to HT code mapping'''
* '!' => 'CH', #On holdshelf
* '$' => 'LM', #Lost and paid
* '%' => 'CH', #ILL/INN-Reach
* '-' => 'CH', #Available
* a   => 'CH', #Contact MRC to reserve
* b   => 'CH', #Backlogged
* c   => 'LM', #Claims lost
* d   => 'LM', #Declared lost
* e   => 'CH', #In process at the LSC
* f   => 'LM', #Never received
* g   => 'CH', #Ask the MRC
* j   => 'CH', #Contact LAFL for status
* m   => 'LM', #Missing
* n   => 'LM', #Billed
* o   => 'CH', #Lib use only
* p   => 'CH', #In process
* r   => 'CH', #In repair
* s   => 'LM', #On search
* t   => 'CH', #In transit
* u   => 'CH', #Staff use only
* w   => 'WD', #Withdrawn
* z   => 'LM', #Clms retd

### Categorize eligible bibs as serials, single volume monographs, or multi-volume monographs
Separating out the serials is easy. This is based on the blvl in the leader coded as s. 

Separating out the single- and multi-volume monographs is a mess: 
* We do not code for whether a monograph is single-volume or multiple volume. 
* "v." or "volume(s)" is used in the physical description for some unpaged single volume monographs and those with complex pagination.
* Multiple item records may reflect multiple volumes, OR multiple copies of one volume. 

For this first pass, the best I can do is this: 
* If there is only one item record, categorize as single-volume monograph

* If there is more than one item record:
** If all volume designations are blank, list as copies of a single-volume monograph
** If some volume designations are populated (and are not all identical), list as volumes of multi-volume monograph


##
#
# This script is used to debug a dbm file.
# -d dbm file (such as -d gd.uername.md5.db)
# optional:
#  -p   -- prints dbm contents
#  -c  -- count the number of enteries
#
###

package PDRIVE;



use strict;

use constant DEBUG => 1;
use constant DEBUG_LOG => 'debug.log';



use constant SERVER_UPDATED => 0;
use constant SERVER_LINK => 1;
use constant TYPE => 2;
use constant LOCAL_UPDATED => 3;



use constant DB_SERVER_UPDATED => 'server_updated';
use constant DB_SERVER_LINK => 'server_link';
use constant DB_TYPE => 'type';
use constant DB_LOCAL_UPDATED => 'local_updated';




use constant IS_ROOT => 1;
use constant NOT_ROOT => 0;



use constant FOLDER_TITLE => 0;
use constant FOLDER_ROOT => 1;
use constant FOLDER_PARENT => 2;
use constant FOLDER_SUBFOLDER => 3;


use Getopt::Std;
use constant USAGE => " usage: $0 [-d dbm]\n";

my %opt;
die (USAGE) unless (getopts ('d:k:v:',\%opt));
my $dbm_file = $opt{d};

&PDRIVE::DBM::init($dbm_file);

&PDRIVE::DBM::updateDBHash($opt{k},$opt{v});

{
package PDRIVE::DBM;

use DB_File;
use Fcntl;

use strict;

my $dbm;
my %dbase;
sub init($){

 $dbm = shift;

}


sub updateDBHash($$){

	my $key = shift;
	my $value = shift;



  tie(%dbase, 'DB_File', $dbm,O_RDWR|O_CREAT, 0666) or die "can't open $dbm: $!";

	$dbase{$key} = $value;
    print "$key: $dbase{$key}\n";


  untie(%dbase);

}



1;

}

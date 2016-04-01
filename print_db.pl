
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
die (USAGE) unless (getopts ('d:pc',\%opt));
my $dbm_file = $opt{d};

&PDRIVE::DBM::init($dbm_file);

if ($opt{p}){
	&PDRIVE::DBM::printDBHash();
}elsif ($opt{c}){
	&PDRIVE::DBM::countDBHash();
}

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




sub printDBHash(){

  print "Database $dbm consists of the following key value pairs...\n";



  tie(%dbase, 'DB_File', $dbm,O_RDWR|O_CREAT, 0666) or die "can't open $dbm: $!";

  foreach my $key (keys %dbase) {
    print "$key: $dbase{$key}\n";
  }


  untie(%dbase);

}



sub countDBHash(){

  print "Database $dbm contains this count...\n";


  tie(%dbase, 'DB_File', $dbm,O_RDWR|O_CREAT, 0666) or die "can't open $dbm: $!";

  my $count = 0;
  foreach my $key (keys %dbase) {
    $count++;
  }

  untie(%dbase);

  print "Number of enteries = " . $count ."\n";

}

1;

}

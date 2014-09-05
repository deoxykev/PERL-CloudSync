#!/usr/local/bin/perl5
#

package pDrive;

if (!(-e './config.cfg')){
  print STDOUT "no config file found... creating config.cfg\nYou will want to modify this file (including adding a username and password)\n";
  open(CONFIG, '>./config.cfg') or die ('cannot create config.cfg');
  print CONFIG <<EOF;
package pDrive::Config;
use SDBM_File;
use Fcntl;



# configuration
use constant DEBUG => 1;
use constant DEBUG_LOG => '/tmp/debug.log';
use constant LOGFILE => '/tmp/pDrive.log';
use constant SAMPLE_LIST => 'samplelist.txt';
use constant REVISIONS => 1;
use constant LOCAL_PATH => '/u01/pdrive/';
use constant USERNAME => '';
use constant PASSWORD => '';
use constant DBM_CONTAINER_FILE => LOCAL_PATH . '.pdrive.catalog.db';


1;
EOF
  close(CONFIG);
}


require './config.cfg';
use strict;

require './lib/googledocsapi3.pm';
require './lib/dbm.pm';
require './lib/time.pm';
require './lib/fileio.pm';
require './lib/gdrive.pm';





########


use constant ONLINE => 1;
#use constant CHUNKSIZE => (256*1024);
use constant CHUNKSIZE => 524288;

# fetch hostname
use Sys::Hostname;
use constant HOSTNAME => hostname;



my $pDrive = pDrive::gDrive->new(pDrive::Config->USERNAME,pDrive::Config->PASSWORD);



exit;




####
# file i/o
####


sub readTestListings(){

  open(INPUT, pDrive::Config->SAMPLE_LIST) or die ('cannot read file '.pDrive::Config->SAMPLE_LIST);
  binmode(INPUT);
  my $fileContents = do { local $/; <INPUT> };
  close(INPUT);

  return \$fileContents;

}





sub masterLog($){

  my $event = shift;

  my $timestamp = pDrive::Time::getTimestamp(time, 'YYYYMMDDhhmmss');
#  my $datestamp = substr($timestamp, 0, 8);

  print STDERR $event . "\n" if (pDrive::Config->DEBUG);
  open (SYSTEMLOG, '>>' . pDrive::Config->LOGFILE) or die('Cannot access application log ' . pDrive::Config->LOGFILE);
  print SYSTEMLOG HOSTNAME . ' (' . $$ . ') - ' . $timestamp . ' -  ' . $event . "\n";
  close (SYSTEMLOG);

}




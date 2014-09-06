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

&PDRIVE::DBM::init();
&PDRIVE::DBM::printDBHash();


{
package PDRIVE::DBM;

use DB_File;
use Fcntl;

use strict;

my $dbm;
my %dbase;
sub init(){

 $dbm = '/u01/pdrive/.pdrive.catalog.db';

}

sub readDBHash(){

  my %returnHash;

  tie(%dbase, 'DB_File', $dbm,O_RDWR|O_CREAT, 0666) or die "can't open $dbm: $!";


  foreach my $key (keys %dbase) {


    my ($path,$resourceID,$type) = $key =~ m%([^\|]+)\|([^\|]+)\|([^\|]+)%;


    if ($type eq PDRIVE::DB_SERVER_UPDATED){
      $returnHash{$path}{$resourceID}[PDRIVE::SERVER_UPDATED] = $dbase{$key};
    } elsif ($type eq PDRIVE::DB_SERVER_LINK){
      $returnHash{$path}{$resourceID}[PDRIVE::SERVER_LINK] = $dbase{$key};
    } elsif ($type eq PDRIVE::DB_TYPE){
      $returnHash{$path}{$resourceID}[PDRIVE::TYPE] = $dbase{$key};
    } elsif ($type eq PDRIVE::DB_LOCAL_UPDATED){
      $returnHash{$path}{$resourceID}[PDRIVE::LOCAL_UPDATED] = $dbase{$key};
    }


  }


  untie(%dbase);


  return %returnHash;

}



sub writeDBHash(*){

  my %memoryHash = %{$_[0]};

  tie(%dbase, 'SDBM_File', $dbm,O_RDWR|O_CREAT, 0666) or die "can't open $dbm: $!";

  foreach my $path (keys %memoryHash) {

    foreach my $resourceID (keys %{$memoryHash{$path}}) {

      if ($memoryHash{$path}{$resourceID}[PDRIVE::SERVER_UPDATED] ne $dbase{$path.'|'.$resourceID.'|'.PDRIVE::DB_SERVER_UPDATED}){
        $dbase{$path.'|'.$resourceID.'|'.PDRIVE::DB_SERVER_UPDATED} = $memoryHash{$path}{$resourceID}[PDRIVE::SERVER_UPDATED];
      } elsif ($memoryHash{$path}{$resourceID}[PDRIVE::SERVER_LINK] ne $dbase{$path.'|'.$resourceID.'|'.PDRIVE::DB_SERVER_LINK}){
         $dbase{$path.'|'.$resourceID.'|'.PDRIVE::DB_SERVER_LINK} = $memoryHash{$path}{$resourceID}[PDRIVE::SERVER_LINK];
      } elsif ($memoryHash{$path}{$resourceID}[PDRIVE::TYPE] ne $dbase{$path.'|'.$resourceID.'|'.PDRIVE::DB_TYPE}){
         $dbase{$path.'|'.$resourceID.'|'.PDRIVE::DB_TYPE} = $memoryHash{$path}{$resourceID}[PDRIVE::TYPE];
      } elsif ($memoryHash{$path}{$resourceID}[PDRIVE::LOCAL_UPDATED] ne $dbase{$path.'|'.$resourceID.'|'.PDRIVE::DB_LOCAL_UPDATED}){
         $dbase{$path.'|'.$resourceID.'|'.PDRIVE::DB_LOCAL_UPDATED} = $memoryHash{$path}{$resourceID}[PDRIVE::LOCAL_UPDATED];
      }


    }


  }

  untie(%dbase);

}


sub printDBHash(){

  print "Database $dbm consists of the following key value pairs...\n";



  tie(%dbase, 'DB_File', $dbm,O_RDWR|O_CREAT, 0666) or die "can't open $dbm: $!";

  foreach my $key (keys %dbase) {
    print "$key: $dbase{$key}\n";
  }


  untie(%dbase);

}



1;

}

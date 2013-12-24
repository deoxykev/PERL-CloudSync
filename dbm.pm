package PDRIVE::DBM;
use SDBM_File;
use Fcntl; 
use strict;



use constant D_SERVER_UPDATED => 'server_updated';
use constant D_SERVER_LINK => 'server_link';
use constant D_TYPE => 'type';
use constant D_LOCAL_UPDATED => 'local_updated';
use constant D_LOCAL_REVISION => 'local_revision';

use constant D => {
  'server_updated' => 0,
  'server_link' => 1,
  'type' => 2,
  'local_updated' => 3,
  'local_revision' => 4
};

my %dbase;
sub init(){

}


sub readDBHash(){
  my %returnHash;

  tie(%dbase, 'SDBM_File', PDRIVE::DBM_FILE,O_RDWR|O_CREAT, 0666) or die "can't open ".PDRIVE::DBM_FILE.": $!";

  foreach my $key (keys %dbase) {

    my ($path,$resourceID,$type) = $key =~ m%([^\|]+)\|([^\|]+)\|([^\|]+)%;

    $returnHash{$path}{$resourceID}[PDRIVE::DBM->D->{$type}] = $dbase{$key};

  }

  untie(%dbase);

  return \%returnHash;

}

sub constructResourceIDHash(*){

  my ($memoryHash) = @_;
  my %resourceIDHash;

  my $count=0;
  foreach my $path (keys %{$memoryHash}) {

    foreach my $resourceID (keys %{${$memoryHash}{$path}}) {
      $resourceIDHash{$resourceID} = $path;
    }

  }
  return \%resourceIDHash;

}

sub writeDBHash(*){
  my %memoryHash = %{$_[0]};

  tie(%dbase, 'SDBM_File', PDRIVE::DBM_FILE,O_RDWR|O_CREAT, 0666) or die "can't open ".PDRIVE::DBM_FILE.": $!";

  foreach my $path (keys %memoryHash) {

    foreach my $resourceID (keys %{$memoryHash{$path}}) {

      foreach my $key (keys %{PDRIVE::DBM->D}){
        $dbase{$path.'|'.$resourceID.'|'.$key} = $memoryHash{$path}{$resourceID}[PDRIVE::DBM->D->{$key}] if ($memoryHash{$path}{$resourceID}[PDRIVE::DBM->D->{$key}] ne $dbase{$path.'|'.$resourceID.'|'.$key});
      }

    }

  }

  untie(%dbase);

}


sub writeValueDBHash(***){

  my ($path,$resourceID, $memoryHash) = @_;

  tie(%dbase, 'SDBM_File', PDRIVE::DBM_FILE,O_RDWR|O_CREAT, 0666) or die "can't open ".PDRIVE::DBM_FILE.": $!";

  foreach my $key (keys %{PDRIVE::DBM->D}){
    $dbase{$$path.'|'.$$resourceID.'|'.$key} = $$memoryHash{$$path}{$$resourceID}[PDRIVE::DBM->D->{$key}] if ($$memoryHash{$$path}{$$resourceID}[PDRIVE::DBM->D->{$key}] ne $dbase{$$path.'|'.$$resourceID.'|'.$key});
  }

  untie(%dbase);

}

sub printDBHash(){

  print "Database ".PDRIVE::DBM_FILE." consists of the following key value pairs...\n";


  tie(%dbase, 'SDBM_File', PDRIVE::DBM_FILE,O_RDWR|O_CREAT, 0666) or die "can't open ".PDRIVE::DBM_FILE.": $!";

  foreach my $key (keys %dbase) {
    print "$key: $dbase{$key}\n"; 
  }

  untie(%dbase);

}

1;


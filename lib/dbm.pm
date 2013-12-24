package pDrive::DBM;
use SDBM_File;
use Fcntl; 
use strict;

# magic numbers
use constant FOLDER_TITLE => 0;
use constant FOLDER_ROOT => 1;
use constant FOLDER_PARENT => 2;
use constant FOLDER_SUBFOLDER => 3;


use constant D => {
  'server_updated' => 0,
  'server_link' => 1,
  'server_md5' => 2,
  'server_edit' => 3,
  'type' => 4,
  'local_updated' => 5,
  'local_revision' => 6,
  'local_md5' => 7,
  'parent' => 8,
  'title' => 9,
  'published' => 10
};


sub new(r) {

  my $self = {_dbase => undef};

  bless $self, $_[0];

  return $self;

}


sub readHash(r){

  my $self = shift;
  my %returnContainerHash;
  my %returnFolderHash;

  tie(my %dbase, 'SDBM_File', pDrive::Config->DBM_CONTAINER_FILE,O_RDWR|O_CREAT, 0666) or die "can't open ".pDrive::Config->DBM_CONTAINER_FILE.": $!";

  foreach my $key (keys %dbase) {


    # container object
    if ($key =~ m%^C\|%){
      my ($path,$resourceID,$type) = $key =~ m%^C\|([^\|]+)\|([^\|]+)\|([^\|]+)$%;
      $returnContainerHash{$path}{$resourceID}[pDrive::DBM->D->{$type}] = $dbase{$key};

    # folder
    }elsif ($key =~ m%^F\|%){
      #old-style F|

      if ($key =~ m%^F\|[^\|]+\|[^\|]+\|[^\|]+\|[^\|]+\|\d+$%){
      my ($resourceID,$title,$isRoot,$parentID,$count) = $key =~ m%^F\|([^\|]+)\|([^\|]+)\|([^\|]+)\|([^\|]+)([^\|]+)$%;
      $returnFolderHash{$resourceID}[FOLDER_TITLE] = $title;
      $returnFolderHash{$resourceID}[FOLDER_ROOT] = $isRoot;
      $returnFolderHash{$resourceID}[FOLDER_PARENT] = $parentID;
      my $subFolders = $dbase{$key};

      while (my ($subFolder) = $subFolders =~ m%^([^\|]+)\|?%){
 
        $subFolders =~ s%^[^\|]+\|?%%;
        if ($#{$returnFolderHash{$parentID}} >= FOLDER_SUBFOLDER){

          $returnFolderHash{$parentID}[$#{$returnFolderHash{$parentID}}+1] = $resourceID;

        }else{

          $returnFolderHash{$parentID}[FOLDER_SUBFOLDER] = $resourceID;

        }

      }


      }elsif ($key =~ m%^F\|[^\|]+\|[^\|]+\|[^\|]+\|[^\|]+\|.*$%){
      my ($resourceID,$title,$isRoot,$parentID,$subFolders) = $key =~ m%^F\|([^\|]+)\|([^\|]+)\|([^\|]+)\|([^\|]+)\|(.*)$%;
      $returnFolderHash{$resourceID}[FOLDER_TITLE] = $title;
      $returnFolderHash{$resourceID}[FOLDER_ROOT] = $isRoot;
      $returnFolderHash{$resourceID}[FOLDER_PARENT] = $parentID;

      while (my ($subFolder) = $subFolders =~ m%^([^\|]+)\|?%){
 
        $subFolders =~ s%^[^\|]+\|?%%;
        if ($#{$returnFolderHash{$parentID}} >= FOLDER_SUBFOLDER){

          $returnFolderHash{$parentID}[$#{$returnFolderHash{$parentID}}+1] = $resourceID;

        }else{

          $returnFolderHash{$parentID}[FOLDER_SUBFOLDER] = $resourceID;

        }

      }
      #new-style F|
      }

    #fix -- temporary
    }else{
      my ($path,$resourceID,$type) = $key =~ m%([^\|]+)\|([^\|]+)\|([^\|]+)$%;
      $returnContainerHash{$path}{$resourceID}[pDrive::DBM->D->{$type}] = $dbase{$key};
      $dbase{'C|'.$key} = $dbase{$key};
      delete $dbase{$key};
    }

  }

  untie(%dbase);

  return (\%returnContainerHash,\%returnFolderHash);

}



sub constructResourceIDHash(rr){

  my $self = shift;
  my $memoryHash = shift;
  my %resourceIDHash;

  my $count=0;
  foreach my $path (keys %{$memoryHash}) {

    foreach my $resourceID (keys %{${$memoryHash}{$path}}) {
      $resourceIDHash{$resourceID} = $path;
    }

  }
  return \%resourceIDHash;

}

sub writeHash(rrr){
  my ($self,$memoryContainerHash,$memoryFolderHash) = @_;

  tie(my %dbase, 'SDBM_File', pDrive::Config->DBM_CONTAINER_FILE,O_RDWR|O_CREAT, 0666) or die "can't open ".pDrive::Config->DBM_CONTAINER_FILE.": $!";

  foreach my $path (keys %{$memoryContainerHash}) {

    foreach my $resourceID (keys %{${$memoryContainerHash}{$path}}) {

      foreach my $key (keys %{pDrive::DBM->D}){
        $dbase{'C|'.$path.'|'.$resourceID.'|'.$key} = $$memoryContainerHash{$path}{$resourceID}[pDrive::DBM->D->{$key}] if ($$memoryContainerHash{$path}{$resourceID}[pDrive::DBM->D->{$key}] ne $dbase{'C|'.$path.'|'.$resourceID.'|'.$key});
      }

    }

  }

  foreach my $resourceID (keys %{$memoryFolderHash}) {
   
    my $subFolders;
    my $count=0;
    for (my $i=3; $i <= $#{$$memoryFolderHash{$resourceID}};$i++){
      $subFolders .= '|'.$$memoryFolderHash{$resourceID}[$i];

      if ($i%10==0){
        $dbase{'F|'.$resourceID.'|'.$$memoryFolderHash{$resourceID}[FOLDER_TITLE].'|'.$$memoryFolderHash{$resourceID}[FOLDER_ROOT].'|'.$$memoryFolderHash{$resourceID}[FOLDER_PARENT].'|'.$count} = $subFolders if ($subFolders ne $dbase{'F|'.$resourceID.'|'.$$memoryFolderHash{$resourceID}[FOLDER_TITLE].'|'.$$memoryFolderHash{$resourceID}[FOLDER_ROOT].'|'.$$memoryFolderHash{$resourceID}[FOLDER_PARENT].'|'.$count});
        $subFolders = '';
        $count++;
      } 
    }

    $dbase{'F|'.$resourceID.'|'.$$memoryFolderHash{$resourceID}[FOLDER_TITLE].'|'.$$memoryFolderHash{$resourceID}[FOLDER_ROOT].'|'.$$memoryFolderHash{$resourceID}[FOLDER_PARENT].'|'.$count} = $subFolders if ($subFolders ne $dbase{'F|'.$resourceID.'|'.$$memoryFolderHash{$resourceID}[FOLDER_TITLE].'|'.$$memoryFolderHash{$resourceID}[FOLDER_ROOT].'|'.$$memoryFolderHash{$resourceID}[FOLDER_PARENT].'|'.$count});

  }

  untie(%dbase);

}


sub writeValueContainerHash(rrrr){

  my ($self,$path,$resourceID, $memoryHash) = @_;

  tie(my %dbase, 'SDBM_File', pDrive::Config->DBM_CONTAINER_FILE,O_RDWR|O_CREAT, 0666) or die "can't open ".pDrive::Config->DBM_CONTAINER_FILE.": $!";

  foreach my $key (keys %{pDrive::DBM->D}){

    $dbase{$path.'|'.$resourceID.'|'.$key} = $$memoryHash{$path}{$resourceID}[pDrive::DBM->D->{$key}] if ($$memoryHash{$path}{$resourceID}[pDrive::DBM->D->{$key}] ne $dbase{$path.'|'.$resourceID.'|'.$key});

  }

  untie(%dbase);

}

sub printHash(r$){

  my $self = shift;
  my $filter = shift;

  print "(filter = $filter) Database ".pDrive::Config->DBM_CONTAINER_FILE." consists of the following key value pairs...\n";


  tie(my %dbase, 'SDBM_File', pDrive::Config->DBM_CONTAINER_FILE,O_RDWR|O_CREAT, 0666) or die "can't open ".pDrive::Config->DBM_CONTAINER_FILE.": $!";

  if ($filter ne ''){

    foreach my $key (keys %dbase) {
      next unless ($key =~ m%$filter%);
      print "$key: $dbase{$key}\n"; 
    }
  }else{
    foreach my $key (keys %dbase) {
      print "$key: $dbase{$key}\n"; 
    }
  }

  untie(%dbase);

}

sub getLastUpdated(rr){
  my ($self,$memoryHash) = @_;
  my @maxTimestamp;

  foreach my $path (keys %{$memoryHash}) {
    foreach my $resourceID (keys %{${$memoryHash}{$path}}) {
      next if ($resourceID eq '');

      my $timestamp = $$memoryHash{$path}{$resourceID}[pDrive::DBM->D->{'server_updated'}];
#print STDERR "$timestamp vs $$memoryHash{$path}{$resourceID}[pDrive::DBM->D->{'server_updated'}]\n";
#      $timestamp =~ s%\D+%%g;
#      ($timestamp) = $timestamp =~ m%^(\d{14})%; 
#      my $EPOC = pDrive::Time::getEPOC($timestamp);
      if ($timestamp > $maxTimestamp[pDrive::Time->A_TIMESTAMP]){
        $maxTimestamp[pDrive::Time->A_TIMESTAMP] = $timestamp;
        $maxTimestamp[pDrive::Time->A_DATE] = pDrive::Time::getDateEPOC($timestamp,-60*60*24);
       }

    }
  }

  return \@maxTimestamp;

}

sub fixTimestamps(rr){
  my ($self,$memoryHash) = @_;

  foreach my $path (keys %{$memoryHash}) {
    foreach my $resourceID (keys %{${$memoryHash}{$path}}) {
      next if ($resourceID eq '');
      if ($$memoryHash{$path}{$resourceID}[pDrive::DBM->D->{'server_updated'}] =~ m%\D+%){
        my $timestamp = $$memoryHash{$path}{$resourceID}[pDrive::DBM->D->{'server_updated'}];
        $timestamp =~ s%\D+%%g;
        ($timestamp) = $timestamp =~ m%^(\d{14})%; 
        $$memoryHash{$path}{$resourceID}[pDrive::DBM->D->{'server_updated'}] = pDrive::Time::getEPOC($timestamp);
      }
      if ($$memoryHash{$path}{$resourceID}[pDrive::DBM->D->{'local_updated'}] =~ m%\D+%){
        my $timestamp = $$memoryHash{$path}{$resourceID}[pDrive::DBM->D->{'local_updated'}];
        $timestamp =~ s%\D+%%g;
        ($timestamp) = $timestamp =~ m%^(\d{14})%; 
        $$memoryHash{$path}{$resourceID}[pDrive::DBM->D->{'local_updated'}] = pDrive::Time::getEPOC($timestamp);
      }

    }
  }

}

sub fixLocalMD5(rr){
  my ($self,$memoryHash) = @_;

  foreach my $path (keys %{$memoryHash}) {
    foreach my $resourceID (keys %{${$memoryHash}{$path}}) {
      next if ($resourceID eq '');
      next unless ($$memoryHash{$path}{$resourceID}[pDrive::DBM->D->{'local_md5'}] eq '');

      $$memoryHash{$path}{$resourceID}[pDrive::DBM->D->{'local_md5'}] = pDrive::FileIO::getMD5(pDrive::Config->LOCAL_PATH . '/' . $path);
    }
  }
}

sub fixServerMD5(rr){
  my ($self,$memoryHash) = @_;

  foreach my $path (keys %{$memoryHash}) {
    foreach my $resourceID (keys %{${$memoryHash}{$path}}) {
      next if ($resourceID eq '');
      next unless ($$memoryHash{$path}{$resourceID}[pDrive::DBM->D->{'server_md5'}] eq '');

      $$memoryHash{$path}{$resourceID}[pDrive::DBM->D->{'local_md5'}] = pDrive::FileIO::getMD5(pDrive::Config->LOCAL_PATH . '/' . $path);
    }
  }
}

sub clearMD5(rr){
  my ($self,$memoryHash) = @_;

  foreach my $path (keys %{$memoryHash}) {
    foreach my $resourceID (keys %{${$memoryHash}{$path}}) {
      next if ($resourceID eq '');

      $$memoryHash{$path}{$resourceID}[pDrive::DBM->D->{'local_md5'}] = '';
    }
  }
}

1;


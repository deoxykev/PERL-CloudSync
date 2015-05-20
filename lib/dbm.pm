package pDrive::DBM;

use Fcntl;
#use strict;

pDrive::Config->DBM_TYPE;

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


sub new(*) {

  	my $self = {_dbase => undef, _container => pDrive::Config->DBM_CONTAINER_FILE};


 	my $class = shift;
  	bless $self, $class;
	my $containerFile = shift;
  	if ($containerFile ne ''){
  		$self->{_container} = $containerFile;
  	}

  	return $self;

}




#
# Open the DBM provided
#
sub openDBM(**$){

	my $self = shift;
	my $file = shift;
	tie( my %dbase, pDrive::Config->DBM_TYPE, $file ,O_RDONLY, 0666) or die "can't open ". $file.": $!";
	return \%dbase;
}

#
# Close the DBM provided
#
sub closeDBM(**$){

	my $self = shift;
	my $dbase = shift;
	untie($dbase);
	return;

}

#
# Find key, given value
#
sub findValue(**$){

	my $self = shift;
	my $dbase = shift;
	my $findValue = shift;

	foreach my $key (keys $dbase){
			if ($$dbase{$key} eq $findValue){
				print STDOUT 'value = '. $findValue. ', key = '.$key ."\n";
				return $key;
			}
	}
	return;

}

#
# Find value, given key
#
sub findKey(**$){

	my $self = shift;
	my $dbase = shift;
	my $findKey = shift;

	foreach my $key (keys $dbase){
			if ($key eq $findKey  or $key eq $findKey.'_0' or $key eq $findKey.'_1'){
				print STDOUT 'found key = '.$key . "\n";
				print STDOUT $$dbase{$key} . "\n";
				return $$dbase{$key};
			}
	}
	return;
}

#
# Read login information from the login DBM
#
sub readLogin(*$){

	my $self = shift;
  	my $username = shift;
	tie(my %dbase, pDrive::Config->DBM_TYPE, $self->{_container},O_RDWR|O_CREAT, 0666) or die "can't open ".$self->{_container}.": $!";
	my $token = $dbase{$username . '|token'};
	my $refreshToken = $dbase{$username . '|refresh'};
	untie(%dbase);
    return ($token,$refreshToken);

}

#
# Create the memory has from the DBM
#
sub readHash(*){

  my $self = shift;
  my %returnContainerHash;
  my %returnFolderHash;

  tie(my %dbase, pDrive::Config->DBM_TYPE, $self->{_container},O_RDWR|O_CREAT, 0666) or die "can't open ".$self->{_container} .": $!";

  print STDOUT "reading readHash...\n" if (pDrive::Config->DEBUG);

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
      if (defined $resourceID){
        $returnFolderHash{$resourceID}[FOLDER_TITLE] = $title;
        $returnFolderHash{$resourceID}[FOLDER_ROOT] = $isRoot;
        $returnFolderHash{$resourceID}[FOLDER_PARENT] = $parentID;
      }
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

  print STDOUT "done\n" if (pDrive::Config->DEBUG);

  return (\%returnContainerHash,\%returnFolderHash);

}



sub constructResourceIDHash(**){

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


#
# Dump and write from memory hash to the DBM
#

sub writeHash(***){
  my ($self,$memoryContainerHash,$memoryFolderHash) = @_;

  tie(my %dbase, pDrive::Config->DBM_TYPE, $self->{_container},O_RDWR|O_CREAT, 0666) or die "can't open ".$self->{_container}.": $!";

  foreach my $path (keys %{$memoryContainerHash}) {

    foreach my $resourceID (keys %{${$memoryContainerHash}{$path}}) {

      foreach my $key (keys %{pDrive::DBM->D}){
        $dbase{'C|'.$path.'|'.$resourceID.'|'.$key} = $$memoryContainerHash{$path}{$resourceID}[pDrive::DBM->D->{$key}] if (defined $key and defined $resourceID and defined $path and defined $$memoryContainerHash{$path}{$resourceID}[pDrive::DBM->D->{$key}] and $$memoryContainerHash{$path}{$resourceID} and %dbase and $$memoryContainerHash{$path}{$resourceID}[pDrive::DBM->D->{$key}] ne $dbase{'C|'.$path.'|'.$resourceID.'|'.$key});
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


    $dbase{'F|'.$resourceID.'|'.$$memoryFolderHash{$resourceID}[FOLDER_TITLE].'|'.$$memoryFolderHash{$resourceID}[FOLDER_ROOT].'|'.$$memoryFolderHash{$resourceID}[FOLDER_PARENT].'|'.$count} = $subFolders if (defined $resourceID and defined $$memoryFolderHash{$resourceID} and defined $count and defined $subFolders and defined $$memoryFolderHash{$resourceID}[FOLDER_TITLE] and $$memoryFolderHash{$resourceID}[FOLDER_ROOT] and $$memoryFolderHash{$resourceID}[FOLDER_PARENT] and $subFolders ne $dbase{'F|'.$resourceID.'|'.$$memoryFolderHash{$resourceID}[FOLDER_TITLE].'|'.$$memoryFolderHash{$resourceID}[FOLDER_ROOT].'|'.$$memoryFolderHash{$resourceID}[FOLDER_PARENT].'|'.$count});

  }

  untie(%dbase);

}

#
# Write login informations to DBM
#

sub writeLogin(*$$$){
	my $self = shift;
	my $username = shift;
	my $token = shift;
	my $refreshToken = shift;

	tie(my %dbase, pDrive::Config->DBM_TYPE, $self->{_container},O_RDWR|O_CREAT, 0666) or die "can't open ".$self->{_container}.": $!";

	$dbase{$username . '|token'} = $token if $token ne $dbase{$username . '|token'};
	$dbase{$username . '|refresh'} = $refreshToken if $refreshToken ne $dbase{$username . '|refresh'};

	 untie(%dbase);

}

sub writeValueContainerHash(****){

  my ($self,$path,$resourceID, $memoryHash) = @_;

  tie(my %dbase, pDrive::Config->DBM_TYPE, $self->{_container},O_RDWR|O_CREAT, 0666) or die "can't open ".$self->{_container}.": $!";

  foreach my $key (keys %{pDrive::DBM->D}){

    $dbase{$path.'|'.$resourceID.'|'.$key} = $$memoryHash{$path}{$resourceID}[pDrive::DBM->D->{$key}] if ($$memoryHash{$path}{$resourceID}[pDrive::DBM->D->{$key}] ne $dbase{$path.'|'.$resourceID.'|'.$key});

  }

  untie(%dbase);

}




#
# Dump the DBM Hash to the screen
#
sub dumpHash(*$){

  my $self = shift;
  my $dbase = shift;

  print "(filter = $filter) Database consists of the following key value pairs...\n";

  if ($filter ne ''){

    foreach my $key (keys $dbase) {
      next unless ($key =~ m%$filter%);
      print "$key: $$dbase{$key}\n";
    }
  }else{
    foreach my $key (keys $dbase) {
      print "$key: $$dbase{$key}\n";
    }
  }

}


#
# Dump the DBM Hash to the screen
sub printHash(*$$){

  my $self = shift;
  my $dbfile = shift;
  my $filter = shift;

  print "(filter = $filter) Database ".$dbfile." consists of the following key value pairs...\n";


  tie(my %dbase, pDrive::Config->DBM_TYPE, $dbfile,O_RDONLY, 0666) or die "can't open ".$dbfile.": $!";

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

#
# update  the key in the hash
sub updateHashKey(*$$$){

	my $self = shift;
 	my $dbfile = shift;
 	my $filter = shift;
  	my $filterChange = shift;

  	tie(my %dbase, pDrive::Config->DBM_TYPE, $dbfile,O_RDWR|O_CREAT, 0666) or die "can't open ".$dbfile.": $!";

  	if ($filter ne ''){

    	foreach my $key (keys %dbase) {
      		next unless ($key =~ m%$filter%);
      		my $newKey = $key;
      		$newKey =~ s%$filter%$filterChange%;
      		$dbase{$newKey} = $dbase{$key};
      		print "Saved new key $dbase{$key} $newKey with value ".$dbase{$newKey}."\n";
    	}
  	}

  	untie(%dbase);

}
#
# Retrieve the timestamp of the most recent record
#
sub getLastUpdated(**){
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
      if (defined $timestamp and (not defined $maxTimestamp[pDrive::Time->A_TIMESTAMP] or $timestamp > $maxTimestamp[pDrive::Time->A_TIMESTAMP])){
        $maxTimestamp[pDrive::Time->A_TIMESTAMP] = $timestamp;
        $maxTimestamp[pDrive::Time->A_DATE] = pDrive::Time::getDateEPOC($timestamp,-60*60*24);
       }

    }
  }

  return \@maxTimestamp;

}


# TEMPORARY:
# correct corrupt timestamps
#
sub fixTimestamps(**){
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



1;


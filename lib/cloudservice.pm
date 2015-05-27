package pDrive::CloudService;
	use Fcntl;

use constant CHUNKSIZE => (8*256*1024);
sub test(){
	return "xxxx";
}


sub traverseFolder($){

  my $resourceID = shift;

  for (my $i=FOLDER_SUBFOLDER; $i <= $#{${$folders}{$resourceID}}; $i++){

    print STDOUT "\t $$folders{$$folders{$resourceID}[$i]}[FOLDER_TITLE]\n";

    if ( $#{${$folders}{${$folders}{$resourceID}}} >= FOLDER_SUBFOLDER ){
      &traverseFolder($$folders{$resourceID}[$i]);
    }

  }

}
sub updateChange(**){

	my $self = shift;
	my $changeID = shift;

	tie(my %dbase, pDrive::Config->DBM_TYPE, $self->{_db_checksum} ,O_RDWR|O_CREAT, 0666) or die "can't open checksum: $!";
	$dbase{'LAST_CHANGE'} = $changeID;
	untie(%dbase);

}

##
# multiple NIC cards:
# bind to a specific IP
##
sub bindIP(*$){

	my $self = shift;
  	my $IP = shift;

  	$self->{_serviceapi}->bindIP($IP);

}
1;
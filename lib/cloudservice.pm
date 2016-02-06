package pDrive::CloudService;
	use Fcntl;

#use lib "$FindBin::Bin/../lib";
#require 'lib/dbm.pm';

#use constant CHUNKSIZE => (8*256*1024);
use constant CHUNKSIZE => (128*256*1024);
use constant CHECKSUM => 0;
use constant FISI => 1;
use constant MEMORY_CHECKSUM => 2;

open(OUTPUT, '>-');
my $dbm = pDrive::DBM->new();


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
	my $URL = shift;

	tie(my %dbase, pDrive::Config->DBM_TYPE, $self->{_db_checksum} ,O_RDWR|O_CREAT, 0666) or die "can't open checksum: $!";
	$dbase{'LAST_CHANGE'} = $changeID unless  (not defined ($changeID) or $changeID eq '');
	$dbase{'URL'} = $URL;
	untie(%dbase);

}


sub resetChange(**){

	my $self = shift;
	tie(my %dbase, pDrive::Config->DBM_TYPE, $self->{_db_checksum} ,O_RDWR|O_CREAT, 0666) or die "can't open checksum: $!";
	$dbase{'LAST_CHANGE'} = '';
	$dbase{'URL'} = '';
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

sub setOutput(*$){
	my $self = shift;

	open(OUTPUT, '>>'.shift);
}


sub dumpFolder(*$$$){
	my $self = shift;
	my $folder = shift;
	my $folderID = shift;
	my $service = shift;

	my $nextURL = '';
	my @subfolders;

	push(@subfolders, $folderID);

	for (my $i=0; $i <= $#subfolders;$i++){
		$folderID = $subfolders[$i];
		while (1){

			my $newDocuments =  $service->getSubFolderIDList($folderID, $nextURL);

  			foreach my $resourceID (keys %{$newDocuments}){
	  			#	folder
  				 if  ($$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}] eq ''){
					push(@subfolders, $resourceID);
  			 	}else{
					print OUTPUT $resourceID."\t". $$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}]."\t". $$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}]."\t". $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}]. "\n";
  				}

			}
			$nextURL = $service->{_nextURL};
			print STDOUT "next url " . $nextURL. "\n";
  			last if  $nextURL eq '';

	  	}

	}

}


1;

package pDrive::CloudService;
	use Fcntl;

#use lib "$FindBin::Bin/../lib";
#require 'lib/dbm.pm';


use constant CHECKSUM => 0;
use constant FISI => 1;
use constant MEMORY_CHECKSUM => 2;

open(OUTPUT, '>-');
##my $dbm = pDrive::DBM->new();

sub buildMemoryDBM()
 {	my %dbase; return \%dbase;};

sub loadFolders(*){
	my $self = shift;
	$self->{_folders_dbm} = buildMemoryDBM();#$self->{_login_dbm}->openDBMForUpdating( 'gd.'.$self->{_username} . '.folders.db');
}

sub unloadFolders(*){
	my $self = shift;
	#untie($self->{_folders_dbm});
}


sub auditON(*){
	my $self = shift;
	$self->{_audit} = 1;
	#untie($self->{_folders_dbm});
	print STDERR "audit on\n";
}

sub test(*){
	my $self = shift;
  	$self->{_serviceapi}->test();

}

sub mergeFolder(*$$$){
	my $self = shift;
	my $folderID1 = shift;
	my $folderID2 = shift;
	my $recusiveLevel = shift;

    if ($recusiveLevel eq ''){
    	$recusiveLevel = 999;
    }

	#construct folders (target)
	my %folders1;
	while (1){

			my $newDocuments =  $self->getSubFolderIDList($folderID1, $nextURL);

  			foreach my $resourceID (keys %{$newDocuments}){
	  			#	folder
  				 if  ($$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}] eq ''){
  				 	my $title = lc $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}] ;
  				 	$folders1{$title} = $resourceID;
  				}

			}
			$nextURL = $self->{_nextURL};
			print STDOUT "next url " . $nextURL. "\n";
  			last if  $nextURL eq '';

	}

	my %folders2;
	while (1){

			my $newDocuments =  $self->getSubFolderIDList($folderID2, $nextURL);

  			foreach my $resourceID (keys %{$newDocuments}){
	  			#	folder
  				 if  ($$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}] eq '' ){
  				 	my $title = lc $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}] ;
					#merge subfolder
  				 	if  ($folders1{$title} ne '' and $recusiveLevel > 0){
						$self->mergeFolder($folders1{$title}, $resourceID, $recusiveLevel-1) if $recusiveLevel > 0;
  				 	#move subfolder
  				 	}else{
						$self->moveFile($resourceID, $folderID1, $folderID2);
  				 	}

				#move file from 2 to 1
  				}else{
						$self->moveFile($resourceID, $folderID1, $folderID2);
  				}

			}
			$nextURL = $self->{_nextURL};
			print STDOUT "next url " . $nextURL. "\n";
  			last if  $nextURL eq '';

	}


}



sub mergeDuplicateFolder(*$$){
	my $self = shift;
	my $folderID = shift;
	my $recusiveLevel = shift;

    if ($recusiveLevel eq ''){
    	$recusiveLevel = 999;
    }
	#construct folders (target)
	my %folders;
	while (1){

			my $newDocuments =  $self->getSubFolderIDList($folderID, $nextURL);

  			foreach my $resourceID (keys %{$newDocuments}){
	  			#	folder
  				 if  ($$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}] eq ''){
  				 	$self->mergeDuplicateFolder($resourceID,$recusiveLevel-1) if $recusiveLevel > 0;
  				 	my $title = lc $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}] ;

					#duplicate folder; merge
  				 	if ($folders{$title} ne ''){
  				 		my $safeNext = $self->{_nextURL};
  				 		$self->mergeFolder($folders{$title}, $resourceID,0);
  				 		$self->trashEmptyFolders($resourceID,0);
  				 		$self->{_nextURL} = $safeNext;
  				 	}else{
	  				 	$folders{$title} = $resourceID;
  				 	}

  				}

			}
			$nextURL = $self->{_nextURL};
			print STDOUT "next url " . $nextURL. "\n";
  			last if  $nextURL eq '';

	}

}

sub moveFile(*$$){

	my $self = shift;
	my $file = shift;
	my $toFolder = shift;
	my $fromFolder = shift;

	return $self->{_serviceapi}->moveFile($file, $toFolder, $fromFolder);

}

sub moveFolder(*$$){

	my $self = shift;
	my $folder = shift;
	my $toFolder = shift;
	my $fromFolder = shift;

	return $self->moveFile($folder, $toFolder, $fromFolder);

}

# pull inner folders out by 1
##doesn't work
sub collapseFolders(*$){
	my $self = shift;
	my $folderID = shift;
	my $pull = shift;
	my $parentFolderID = shift;


	#construct folders (target)
	my %folders;
	while (1){

			my $newDocuments =  $self->getSubFolderIDList($folderID, $nextURL);

  			foreach my $resourceID (keys %{$newDocuments}){
	  			#folder
	  			my $folderName;
  				if  ($pull and $$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}] eq ''){
  					$self->moveFolder($resourceID, $folderID, $parentFolderID);
  				}elsif ($$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}] eq ''){
  					$self->collapseFolders($resourceID, 1, $folderID);
  				#file
  				}else{
  				}

  			}

			#}
			$nextURL = $self->{_nextURL};
			print STDOUT "next url " . $nextURL. "\n";
  			last if  $nextURL eq '';

	}

}

sub alphabetizeFolder(*$){
	my $self = shift;
	my $folderID = shift;


	#construct folders (target)
	my %folders;
	while (1){

			my $newDocuments =  $self->getSubFolderIDList($folderID, $nextURL);

  			foreach my $resourceID (keys %{$newDocuments}){
	  			#folder (exclude alpha folders themselves)
	  			my $folderName;
  				if  ($$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}] eq ''){
  				 	($folderName) = $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}] =~ m%^(\S)\S+% ;
  				#file
  				}else{
  				 	($folderName) = $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}] =~ m%^(\S)% ;
  				}
  				$folderName = lc $folderName;
  				if ($folderName ne '' and $folders{$folderName} eq ''){
  				 		my $subfolderID = $self->createFolder($folderName, $folderID);
  				 		$folders{$folderName} = $subfolderID;
  				 		$self->moveFile($resourceID, $folders{$folderName}, $folderID);
  				}elsif ($folderName ne '' and $folders{$folderName} ne ''){
  				 		$self->moveFile($resourceID, $folders{$folderName}, $folderID);
  				}

  			}

			#}
			$nextURL = $self->{_nextURL};
			print STDOUT "next url " . $nextURL. "\n";
  			last if  $nextURL eq '';

	}

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


sub auditLog(*$){
  my $self = shift;
  my $event = shift;

  return if $event eq '';

  open (AUDITLOG, '>>' . pDrive::Config->AUDITFILE) or die('Cannot access audit file ' . pDrive::Config->AUDITFILE);
  print AUDITLOG  $event . "\n";
  close (AUDITLOG);

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

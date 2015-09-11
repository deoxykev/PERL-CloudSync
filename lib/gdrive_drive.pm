package pDrive::gDrive;

our @ISA = qw(pDrive::CloudService);

use Fcntl;


# magic numbers
use constant IS_ROOT => 1;
use constant NOT_ROOT => 0;

use constant FOLDER_TITLE => 0;
use constant FOLDER_ROOT => 1;
use constant FOLDER_PARENT => 2;
use constant FOLDER_SUBFOLDER => 3;


#my $types = {'document' => ['doc','html'],'drawing' => 'png', 'pdf' => 'pdf','presentation' => 'ppt', 'spreadsheet' => 'xls'};
my $types = {'document' => ['doc','html'],'drawing' => 'png', 'presentation' => 'ppt', 'spreadsheet' => 'xls'};
#my $types = {'document' => ['doc','html'],'drawing' => 'png', 'presentation' => 'ppt', 'spreadsheet' => 'xls'};

sub new(*$) {

  	my $self = {_serviceapi => undef,
               _login_dbm => undef,
              _dbm => undef,
  			  _nextURL => '',
  			  _username => undef,
  			  _folders_dbm => undef,
  			  _db_checksum => undef,
  			  _db_fisi => undef};

  	my $class = shift;
  	bless $self, $class;
	$self->{_username} = shift;
	$self->{_db_checksum} = 'gd.'.$self->{_username} . '.md5.db';
	$self->{_db_fisi} = 'gd.'.$self->{_username} . '.fisi.db';



  	# initialize web connections
  	$self->{_serviceapi} = pDrive::GoogleDriveAPI2->new(pDrive::Config->CLIENT_ID,pDrive::Config->CLIENT_SECRET);

  	my $loginsDBM = pDrive::DBM->new('./gd.'.$self->{_username}.'.db');
#  	my $loginsDBM = pDrive::DBM->new(pDrive::Config->DBM_LOGIN_FILE);
  	$self->{_login_dbm} = $loginsDBM;
  	my ($token,$refreshToken) = $loginsDBM->readLogin($self->{_username});

	$self->{_folders_dbm} = $loginsDBM->openDBMForUpdating( 'gd.'.$self->{_username} . '.folders.db');


	# no token defined
	if ($token eq '' or  $refreshToken  eq ''){
		my $code;
		my  $URL = 'https://accounts.google.com/o/oauth2/auth?scope=https://www.googleapis.com/auth/drive&redirect_uri=urn:ietf:wg:oauth:2.0:oob&response_type=code&client_id='.pDrive::Config->CLIENT_ID;
		print STDOUT "visit $URL\n";
		print STDOUT 'Input Code:';
		$code = <>;
		print STDOUT "code = $code\n";
 	  	($token,$refreshToken) = $self->{_serviceapi}->getToken($code);
	  	$self->{_login_dbm}->writeLogin($self->{_username},$token,$refreshToken);
	}else{
		$self->{_serviceapi}->setToken($token,$refreshToken);
	}

	# token expired?
	if (!($self->{_serviceapi}->testAccess())){
		# refresh token
 	 	($token,$refreshToken) = $self->{_serviceapi}->refreshToken();
		$self->{_serviceapi}->setToken($token,$refreshToken);
	  	$self->{_login_dbm}->writeLogin($self->{_username},$token,$refreshToken);
	}
	return $self;

}

sub loadFolders(*){
	my $self = shift;
	$self->{_folders_dbm} = $self->{_login_dbm}->openDBMForUpdating( 'gd.'.$self->{_username} . '.folders.db');
}

sub unloadFolders(*){
	my $self = shift;
	untie($self->{_folders_dbm});
}


sub downloadFile(*$$$){

      my ($self,$path,$link,$updated) = @_;
      my $returnStatus;
      my $finalPath = pDrive::Config->LOCAL_PATH."/$path";

      pDrive::FileIO::traverseMKDIR($finalPath);
      print STDOUT "downloading $finalPath...";

      # a simple non-google-doc file
      $returnStatus = $self->{_serviceapi}->downloadFile($finalPath,$link,$updated);

}



sub createFolder(*$$){

	my $self = shift;
	my $folder = shift;
	my $parentFolder = shift;

	return $self->{_serviceapi}->createFolder('https://www.googleapis.com/drive/v2/files?fields=id',$folder, $parentFolder);

}

sub getSubFolderID(*$$){

	my $self = shift;
	my $folderName = shift;
	my $parentID = shift;

	my $URL = 'https://www.googleapis.com/drive/v2/files?q=\''. $parentID.'\'+in+parents&fields=nextLink%2Citems(kind%2Cid%2CmimeType%2Ctitle%2CfileSize%2CmodifiedDate%2CcreatedDate%2CdownloadUrl%2Cparents/parentLink%2Cmd5Checksum)';

	my $driveListings = $self->{_serviceapi}->getList($URL);
  	my $newDocuments = $self->{_serviceapi}->readDriveListings($driveListings);

  	foreach my $resourceID (keys %{$newDocuments}){
    	if ($$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}] eq $folderName){
    		print STDERR "returning $resourceID\n ";
    		return $resourceID;
    	}
	}
	return '';

}

sub getSubFolderIDList(*$$){

	my $self = shift;
	my $folderName = shift;
	my $URL = shift;

	if ($URL eq ''){
		$URL = 'https://www.googleapis.com/drive/v2/files?q=\''. $folderName.'\'+in+parents&fields=nextLink%2Citems(kind%2Cid%2CmimeType%2Ctitle%2CfileSize%2CmodifiedDate%2CcreatedDate%2CdownloadUrl%2Cparents/parentLink%2Cmd5Checksum)';
	}


	my $driveListings = $self->{_serviceapi}->getList($URL);
  	my $newDocuments = $self->{_serviceapi}->readDriveListings($driveListings);

	$self->{_nextURL} =  $self->{_serviceapi}->getNextURL($driveListings);
	#$self->updateMD5Hash($newDocuments);
	return $newDocuments;

}

sub uploadFolder(*$$){
	my $self = shift;
	my $localPath = shift;
	my $serverPath = shift;
	my $parentFolder = shift;

    my ($folder) = $localPath =~ m%\/([^\/]+)$%;

#	if ($serverPath ne ''){
		$serverPath .= $folder;
#	}
  	print STDOUT "path = $localPath\n";
   	my @fileList = pDrive::FileIO::getFilesDir($localPath);

	print STDOUT "folder = $folder\n";

	#check server-cache for folder
	my $folderID = $self->{_login_dbm}->findFolder($self->{_folders_dbm}, $serverPath);
	#folder doesn't exist, create it
	if ($folderID eq ''){
		#*** validate it truly doesn't exist on the server before creating
		#this is the parent?
		if ($parentFolder eq ''){
			#look at the root
			#get root's children, look for folder as child
			$folderID = $self->getSubFolderID($folder,'root');
		}else{
			#look at the parent
			#get parent's children, look for folder as child
			$folderID = $self->getSubFolderID($folder,$parentFolder);
		}
		if ($folderID eq '' and $parentFolder ne ''){
			$folderID = $self->createFolder($folder, $parentFolder);
		}elsif ($folderID eq '' and  $parentFolder eq ''){
			$folderID = $self->createFolder($folder, 'root');
		}
		$self->{_login_dbm}->addFolder($self->{_folders_dbm}, $serverPath, $folderID) if ($folderID ne '');
	}



	print "resource ID = " . $folderID . "\n";

    for (my $i=0; $i <= $#fileList; $i++){

    	#empty file; skip
    	if (-z $fileList[$i]){
			next;
    	#folder
    	}elsif (-d $fileList[$i]){
	  		my $fileID = $self->uploadFolder($fileList[$i], $serverPath, $folderID);
    	# file
    	}else{
    		my $process = 1;
    		#look for md5 file
    		for (my $j=0; $j <= $#fileList; $j++){
    			my $value = $fileList[$i];
    			my ($file,$md5) = $fileList[$j] =~ m%[^\/]+\/\.(.*?)\.([^\.]+)$%;
    			my ($currentFile) = $fileList[$i] =~ m%\/([^\/]+)$%;

    			if ($file eq $currentFile and $md5 ne ''){
    				tie(my %dbase, pDrive::Config->DBM_TYPE, $self->{_db_checksum} ,O_RDONLY, 0666) or die "can't open md5: $!";
    				if (  (defined $dbase{$md5.'_'} and $dbase{$md5.'_'} ne '') or (defined $dbase{$md5.'_0'} and $dbase{$md5.'_0'} ne '')){
    					$process = 0;
				    	#pDrive::masterLog("skipped file (checksum $md5 exists ".$dbase{$md5.'_0'}.") - $fileList[$i]\n");
    					last;
	    			}
    				untie(%dbase);
    			}
    		}
    		#calculate the fisi
			my ($fileName) = $fileList[$i] =~ m%\/([^\/]+)$%;
			my $fileSize = -s $fileList[$i];
 			my $fisi = pDrive::FileIO::getMD5String($fileName .$fileSize);
    		tie(my %dbase, pDrive::Config->DBM_TYPE, $self->{_db_fisi} ,O_RDONLY, 0666) or die "can't open fisi: $!";
    		if (  (defined $dbase{$fisi.'_'} and $dbase{$fisi.'_'} ne '') or (defined $dbase{$fisi.'_0'} and $dbase{$fisi.'_0'} ne '')){
    					$process = 0;
				    	#pDrive::masterLog("skipped file (fisi $fisi exists ".$dbase{$fisi.'_0'}.") - $fileList[$i]\n");
	    	}
    		untie(%dbase);
			if ($process){
				print STDOUT "Upload $fileList[$i]\n";
		  		my $fileID = $self->uploadFile($fileList[$i], $folderID);
    		}else{
				print STDOUT "SKIP $fileList[$i]\n";
	    	}
    	}
	  	print STDOUT "\n";
	}
}


sub createUploadListForFolder(*$$$$){
	my $self = shift;
	my $localPath = shift;
	my $serverPath = shift;
	my $parentFolder = shift;
	my $listHandler = shift;

    my ($folder) = $localPath =~ m%\/([^\/]+)$%;

#	if ($serverPath ne ''){
		$serverPath .= $folder;
#	}
  	print STDOUT "path = $localPath\n";
   	my @fileList = pDrive::FileIO::getFilesDir($localPath);

	print STDOUT "folder = $folder\n";

	#check server-cache for folder
	my $folderID = $self->{_login_dbm}->findFolder($self->{_folders_dbm}, $serverPath);
	#folder doesn't exist, create it
	if ($folderID eq ''){
		#*** validate it truly doesn't exist on the server before creating
		#this is the parent?
		if ($parentFolder eq ''){
			#look at the root
			#get root's children, look for folder as child
			$folderID = $self->getSubFolderID($folder,'root');
		}else{
			#look at the parent
			#get parent's children, look for folder as child
			$folderID = $self->getSubFolderID($folder,$parentFolder);
		}
		if ($folderID eq '' and $parentFolder ne ''){
			$folderID = $self->createFolder($folder, $parentFolder);
		}elsif ($folderID eq '' and  $parentFolder eq ''){
			$folderID = $self->createFolder($folder, 'root');
		}
		$self->{_login_dbm}->addFolder($self->{_folders_dbm}, $serverPath, $folderID) if ($folderID ne '');
	}



	print "resource ID = " . $folderID . "\n";

    for (my $i=0; $i <= $#fileList; $i++){

    	#empty file; skip
    	if (-z $fileList[$i]){
			next;
    	#folder
    	}elsif (-d $fileList[$i]){
	  		my $fileID = $self->createUploadListForFolder($fileList[$i], $serverPath, $folderID, $listHandler);
    	# file
    	}else{
    		my $process = 1;
    		#look for md5 file
    		for (my $j=0; $j <= $#fileList; $j++){
    			my $value = $fileList[$i];
    			my ($file,$md5) = $fileList[$j] =~ m%[^\/]+\/\.(.*?)\.([^\.]+)$%;
    			my ($currentFile) = $fileList[$i] =~ m%\/([^\/]+)$%;

    			if ($file eq $currentFile and $md5 ne ''){
    				tie(my %dbase, pDrive::Config->DBM_TYPE, $self->{_db_checksum} ,O_RDONLY, 0666) or die "can't open md5: $!";
    				if (  (defined $dbase{$md5.'_'} and $dbase{$md5.'_'} ne '') or (defined $dbase{$md5.'_0'} and $dbase{$md5.'_0'} ne '')){
    					$process = 0;
    					last;
	    			}
    				untie(%dbase);
    			}
    		}
			if ($process){
				print STDOUT "Upload $fileList[$i]\n";
				print {$listHandler} "$fileList[$i]	$folderID\n";

    		}else{
				print STDOUT "SKIP $fileList[$i]\n";
	    	}
    	}
	  	print STDOUT "\n";
	}
}

#
# get list of the content in the Google Drive
##
sub getFolderInfo(*$){

	my $self = shift;
	my $id = shift;

	my $hasMore=1;
	my $title;
	my $path = -1;
	while ($hasMore){
		($hasMore, $title,$id) = $self->{_serviceapi}->getFolderInfo($id);
		if ($path == -1){
			$path = $title;
		}else{
			$path = $title  . '/' . $path;
		}
#	    	print STDOUT "path = $path, title = $title, id = $id\n";
	}
	return $path;
}

sub uploadFile(*$$){

	my $self = shift;
	my $file = shift;
	my $folder = shift;
	my $fileName = shift;

	if ($fileName eq ''){
		($fileName) = $file =~ m%\/([^\/]+)$%;
	}

	print STDOUT $file . "\n";

  	my $fileSize =  -s $file;
  	return 0 if $fileSize == 0;
  	my $filetype = 'application/octet-stream';
  	print STDOUT "file size for $file ($fileName)  is $fileSize to folder $folder\n" if (pDrive::Config->DEBUG);

  	my $uploadURL = $self->{_serviceapi}->createFile('https://www.googleapis.com/upload/drive/v2/files?fields=id&convert=false&uploadType=resumable',$fileSize,$fileName,$filetype, $folder);


  	my $chunkNumbers = int($fileSize/(pDrive::CloudService->CHUNKSIZE))+1;
	my $pointerInFile=0;
  	print STDOUT "file number is $chunkNumbers\n" if (pDrive::Config->DEBUG);
  	open(INPUT, "<".$file) or die ('cannot read file '.$file);

  	binmode(INPUT);

  	my $fileID=0;
  	my $retrycount=0;

  	for (my $i=0; $i < $chunkNumbers; $i++){
		my $chunkSize =pDrive::CloudService->CHUNKSIZE;
		my $chunk;
    	if ($i == $chunkNumbers-1){
	    	$chunkSize = $fileSize - $pointerInFile;
    	}

    	sysread INPUT, $chunk, pDrive::CloudService->CHUNKSIZE;
    	print STDERR "\r".$i . '/'.$chunkNumbers;
    	my $status=0;
    	$retrycount=0;
    	while ($status eq '0' and $retrycount < 10){
			$status = $self->{_serviceapi}->uploadFile($uploadURL,\$chunk,$chunkSize,'bytes '.$pointerInFile.'-'.($i == $chunkNumbers-1? $fileSize-1: ($pointerInFile+$chunkSize-1)).'/'.$fileSize,$filetype);
      		print STDOUT "\r"  . $status;
	      	if ($status eq '0'){
	       		print STDERR "...retrying\n";
	       		#some other instance may have updated the tokens already, refresh with the latest
	       		if ($retrycount == 0){
	       			my ($token,$refreshToken) = $self->{_login_dbm}->readLogin($self->{_username});
	       			$self->{_serviceapi}->setToken($token,$refreshToken);
	       		#multiple failures, force-fech a new token
	       		}else{
 	 				my ($token,$refreshToken) = $self->{_serviceapi}->refreshToken();
	  				$self->{_login_dbm}->writeLogin( $self->{_username},$token,$refreshToken);
	       			$self->{_serviceapi}->setToken($token,$refreshToken);
	       		}
        		sleep (10);
        		$retrycount++;
	      	}

    	}
		if ($retrycount >= 10){
			print STDERR "\r" . $file . "'...retry failed - $file\n";

    		pDrive::masterLog("failed chunk $pointerInFile (all attempts failed) - $file\n");
    		last;
		}

    	$fileID=$status;
		$pointerInFile += $chunkSize;
  	}
  	if ($retrycount < 10){
		print STDOUT "\r" . $file . "'...success - $file\n";
  	}
  	close(INPUT);
}

sub getList(*){

	my $self = shift;
	my $driveListings = $self->{_serviceapi}->getList($self->{_nextURL});
  	my $newDocuments = $self->{_serviceapi}->readDriveListings($driveListings);

#  	foreach my $resourceID (keys $newDocuments){
 #   	print STDOUT 'new document -> '.$$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}] . ', '. $$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}] . "\n";
#	}

	#print STDOUT $$driveListings . "\n";
	$self->{_nextURL} =  $self->{_serviceapi}->getNextURL($driveListings);
	#$self->updateMD5Hash($newDocuments);
	return $newDocuments;
}


sub getListRoot(*){

	my $self = shift;
	print STDOUT "root = " . $self->{_serviceapi}->getListRoot('') . "\n";

}

sub getListAll(*){

	my $self = shift;

	my $nextURL = '';
	while (1){
		my $driveListings = $self->{_serviceapi}->getList($nextURL);
  		my $newDocuments = $self->{_serviceapi}->readDriveListings($driveListings);
  		$nextURL = $self->{_serviceapi}->getNextURL($driveListings);
		$self->updateMD5Hash($newDocuments);
		print STDOUT "next url " . $nextURL . "\n";
  		last if $nextURL eq '';
	}

}


sub readDriveListings(**){

	my $self = shift;
	my $driveListings = shift;
	return $self->{_serviceapi}->readDriveListings($driveListings);

}

sub getChangesAll(*){

	my $self = shift;

	my $nextURL = '';
    tie(my %dbase, pDrive::Config->DBM_TYPE, $self->{_db_checksum} ,O_RDONLY, 0666) or die "can't open md5: $!";
    my $changeID = $dbase{'LAST_CHANGE'};
    print STDOUT "changeID = " . $changeID . "\n";
    untie(%dbase);

	while (1){
		my $driveListings = $self->{_serviceapi}->getChanges($nextURL, $changeID);
  		$nextURL = $self->{_serviceapi}->getNextURL($driveListings);
  		my $newDocuments = $self->{_serviceapi}->readChangeListings($driveListings);
		$self->updateMD5Hash($newDocuments);
		$changeID = $self->{_serviceapi}->getChangeID($driveListings);
		print STDOUT "next url " . $nextURL . "\n";
  		last if $nextURL eq '';
	}
	#print STDOUT $$driveListings . "\n";
	$self->updateChange($changeID);

}

sub updateMD5Hash(**){

	my $self = shift;
	my $newDocuments = shift;

	my $createdCountMD5=0;
	my $skippedCountMD5=0;
	my $createdCountFISI=0;
	my $skippedCountFISI=0;
	tie(my %dbase, pDrive::Config->DBM_TYPE, $self->{_db_checksum} ,O_RDWR|O_CREAT, 0666) or die "can't open md5: $!";
	foreach my $resourceID (keys %{$newDocuments}){
		next if $$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}] eq '';
		for (my $i=0; 1; $i++){
			# if MD5 exists,
			if (defined $dbase{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_'. $i}){
				# validate it is the same file, if so, skip, otherwise move onto another md5 slot
				if  ($dbase{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_'. $i}  eq $resourceID){
					$skippedCountMD5++;
					last;
				}else{
					#move onto next slot
				}
			#	create
			}else{
				$dbase{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_'. $i} = $resourceID;
				$createdCountMD5++;
				last;
			}
		}
	}
	untie(%dbase);
	tie( %dbase, pDrive::Config->DBM_TYPE, $self->{_db_fisi} ,O_RDWR|O_CREAT, 0666) or die "can't open fisi: $!";
	foreach my $resourceID (keys %{$newDocuments}){
		next if $$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}] eq '';
		for (my $i=0; 1; $i++){
			# if MD5 exists,
			if (defined $dbase{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}].'_'. $i}){
				# validate it is the same file, if so, skip, otherwise move onto another md5 slot
				if  ($dbase{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}].'_'. $i}  eq $resourceID){
					$skippedCountFISI++;
					last;
				}else{
					#move onto next slot
				}
			#	create
			}else{
				$dbase{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}].'_'. $i} = $resourceID;
				$createdCountFISI++;
				last;
			}
		}
	}
	untie(%dbase);
	print STDOUT "MD5: created = $createdCountMD5, skipped = $skippedCountMD5\n";
	print STDOUT "FISI: created = $createdCountFISI, skipped = $skippedCountFISI\n";


}


sub createFolderByPath(*$){

	my $self = shift;
	my $path = shift;

	my $parentFolder= '';
	my $folderID;
	#$path =~ s%^\/%%;

	#remove double // occurrences (make single /)
	$path =~ s%\/\/%\/%g;

	my $serverPath = '';
	while(my ($folder) = $path =~ m%^\/?([^\/]+)%){

    	$path =~ s%^\/?[^\/]+%%;
		$serverPath .= $folder;

		#check server-cache for folder
		$folderID = $self->{_login_dbm}->findFolder($self->{_folders_dbm}, $serverPath);
		#	folder doesn't exist, create it
		if ($folderID eq ''){
			#*** validate it truly doesn't exist on the server before creating
			#this is the parent?
			if ($parentFolder eq ''){
				#look at the root
				#	get root's children, look for folder as child
				$folderID = $self->getSubFolderID($folder,'root');
				$parentFolder =$folderID if ($folderID ne '');
			}else{
				#look at the parent
				#get parent's children, look for folder as child
				$folderID = $self->getSubFolderID($folder,$parentFolder);
				$parentFolder =$folderID if ($folderID ne '');
			}

			if ($folderID eq '' and $parentFolder ne ''){
				$folderID = $self->createFolder($folder, $parentFolder);
				$parentFolder =$folderID if ($folderID ne '');
			}elsif ($folderID eq '' and  $parentFolder eq ''){
				$folderID = $self->createFolder($folder, 'root');
				$parentFolder =$folderID if ($folderID ne '');
			}
			#	$self->{_login_dbm}->addFolder($self->{_folders_dbm}, $serverPath, $folderID) if ($folderID ne '');
		}

	}
	return $folderID;

}




1;


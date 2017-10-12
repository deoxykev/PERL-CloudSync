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
use constant RETRY_COUNT => 3;

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
  			  _dbm => undef,
  			  _audit => 0,
  			  _paths => undef,
  			  _db_fisi => undef,
  			  _proxy_accounts => undef,
  			  _proxy_current => 0,
  			  _realtime_updates => 0};

  	my $class = shift;
  	bless $self, $class;
	$self->{_username} = shift;
	$self->{_db_checksum} = 'gd.'.$self->{_username} . '.md5.db';
	$self->{_db_fisi} = 'gd.'.$self->{_username} . '.fisi.db';
	$self->{_dbm} = pDrive::DBM->new();
	$self->{_paths} = {};
	$self->{_proxy_accounts} = [];

  	# initialize web connections
  	$self->{_serviceapi} = pDrive::GoogleDriveAPI2->new(pDrive::Config->CLIENT_ID,pDrive::Config->CLIENT_SECRET);
  	#my $my = pDrive::GoogleDriveAPI2->new(pDrive::Config->CLIENT_ID,pDrive::Config->CLIENT_SECRET);
  	#$my->test();

  	my $loginsDBM = pDrive::DBM->new('./gd.'.$self->{_username}.'.db');
#  	my $loginsDBM = pDrive::DBM->new(pDrive::Config->DBM_LOGIN_FILE);
  	$self->{_login_dbm} = $loginsDBM;
  	my ($token,$refreshToken) = $loginsDBM->readLogin($self->{_username});

	$self->{_folders_dbm} = $self->buildMemoryDBM();
	#$loginsDBM->openDBMForUpdating( 'gd.'.$self->{_username} . '.folders.db');


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
	  	$self->{_serviceapi}->testAccess();
	}
	return $self;

}

sub newService(*$) {

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
  	$self->{_serviceapi} = pDrive::GoogleDriveServiceAPI2->new(pDrive::Config->CLIENT_ID,pDrive::Config->CLIENT_SECRET);

  	my $loginsDBM = pDrive::DBM->new('./gd.'.$self->{_username}.'.db');
#  	my $loginsDBM = pDrive::DBM->new(pDrive::Config->DBM_LOGIN_FILE);
  	$self->{_login_dbm} = $loginsDBM;
  	my ($token,$refreshToken) = $loginsDBM->readLogin($self->{_username});

	$self->{_folders_dbm} = $self->buildMemoryDBM();#$loginsDBM->openDBMForUpdating( 'gd.'.$self->{_username} . '.folders.db');


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
	  	$self->{_serviceapi}->testAccess();
	}
	return $self;

}

sub setService(*$){
	my $self = shift;
	my $username = shift;
	$self->{_serviceapi}->setService(pDrive::Config->ISS, pDrive::Config->KEY, $username);


  	my ($token) = $self->{_login_dbm}->readServiceLogin($username);

	# no token defined
	if ($token eq ''){
 	  	$token = $self->{_serviceapi}->getServiceToken($username);
 	  	print STDERR "TOKEN = $token\n";
	  	$self->{_login_dbm}->writeServiceLogin($username,$token);
	}else{
		$self->{_serviceapi}->setServiceToken($token);
	}

	# token expired?
	if (!($self->{_serviceapi}->testServiceAccess())){
		# refresh token
 	 	($token) = $self->{_serviceapi}->getServiceToken($username);
		$self->{_serviceapi}->setServiceToken($token);
	  	$self->{_login_dbm}->writeServiceLogin($username,$token);
	  	$self->{_serviceapi}->testServiceAccess();
	}
}




sub overrideChecksum(*$){

	my ($self,$dbname) = @_;
	$self->{_db_checksum} = 'gd.'.$dbname . '.md5.db';
	$self->{_db_fisi} = 'gd.'.$dbname . '.fisi.db';

}


sub setRealTimeUpdates(*){

	my ($self) = @_;
	$self->{_realtime_updates} = 1;

}

sub downloadFile(*$$$){

      my ($self,$path,$link,$updated) = @_;
      my $returnStatus;
      my $finalPath;
      if ($path > 0){
      	$finalPath = pDrive::Config->LOCAL_PATH."/$path";
      }else{
      	$finalPath = $path;
      }

      pDrive::FileIO::traverseMKDIR($finalPath);
      print STDOUT "downloading $finalPath...";

      # a simple non-google-doc file
      if ($self->{_serviceapi}->downloadFile($finalPath,$link,$updated)){
      	return $finalPath;
      }else{
      	return 0;
      }

}



sub createFolder(*$$){

	my $self = shift;
	my $folder = shift;
	my $parentFolder = shift;

	return $self->{_serviceapi}->createFolder('https://www.googleapis.com/drive/v2/files?includeTeamDriveItems=true&supportsTeamDrives=true&fields=id',$folder, $parentFolder);

}

sub moveFile(*$$){

	my $self = shift;
	my $file = shift;
	my $toFolder = shift;
	my $fromFolder = shift;

	return $self->{_serviceapi}->moveFile($file, $toFolder, $fromFolder);

}

sub getSubFolderID(*$$){

	my $self = shift;
	my $folderName = shift;
	my $parentID = shift;

	my $URL = 'https://www.googleapis.com/drive/v2/files?includeTeamDriveItems=true&supportsTeamDrives=true&q=\''. $parentID.'\'+in+parents+and+trashed%3Dfalse&fields=nextLink%2Citems(kind%2Cid%2CmimeType%2Ctitle%2CfileSize%2CmodifiedDate%2CcreatedDate%2CdownloadUrl%2Cparents/parentLink%2Cmd5Checksum)';

	while ($URL ne ''){

	my $driveListings = $self->{_serviceapi}->getList($URL);
	$self->{_nextURL} =  $self->{_serviceapi}->getNextURL($driveListings);
  	my $newDocuments = $self->{_serviceapi}->readDriveListings($driveListings);

  	foreach my $resourceID (keys %{$newDocuments}){
    	if ($$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}] eq $folderName){
    		print STDERR "returning $resourceID\n " if (pDrive::Config->DEBUG);
    		return $resourceID;
    	}
	}
	last if $self->{_nextURL} eq '';
	$URL = $self->{_nextURL};
	}
	return '';

}

sub getSubFolderIDList(*$$){

	my $self = shift;
	my $folderName = shift;
	my $URL = shift;

	if ($URL eq ''){
		$URL = 'https://www.googleapis.com/drive/v2/files?includeTeamDriveItems=true&supportsTeamDrives=true&q=\''. $folderName.'\'+in+parents+and+trashed%3Dfalse&fields=nextLink%2Citems(kind%2Cid%2CmimeType%2Ctitle%2CfileSize%2CmodifiedDate%2CcreatedDate%2CdownloadUrl%2Cmd5Checksum%2Cparents/parentLink)';
	}


	my $driveListings = $self->{_serviceapi}->getList($URL);
	$self->{_nextURL} =  $self->{_serviceapi}->getNextURL($driveListings);

  	my $newDocuments = $self->{_serviceapi}->readDriveListings($driveListings);

	return $newDocuments;

}


sub getSubFolderIDListWithMedia(*$$){

	my $self = shift;
	my $folderName = shift;
	my $URL = shift;

	if ($URL eq ''){
		$URL = 'https://www.googleapis.com/drive/v2/files?includeTeamDriveItems=true&supportsTeamDrives=true&q=\''. $folderName.'\'+in+parents+and+trashed%3Dfalse&fields=nextLink%2Citems(videoMediaMetadata%2Ckind%2Cid%2CmimeType%2Ctitle%2CfileSize%2CmodifiedDate%2CcreatedDate%2CdownloadUrl%2Cmd5Checksum%2Cparents/parentLink)';
	}


	my $driveListings = $self->{_serviceapi}->getList($URL);
	my $nextURL =  $self->{_serviceapi}->getNextURL($driveListings);

  	my $newDocuments = $self->{_serviceapi}->readDriveListings($driveListings);

	return ($nextURL, $newDocuments);

}



sub uploadFolder(*$$){
	my $self = shift;
	my $localPath = shift;
	my $serverPath = shift;
	my $parentFolder = shift;
	my $uploaded = shift;


	#my %uploaded;
    my ($folder) = $localPath =~ m%\/([^\/]+)$%;

#	if ($serverPath ne ''){
		$serverPath .= '/'.$folder;
#	}
  	print STDOUT "path = $localPath\n";
   	my @fileList = pDrive::FileIO::getFilesDir($localPath);

	print STDOUT "folder = $folder\n";

	#check server-cache for folder
	my $folderID = '';#$self->{_login_dbm}->findFolder($self->{_folders_dbm}, $serverPath);
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
		#$self->{_login_dbm}->addFolder($self->{_folders_dbm}, $serverPath, $folderID) if ($folderID ne '');
	}



	print "resource ID = " . $folderID . "\n";

    for (my $i=0; $i <= $#fileList; $i++){

    	#empty file; skip
    	if (-z $fileList[$i]){
			next;
    	#folder
    	}elsif (-d $fileList[$i]){
	  		$self->uploadFolder($fileList[$i], $serverPath, $folderID,$uploaded);
	  		#%uploaded = (%uploaded,%uploaded2);
    	# file
    	}else{
    		my $process = 1;

    		#look for md5 file
    		for (my $j=0; $j <= $#fileList; $j++){
    			my $value = $fileList[$i];
    			my ($file,$md5) = $fileList[$j] =~ m%[^\/]+\/\.(.*?)\.([^\.]+)$%;
    			my ($currentFile) = $fileList[$i] =~ m%\/([^\/]+)$%;

    			if ($file eq $currentFile and $md5 ne ''){
    				tie(my %dbase, pDrive::Config->DBM_TYPE, $self->{_db_checksum} ,O_RDONLY|O_CREAT, 0666) or die "can't open md5: $!";
    				if (  (defined $dbase{$md5.'_'} and $dbase{$md5.'_'} ne '') or (defined $dbase{$md5.'_0'} and $dbase{$md5.'_0'} ne '')){
    					$process = 0;
    				my $resourceID;
    				if ($dbase{$md5.'_'} ne ''){
    					$resourceID =  $dbase{$md5.'_'};
    				}elsif($dbase{$md5.'_0'} ne ''){
    					$resourceID = $dbase{$md5.'_0'};
    				}
			  		 my $newDocuments = $self->getFileMeta($resourceID);
			  		   		foreach my $resourceID (keys %{$newDocuments}){
			  		   			my $filename = $$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}];
						  		@{$uploaded{$resourceID}} = ($$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}],$serverPath, $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}],$fileList[$i] );

			  		   		}

				    	#pDrive::masterLog("skipped file (checksum $md5 exists ".$dbase{$md5.'_0'}.") - $fileList[$i]\n");
    					#last;
	    			}
    				untie(%dbase);
    			}
    		}
    		#calculate the fisi
			my ($fileName) = $fileList[$i] =~ m%\/([^\/]+)$%;
			my $fileSize = -s $fileList[$i];
 			my $fisi = pDrive::FileIO::getMD5String($fileName .$fileSize);
    		tie(my %dbase, pDrive::Config->DBM_TYPE, $self->{_db_fisi} ,O_RDONLY|O_CREAT, 0666) or die "can't open fisi: $!";
    		if (  (defined $dbase{$fisi.'_'} and $dbase{$fisi.'_'} ne '') or (defined $dbase{$fisi.'_0'} and $dbase{$fisi.'_0'} ne '')){
    					$process = 0;
    				my $resourceID;
    				if ($dbase{$fisi.'_'} ne ''){
    					$resourceID =  $dbase{$fisi.'_'};
    				}elsif($dbase{$fisi.'_0'} ne ''){
    					$resourceID = $dbase{$fisi.'_0'};
    				}
			  		 my $newDocuments = $self->getFileMeta($resourceID);
			  		   		foreach my $resourceID (keys %{$newDocuments}){
			  		   			my $filename = $$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}];
						  		@{$uploaded{$resourceID}} = ($$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}],$serverPath, $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}],$fileList[$i] );

			  		   		}

				    	#pDrive::masterLog("skipped file (fisi $fisi exists ".$dbase{$fisi.'_0'}.") - $fileList[$i]\n");
	    	}
    		untie(%dbase);
			if ($process){
				print STDOUT "Upload $fileList[$i]\n";
		  		my $results = $self->uploadFile($fileList[$i], $folderID);
		  		 my $newDocuments = $self->getFileMeta($$results[0]);
		  		   		foreach my $resourceID (keys %{$newDocuments}){
		  		   			my $filename = $$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}];
					  		@{$uploaded{$resourceID}} = ($$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}],$serverPath, $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}],$fileList[$i] );

		  		   		}

    		}else{
				print STDOUT "SKIP $fileList[$i]\n";
				#return \%uploaded;
	    	}
    	}
	  	print STDOUT "\n";
	}
	return \%uploaded;
}


sub uploadFTPFolder(*$$){
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
	my $folderID = '';#$self->{_login_dbm}->findFolder($self->{_folders_dbm}, $serverPath);
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
		#$self->{_login_dbm}->addFolder($self->{_folders_dbm}, $serverPath, $folderID) if ($folderID ne '');
	}



	print "resource ID = " . $folderID . "\n";

    for (my $i=0; $i <= $#fileList; $i++){


    	#empty file; skip
    	if (-z $fileList[$i]){
			next;
    	#folder
    	}elsif (-d $fileList[$i]){
	  		my $fileID = $self->uploadFTPFolder($fileList[$i], $serverPath, $folderID);
    	# file
    	}else{

	    	#check if file is updating
	    	my $fileSize = -s $fileList[$i];
	    	sleep 5;
	    	if ($fileSize != -s $fileList[$i] or $fileSize == 0 ){
				print STDOUT "SKIP $fileList[$i], still increasing or 0 byte file\n";
				next;
	    	}
    		my $process = 1;
    		#look for md5 file
    		for (my $j=0; $j <= $#fileList; $j++){
    			my $value = $fileList[$i];
    			my ($file,$md5) = $fileList[$j] =~ m%[^\/]+\/\.(.*?)\.([^\.]+)$%;
    			my ($currentFile) = $fileList[$i] =~ m%\/([^\/]+)$%;

    			if ($file eq $currentFile and $md5 ne ''){
    				tie(my %dbase, pDrive::Config->DBM_TYPE, $self->{_db_checksum} ,O_RDONLY|O_CREAT, 0666) or die "can't open md5: $!";
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
    		tie(my %dbase, pDrive::Config->DBM_TYPE, $self->{_db_fisi} ,O_RDONLY|O_CREAT, 0666) or die "can't open fisi: $!";
    		if (  (defined $dbase{$fisi.'_'} and $dbase{$fisi.'_'} ne '') or (defined $dbase{$fisi.'_0'} and $dbase{$fisi.'_0'} ne '')){
    					$process = 0;
				    	#pDrive::masterLog("skipped file (fisi $fisi exists ".$dbase{$fisi.'_0'}.") - $fileList[$i]\n");
	    	}
    		untie(%dbase);
			if ($process){
				print STDOUT "Upload $fileList[$i]\n";
		  		my $fileID = $self->uploadFile($fileList[$i], $folderID);
    		}else{
				print STDOUT "SKIP $fileList[$i], DELETE local file\n";
				unlink $fileList[$i];
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
	my $folderID =  '';#$self->{_login_dbm}->findFolder($self->{_folders_dbm}, $serverPath);
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
		#$self->{_login_dbm}->addFolder($self->{_folders_dbm}, $serverPath, $folderID) if ($folderID ne '');
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
    				tie(my %dbase, pDrive::Config->DBM_TYPE, $self->{_db_checksum} ,O_RDONLY|O_CREAT, 0666) or die "can't open md5: $!";
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


  	my $fileSize =  -s $file;
  	return 0 if $fileSize == 0;
  	my $filetype = 'application/octet-stream';
  	print STDOUT "file size for $file ($fileName)  is $fileSize to folder $folder\n" if (pDrive::Config->DEBUG);

  	my $uploadURL = $self->{_serviceapi}->createFile('https://www.googleapis.com/upload/drive/v2/files?includeTeamDriveItems=true&supportsTeamDrives=true&fields=id&convert=false&uploadType=resumable',$fileSize,$fileName,$filetype, $folder);


  	my $chunkNumbers = int($fileSize/(pDrive::Config->CHUNKSIZE))+1;
	my $pointerInFile=0;
  	print STDOUT "file number is $chunkNumbers\n" if (pDrive::Config->DEBUG);
  	open(INPUT, "<".$file) or die ('cannot read file '.$file);

  	binmode(INPUT);

  	my $results;
  	my $retrycount=0;

  	for (my $i=0; $i < $chunkNumbers; $i++){
		my $chunkSize =pDrive::Config->CHUNKSIZE;
		my $chunk;
    	if ($i == $chunkNumbers-1){
	    	$chunkSize = $fileSize - $pointerInFile;
    	}

    	sysread INPUT, $chunk, pDrive::Config->CHUNKSIZE;
    	print STDERR "\r".$i . '/'.$chunkNumbers;
    	#smy $results;
    	$retrycount=0;
		my $resourceID = 0;

    	while ($resourceID eq '0' and $retrycount < RETRY_COUNT){

			$results = $self->{_serviceapi}->uploadFile($uploadURL,\$chunk,$chunkSize,'bytes '.$pointerInFile.'-'.($i == $chunkNumbers-1? $fileSize-1: ($pointerInFile+$chunkSize-1)).'/'.$fileSize,$filetype);
			$resourceID = $$results[0];
      		#print STDOUT "\r"  . $resourceID;
	      	if ($resourceID eq '0'){
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
		if ($retrycount >= RETRY_COUNT){
			print STDERR "\r" . $file . "'...retry failed - $file\n";

    		pDrive::masterLog("failed chunk $pointerInFile (all attempts failed) - $file\n");
    		last;
		}

		$pointerInFile += $chunkSize;
  	}
  	if ($retrycount < RETRY_COUNT){
		print STDOUT "\r" . $file . "'...success - $file\n";
  	}
  	close(INPUT);
  	return $results;
}



sub copyFile(*$$$$){

	my $self = shift;
	my $fileID = shift;
	my $folder = shift;
	my $fileName = shift;
	my $createDate = shift;

	$fileID =~ s%\s%%g; #remove spaces
  	my $retrycount=0;

  	my $status=0;
   	$retrycount=0;
   	while ($status eq '0' and $retrycount < RETRY_COUNT){
			$status =  $self->{_serviceapi}->copyFile($fileID,$fileName, $folder,$createDate);
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
        	#cannot copy, user limit exceeded
	      	}elsif ($status eq '-1'){
				return -1;
			#cannot copy, no access
	      	}elsif ($status eq '-2'){
				return -2;
	      	}
			if ($retrycount >= RETRY_COUNT){
				print STDERR "\r" . $fileID . "'...retry failed - $fileID\n";

    			pDrive::masterLog("failed copy (all attempts failed) - $fileID\n");
    			last;
			}
  	}
  	if ($retrycount < RETRY_COUNT){
		print STDOUT "\r" . $file . "'...success - $fileID\n";
  	}
}


sub getFileMeta(*$$$$){

	my $self = shift;
	my $fileID = shift;


#			$status =  $self->{_serviceapi}->getFileMeta($fileID);
			my $driveListings = $self->{_serviceapi}->getFileMeta($fileID);
			return if ($driveListings eq '-1');
  			my $newDocuments = $self->{_serviceapi}->readDriveListings($driveListings);
			return $newDocuments;

}



sub cleanNames(*$){
	my $self = shift;
	my $folderID = shift;

	my $nextURL='';

	#last run failed to finish, attempt to continue where left
	while (1){
  		my $newDocuments = $self->getSubFolderIDList($folderID, $nextURL);


  		foreach my $resourceID (keys %{$newDocuments}){

				my $filename = $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}];
				#fix season folders
				if ($filename =~ m%^\S+\_s\d?\d$%){
					$filename =~ s%^\S+\_s(\d?\d)$%Season $1%;
				#fix MixedCase names
				}else{
					$filename =~ s%(\S)([A-Z][a-z]+)%$1 $2%g;
					$filename =~ s%(\S)([A-Z][a-z]+)%$1 $2%g;

					$filename =~ s%(\S)([A-Z])\s%$1 $2 %g;
				}
				#something to rename?
				if ($filename ne $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}]){
					$self->renameFile($resourceID, $filename);
					print "rename " .  $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}] . ' to ' . $filename . "\n";
				}

	  			#	folder
  				 if  ($$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}] eq ''){
  				 	$self->cleanNames($resourceID);
  				}

  		}
			$nextURL = $self->{_nextURL};

			#print STDOUT "next url " . $nextURL. "\n";
  			last if  $nextURL eq '';
	}


}


sub renameFile(*$$){

	my $self = shift;
	my $fileID = shift;
	my $fileName = shift;

  	my $retrycount=0;

  	my $status=0;
   	$retrycount=0;
   	while ($status eq '0' and $retrycount < RETRY_COUNT){
			$status =  $self->{_serviceapi}->renameFile($fileID,$fileName);
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

			if ($retrycount >= RETRY_COUNT){
				print STDERR "\r" . $fileID . "'...retry failed - $fileID\n";

    			pDrive::masterLog("failed copy (all attempts failed) - $fileID\n");
    			last;
			}
  	}
  	if ($retrycount < RETRY_COUNT){
		print STDOUT "\r" . $file . "'...success - $fileID\n";
  	}
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

sub deleteFile(*$){

	my $self = shift;
	my $resourceID = shift;

	return $self->{_serviceapi}->deleteFile($resourceID);

}


sub trashFile(*$){

	my $self = shift;
	my $resourceID = shift;

	return $self->{_serviceapi}->trashFile($resourceID);

}
sub getListAllOLD(*){

	my $self = shift;

	my $nextURL = '';
	while (1){
		my $driveListings = $self->{_serviceapi}->getList($nextURL);
  		my $newDocuments = $self->{_serviceapi}->readDriveListings($driveListings);
  		$nextURL = $self->{_serviceapi}->getNextURL($driveListings);
		$self->updateMD5Hash($newDocuments);

		#print STDOUT "next url " . $nextURL . "\n";
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

	my $nextURL;
    tie(my %dbase, pDrive::Config->DBM_TYPE, $self->{_db_checksum} ,O_RDONLY|O_CREAT, 0666) or die "can't open md5: $!";
    my $changeID = $dbase{'LAST_CHANGE'};
    $nextURL = $dbase{'URL'} if $changeID eq '';

    print STDOUT "changeID = " . $changeID . "\n";
    print STDOUT "URL = " . $nextURL . "\n";
    untie(%dbase);

	#last run failed to finish, attempt to continue where left
	my $driveListings;
	my $lastURL;
	while (1){
		$driveListings = $self->{_serviceapi}->getChanges($nextURL, $changeID);
  		$nextURL = $self->{_serviceapi}->getNextURL($driveListings);
  		my $newDocuments = $self->{_serviceapi}->readChangeListings($driveListings);
		$self->updateMD5Hash($newDocuments);

		#$changeID = $self->{_serviceapi}->getChangeID($driveListings);
		#$self->updateChange($changeID);


		#print STDOUT "next url " . $nextURL . "\n";
  		last if $nextURL eq '';
  		$lastURL = $nextURL if $nextURL ne '';
	}
	#print STDOUT $$driveListings . "\n";
	$changeID = $self->{_serviceapi}->getChangeID($driveListings);
	$self->updateChange($changeID, $lastURL);

}

sub getChangesTeamDrive(*$){

	my $self = shift;
	my $teamdrive = shift;

	my $nextURL;
    tie(my %dbase, pDrive::Config->DBM_TYPE, $self->{_db_checksum} ,O_RDONLY|O_CREAT, 0666) or die "can't open md5: $!";
    my $changeID = $dbase{'LAST_CHANGE'};
    $nextURL = $dbase{'URL'} if $changeID eq '';

    print STDOUT "changeID = " . $changeID . "\n";
    print STDOUT "URL = " . $nextURL . "\n";
    untie(%dbase);

	#last run failed to finish, attempt to continue where left
	my $driveListings;
	my $lastURL;
	while (1){
		$driveListings = $self->{_serviceapi}->getChanges($nextURL, $changeID, $teamdrive);
  		$nextURL = $self->{_serviceapi}->getNextURL($driveListings);
  		my $newDocuments = $self->{_serviceapi}->readChangeListings($driveListings);
		$self->updateMD5Hash($newDocuments);

		#$changeID = $self->{_serviceapi}->getChangeID($driveListings);
		#$self->updateChange($changeID);

		#print STDOUT "next url " . $nextURL . "\n";
  		last if $nextURL eq '';
  		$lastURL = $nextURL if $nextURL ne '';
	}
	#print STDOUT $$driveListings . "\n";
	$changeID = $self->{_serviceapi}->getChangeID($driveListings);
	$self->updateChange($changeID, $lastURL);

}

sub getTrash(*){

	my $self = shift;

	my $nextURL='';

	#last run failed to finish, attempt to continue where left
	my $driveListings;
	while (1){
		$driveListings = $self->{_serviceapi}->getTrash($nextURL);
  		$nextURL = $self->{_serviceapi}->getNextURL($driveListings);
  		my $newDocuments = $self->{_serviceapi}->readDriveListings($driveListings);


  		foreach my $resourceID (keys %{$newDocuments}){
	  			#	folder
  				 if  ($$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}] eq ''){
					print STDOUT "folder $resourceID " . $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}].  "\n";
					$self->auditLog('folder,'. $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}]) if $self->{_audit};
  			 	}else{

					print STDOUT "file $resourceID " . $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}].  "\n";
					$self->auditLog('file,'. $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}]) if $self->{_audit};

  				}

  		}

		#print STDOUT "next url " . $nextURL . "\n";
  		last if $nextURL eq '';
	}

}


sub getFolderSize(*$$){

	my $self = shift;
	my $folderID = shift;
	my $tempDBM = shift;

	my $nextURL='';

	#last run failed to finish, attempt to continue where left
	my $driveListings;
	my $folderSize = 0;
	my $fileCount = 0;
	my $duplicateSize = 0;
	my $duplicateCount = 0;

	while (1){
		$driveListings = $self->{_serviceapi}->getFolderList($folderID, $nextURL);
  		$nextURL = $self->{_serviceapi}->getNextURL($driveListings);
  		my $newDocuments = $self->{_serviceapi}->readDriveListings($driveListings);


  		foreach my $resourceID (keys %{$newDocuments}){
	  			#	folder
  				 if  ($$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}] eq ''){
			    	print STDERR "." if $self->{_realtime_updates};
  				 	($size, $count, $dSize, $dCount) = $self->getFolderSize($resourceID, $tempDBM);
			    	print STDERR "\b \b" if $self->{_realtime_updates};
  				 	$folderSize += $size;
  				 	$fileCount += $count + 1;
  				 	$duplicateSize += $dSize;
  				 	$duplicateCount += $dCount;
  			 	}else{
  			 		if ($$tempDBM{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}]} >= 1){
	  				 	$duplicateSize +=  $$newDocuments{$resourceID}[pDrive::DBM->D->{'size'}];
	  				 	$duplicateCount++;
	  				 	$$tempDBM{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}]}++;
  			 		}else{
	  				 	$folderSize +=  $$newDocuments{$resourceID}[pDrive::DBM->D->{'size'}];
	  				 	$fileCount++;
	  				 	$$tempDBM{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}]}++;
  			 		}
  				}

  		}

		#print STDOUT "next url " . $nextURL . "\n";
  		last if $nextURL eq '';
	}
	return ($folderSize,$fileCount, $duplicateSize, $duplicateCount);
}


sub restoreTrash(*){

	my $self = shift;

	my $nextURL='';

	#last run failed to finish, attempt to continue where left
	my $driveListings;
	while (1){
		$driveListings = $self->{_serviceapi}->getTrash($nextURL);
  		$nextURL = $self->{_serviceapi}->getNextURL($driveListings);
  		my $newDocuments = $self->{_serviceapi}->readDriveListings($driveListings);

		my $folderID = '';
  		foreach my $resourceID (keys %{$newDocuments}){
	  			#	folder
  				 if  ($$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}] eq ''){
  			 	}else{
					#fetch recovery folder (or create)
  			 		if ($folderID eq ''){
  			 			$folderID = $self->getFolderIDByPath('recovery', 1);
  			 		}
  			 		# untrash and move to recovery folder
  			 		$self->{_serviceapi}->untrashFile($resourceID);
					$self->{_serviceapi}->moveFile($resourceID,$folderID);
					print STDOUT "recovered file $resourceID " . $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}].  "\n";

  				}

  		}

		#print STDOUT "next url " . $nextURL . "\n";
  		last if $nextURL eq '';
	}

}


sub getListAll(*){

	my $self = shift;

	my $nextURL='';

	#last run failed to finish, attempt to continue where left
	my $driveListings;
	my $lastURL;
	while (1){
		$driveListings = $self->{_serviceapi}->getList($nextURL);
  		$nextURL = $self->{_serviceapi}->getNextURL($driveListings);
  		my $newDocuments = $self->{_serviceapi}->readDriveListings($driveListings);

		#print STDOUT "next url " . $nextURL . "\n";
  		last if $nextURL eq '';
  		$lastURL = $nextURL if $nextURL ne '';
	}
	print STDOUT "last url " . $lastURL . "\n";

}

sub updateMD5Hash(**){

	my $self = shift;
	my $newDocuments = shift;

	my $createdCountMD5=0;
	my $skippedCountMD5=0;
	my $createdCountFISI=0;
	my $skippedCountFISI=0;
	my $db = tie(my %dbase, pDrive::Config->DBM_TYPE, $self->{_db_checksum} ,O_RDWR|O_CREAT, 0666) or die "can't open md5: $!";
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
	$db->sync();
	untie(%dbase);
	my $db = tie( %dbase, pDrive::Config->DBM_TYPE, $self->{_db_fisi} ,O_RDWR|O_CREAT, 0666) or die "can't open fisi: $!";
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
	$db->sync();
	untie(%dbase);
	print STDOUT "MD5: created = $createdCountMD5, skipped = $skippedCountMD5\n";
	print STDOUT "FISI: created = $createdCountFISI, skipped = $skippedCountFISI\n";


}


sub getFolderIDByPath(*$$){

	my $self = shift;
	my $path = shift;
	my $doCreate = shift;
	my $rootID = shift;

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
		$folderID = '';# $self->{_login_dbm}->findFolder($self->{_folders_dbm}, $serverPath);
		#	folder doesn't exist, create it
		if ($folderID eq ''){
			#*** validate it truly doesn't exist on the server before creating
			#this is the parent?
			if ($parentFolder eq ''){
				#look at the root
				#	get root's children, look for folder as child
				if ($rootID ne ''){
					$folderID = $self->getSubFolderID($folder,$rootID);
				}else{
					$folderID = $self->getSubFolderID($folder,'root');
				}
				$parentFolder =$folderID if ($folderID ne '');
			}else{
				#look at the parent
				#get parent's children, look for folder as child
				$folderID = $self->getSubFolderID($folder,$parentFolder);
				$parentFolder =$folderID if ($folderID ne '');
			}

			if ($folderID eq '' and $parentFolder ne ''){
				$folderID = $self->createFolder($folder, $parentFolder)  if $doCreate;
				$parentFolder =$folderID if ($folderID ne '');
			}elsif ($folderID eq '' and  $parentFolder eq ''){
				if ($rootID ne ''){
					$folderID = $self->createFolder($folder,$rootID)  if $doCreate;
				}else{
					$folderID = $self->createFolder($folder, 'root')  if $doCreate;

				}
				$parentFolder =$folderID if ($folderID ne '');
			}
#			$self->{_login_dbm}->addFolder($self->{_folders_dbm}, $serverPath, $folderID) if ($folderID ne '');
		}

	}
	return $folderID;

}



sub getFolderIDByParentID(*$$$){

	my $self = shift;
	my $folderName = shift;
	my $parentID = shift;
	my $doCreate = shift;

	my $folderID;

	#look at the parent
	#get parent's children, look for folder as child
	$folderID = $self->getSubFolderID($folderName,$parentID);

	if ($folderID eq ''){
		$folderID = $self->createFolder($folderName, $parentID)  if $doCreate;
	}
	return $folderID;

}


sub renameFileList(*$){
	my $self = shift;
	my $fileList = shift;

	my @dbase;
	$dbase[0] = $self->{_dbm}->openDBM($service->{_db_checksum});
	$dbase[1] = $self->{_dbm}->openDBM($service->{_db_fisi});
	$dbase[2] = my %md5tmp;

	open (LIST, '<'.$fileList) or  die ('cannot read file '.$fileList);
    while (my $line = <LIST>){
			my ($fileID, $checksum, $fisi, $title, $rename_title) = $line =~ m%\"?(.*?)\"?\t\"?(.*?)\"?\t\"?(.*?)\"?\t\"?(.*?)\"?\t\"?(.*?)\"?\n%;
			$fileID =~ s%\s%%g;
			next if $fileID eq '';
			next if $title eq $rename_title;
      		print STDOUT "renaming = $fileID $title to $rename_title\n";
      		$self->{_serviceapi}->renameFile($fileID,$rename_title);

    }
    close(LIST);
	$self->{_dbm}->closeDBM($dbase[0]);
	$self->{_dbm}->closeDBM($dbase[1]);

}





sub generateSTRM(*$){
	my $self = shift;
	my $path = shift;

	my %db;
	open(MOVIES, './movies.tab');

	while(my $line = <MOVIES>){
		my ($title, $year,$fileID) = $line =~ m%^([^\t]+)\t([^\t]+)\t.*?\t([^\t]+)\n$%;
		$title = lc $title;
		my $filename =  "$path/$title ($year).strm";
		if (! (-e $filename)){
			open(STRM, '>'.$filename);
			print STRM 	'plugin://plugin.video.gdrive-testing/?mode=video&strm=true&title='.$title.'&year='.$year.'&spreadsheet=10t5UULE8H4Xu_B0i3o0EWxsn_WAfyoF_pjPiE-MdCCI&sheet=ofx5r0l' . "\n";
			close(STRM);
		}

		print "$title, $year, $fileID\n";

	}
	close(MOVIES);

}



sub catalogMedia(*$$){
	my $self = shift;
	my $folderID = shift;

	my %db;
	open(MOVIES, './movies.tab');
	open(TV, './tv.tab');

	while(my $line = <MOVIES>){
		my ($fileID) = $line =~ m%\t([^\t]+)\n$%;
		$db{$fileID} = 1;
		print '"'.$fileID.'"' . $db{$fileID} . "\n";

	}
	while(my $line = <TV>){
		my ($fileID) = $line =~ m%\t([^\t]+)\n$%;
		$db{$fileID} = 1;
	}
	close(MOVIES);
	close(TV);

	$self->_catalogMedia($folderID, '', '', \%db);

}



sub _catalogMedia(*$$%){
	my $self = shift;
	my $folderID = shift;
	my $_title = shift;
	my $_season = shift;
	my $db= shift;

	my $nextURL='';

	while (1){
		my $newDocuments;
		 ($nextURL, $newDocuments) = $self->getSubFolderIDListWithMedia($folderID, $nextURL);


  		foreach my $resourceID (keys %{$newDocuments}){
  				my $output;
	  			#	folder
  				 if  ($$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}] eq ''){
  				 	# is a season folder, therefore the parent is a show folder
  				 	if ($$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}] =~ m%^season \d+%i){
  				 		my ($season) = $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}] =~ m%^season (\d+)%i;
						$self->_catalogMedia($resourceID, $_title, $season, $db);
  				 	}else{
						$self->_catalogMedia($resourceID, lc $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}], $_season, $db);
  				 	}

  				}

  		}

		open(MOVIES, '>>./movies.tab') or die ('Cannot save to ' . pDrive::Config->LOCAL_PATH . '/movies.tab');
		open(TV, '>>./tv.tab') or die ('Cannot save to ' . pDrive::Config->LOCAL_PATH . '/tv.tab');
		open(OTHER, '>>./other.tab') or die ('Cannot save to ' . pDrive::Config->LOCAL_PATH . '/other.tab');

  		foreach my $resourceID (keys %{$newDocuments}){

			next if $$db{$resourceID} ==1 ;	#pre-existing, skip

			# is video
			if ($$newDocuments{$resourceID}[pDrive::DBM->D->{'duration'}]  > 0){
	  				my $output;
		  			#	folder
	  				 if  ($$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}] eq ''){
	  			 	}else{

						print STDOUT "file $resourceID " . $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}].  "\n";
						my $directory = '';
	  			 		#tv1
	  			 		if ($_season ne '' or $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}] =~ m%(.+?)[ .]?[ \-]?\s*S0?(\d\d?)E(\d\d?)(.*)(?:[ .](\d{3}\d?p)|\Z)?\..*%i
	#  			 		or $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}] =~ m%(.+?)[ .]?[ \-]?\s*[^\d]+(\d)(\d\d)[^\d]+(.*)(?:[ .](\d{3}\d?p)|\Z)?\..*%i
	  			 		or $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}] =~ m%(.+?)[ .]?[ \-]?\s*season\s?(\d\d?)\s?episode\s?(\d\d?)(.*)(?:[ .](\d{3}\d?p)|\Z)?\..*%i
	  			 		or $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}] =~ m%(.+?)[ .]?[ \-]?\s*0?(\d\d?)x(\d\d?)(.*)(?:[ .](\d{3}\d?p)|\Z)?\..*%i){
							my ($show, $season, $episode) = $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}]  =~ m%(.+?)[ .]?[ \-]?\s*S0?(\d\d?)E(\d\d?)(.*)(?:[ .](\d{3}\d?p)|\Z)?\..*%i;
							if ($show eq ''){
								($show, $season, $episode) = $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}]  =~  m%(.+?)[ .]?[ \-]?\s*season\s?(\d\d?)\s?episode\s?(\d\d?)(.*)(?:[ .](\d{3}\d?p)|\Z)?\..*%i;
								if ($show eq ''){
									($show, $season, $episode) = $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}]  =~ m%(.+?)[ .]?[ \-]?\s*0?(\d\d?)x(\d\d?)(.*)(?:[ .](\d{3}\d?p)|\Z)?\..*%i;
									if ($show eq ''){
										($show, $season, $episode) = $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}]  =~ m%(.+?)[ .]?[ \-]?\s*(\d)(\d\d)(.*)(?:[ .](\d{3}\d?p)|\Z)?\..*%i;
										#episode is not parseable
										if ($show eq ''){
											$show = $_title;
											$season = $_season;
										}
									}
								}
							}
							$show =~ s%\.% %g; #remove . from name
							$show =~ s%\_% %g; #remove _ from name

							$season =~ s%^(\d)$%0$1%; #pad season with leading 0

							$output = (lc $show ). "\t"  . $season . "\t" . $episode . "\t\t" . $$newDocuments{$resourceID}[pDrive::DBM->D->{'duration'}]  . "\t" . $$newDocuments{$resourceID}[pDrive::DBM->D->{'resolution'}]  . "\t" . $$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}] . "\t" .  $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}] . "\t" . $resourceID . "\n";
							print TV $output;

						#movie
	  			 		}elsif ($_title ne '' or $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}] =~ m%(.*?[ \(]?[ .]?[ \-]?\d{4}[ \)]?[ .]?[ \-]?).*?(?:(\d{3}\d?p)|\Z)?%i){
							my ($movie, $year) =  $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}]  =~ m%(.*?)[ \(]?[\[]?[\{]?[ .]?[ \-]?(\d{4})[ \)]?[\]]?[\}]?[ .]?[ \-]?.*?(?:(\d{3}\d?p)|\Z)?%i;
							if ($movie eq ''){
								($movie, $year)  = $_title =~   m%(.*?)[ \(]?[\[]?[\{]?[ .]?[ \-]?(\d{4})[ \)]?[\]]?[\}]?[ .]?[ \-]?.*?(?:(\d{3}\d?p)|\Z)?%i;
							}
							$movie =~ s%\.% %g; #remove . from name
							$movie =~ s%\_% %g; #remove _ from name

							$output = (lc $movie) . "\t"  . $year . "\t\t" . $$newDocuments{$resourceID}[pDrive::DBM->D->{'duration'}]  . "\t"  . $$newDocuments{$resourceID}[pDrive::DBM->D->{'resolution'}]  . "\t" . $$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}] . "\t" . $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}] . "\t". $resourceID . "\n";
							print MOVIES $output;

	  			 		}else{
							$output =   "\t\t\t" . $$newDocuments{$resourceID}[pDrive::DBM->D->{'duration'}]  . "\t"  . $$newDocuments{$resourceID}[pDrive::DBM->D->{'resolution'}]  . "\t" . $$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}] . "\t" . $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}] . "\t". $resourceID . "\n";
							print OTHER $output;

	  			 		}

						print STDOUT $output;

	  				}

	  		}

		}
		close(OTHER);
		close(TV);
		close(MOVIES);



		#$nextURL = $self->{_nextURL};
		#print STDOUT "next url " . $nextURL. "\n";
	  	last if  $nextURL eq '';

	}

}



sub findEmpyFolders(*$){

	my $self = shift;
	my $folderID = shift;

	my $nextURL = '';
	my @subfolders;

	push(@subfolders, $folderID);

	for (my $i=0; $i <= $#subfolders;$i++){
		$folderID = $subfolders[$i];
		my $fileFolderCount=0;
		while (1){

			my $newDocuments =  $self->getSubFolderIDList($folderID, $nextURL);

  			foreach my $resourceID (keys %{$newDocuments}){
	  			#	folder
  				 if  ($$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}] eq ''){
					push(@subfolders, $resourceID);
					$fileFolderCount++;

  			 	}else{
					$fileFolderCount++;
  				}

			}
			$nextURL = $self->{_nextURL};
			#print STDOUT "next url " . $nextURL. "\n";
  			last if  $nextURL eq '';

	  	}
	  	if ($fileFolderCount == 0){
	  		print STDOUT "empty folder - ". $folderID . "\n";
	  	}

	}


}

sub addProxyAccount(*$){

	my $self = shift;
	my $service = shift;
	push(@{$self->{_proxy_accounts}},\$service);
	print STDOUT "added proxy " . ${$self->{_proxy_accounts}[$#{$self->{_proxy_accounts}}]}->{_username} . "\n";

}

sub pullProxyAccount(*){

	my $self = shift;

	#$self->{_proxy_current}++;
	return ${$self->{_proxy_accounts}[$self->{_proxy_current}++]};#pop(@{$self->{_proxy_accounts}});

}

sub hasProxyAccount(*){

	my $self = shift;
	if ($self->{_proxy_current} < $#{$self->{_proxy_accounts}}){
		return 1;
	}else{
		return 0;
	}

}

sub trashEmptyFolders(*$$){

	my $self = shift;
	my $folderID = shift;

	my $recusiveLevel = shift;

	if ($recusiveLevel eq ''){
		$recusiveLevel = 999;
	}

	#for (my $count=0; $count < 2; $count++){
		my $nextURL = '';

		my $fileFolderCount=0;
		while (1){

				my $newDocuments =  $self->getSubFolderIDList($folderID, $nextURL);
				$nextURL = $self->{_nextURL};

	  			foreach my $resourceID (keys %{$newDocuments}){
		  			# a folder is found, recurse into it
	  				 if  ($$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}] eq ''){
	  				 	my $count = 1;
	  				 	# if the subfolder is empty, or becomes empty, we don't want to count this folder against our fileFolderCount
						$count = $self->trashEmptyFolders($resourceID, $recusiveLevel-1) if $recusiveLevel > 0;
						$fileFolderCount += $count;

	  			 	}else{
						$fileFolderCount++;
	  				}

				}



				#print STDOUT "next url " . $nextURL. "\n";
	  			last if  $nextURL eq '';

	  	}
	  	#if there is nothing in the folder, trash it.
	  	if ($fileFolderCount == 0){
	  		print STDOUT "trashing empty folder - ". $folderID . "\n";
	  		$self->trashFile($folderID);
			#last;
	  	}

	#}
	# return the number of items in the folder
	return $fileFolderCount;



}

1;


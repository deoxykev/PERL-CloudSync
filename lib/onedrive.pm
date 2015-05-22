package pDrive::oneDrive;
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

sub new(*) {

	my $self = {_oneDrive => undef,
               _login_dbm => undef,
              _dbm => undef,
  			  _username => undef,
  			  _db_checksum => undef,
  			  _db_fisi => undef};

  	my $class = shift;
  	bless $self, $class;
	$self->{_username} = shift;
	$self->{_db_checksum} = 'od.'.$self->{_username} . '.sha1.db';
	$self->{_db_fisi} = 'od.'.$self->{_username} . '.fisi.db';

  	# initialize web connections
  	$self->{_oneDrive} = pDrive::OneDriveAPI1->new(pDrive::Config->ODCLIENT_ID,pDrive::Config->ODCLIENT_SECRET);

  	my $loginsDBM = pDrive::DBM->new('./od.'.$self->{_username}.'.db');
  	$self->{_login_dbm} = $loginsDBM;
  	my ($token,$refreshToken) = $loginsDBM->readLogin($self->{_username});

	# no token defined
	if ($token eq '' or  $refreshToken  eq ''){
		my $code;
		my  $URL = 'https://login.live.com/oauth20_authorize.srf?client_id='.pDrive::Config->ODCLIENT_ID . '&scope=onedrive.readwrite+wl.offline_access&response_type=code&redirect_uri=https://login.live.com/oauth20_desktop.srf';
		print STDOUT "visit $URL\n";
		print STDOUT 'Input Code:';
		$code = <>;
		print STDOUT "code = $code\n";
 	  	($token,$refreshToken) = $self->{_oneDrive}->getToken($code);
	  	$self->{_login_dbm}->writeLogin($username,$token,$refreshToken);
	}else{
		$self->{_oneDrive}->setToken($token,$refreshToken);
	}

	# token expired?
	if (!($self->{_oneDrive}->testAccess())){
		# refresh token
 	 	($token,$refreshToken) = $self->{_oneDrive}->refreshToken();
		$self->{_oneDrive}->setToken($token,$refreshToken);
	  	$self->{_login_dbm}->writeLogin($username,$token,$refreshToken);
	}


	return $self;



  	my $dbm = pDrive::DBM->new(pDrive::Config->DBM_CONTAINER_FILE);
  	$self->{_dbm} = $dbm;
  	my ($dbase,$folders) = $dbm->readHash();

	my $resourceIDHash = $dbm->constructResourceIDHash($dbase);

  return $self;

}

sub getListAll(*){

	my $self = shift;

	my $nextURL = '';
	while (1){
		my $driveListings = $self->{_oneDrive}->getList($nextURL);
  		my $newDocuments = $self->{_oneDrive}->readDriveListings($driveListings);
  		$nextURL = $self->{_oneDrive}->getNextURL($driveListings);
#		$self->updateMD5Hash($newDocuments);
		print STDOUT "next url " . $nextURL . "\n";
  		last if $nextURL eq '';
	}

}

sub getChangesAll(*){

	my $self = shift;

	my $nextURL = '';

	my $changeID = '';
    if (tie(my %dbase, pDrive::Config->DBM_TYPE, $self->{_db_checksum} ,O_RDONLY, 0666)){
    	$changeID = $dbase{'LAST_CHANGE'};
    	print STDOUT "changeID = " . $changeID . "\n";
    	untie(%dbase);
    }

	while (1){
		my $driveListings = $self->{_oneDrive}->getChanges($nextURL, $changeID);
  		$nextURL = $self->{_oneDrive}->getNextURL($driveListings);
  		my $newDocuments = $self->{_oneDrive}->readChangeListings($driveListings);
		$self->updateSHA1Hash($newDocuments);
		$changeID = $self->{_oneDrive}->getChangeID($driveListings);
		print STDOUT "next url " . $nextURL . "\n";
  		last if $nextURL eq '';
	}
	#print STDOUT $$driveListings . "\n";
	$self->updateChange($changeID);

}




sub createFolder(*$$){

	my $self = shift;
	my $folder = shift;
	my $parentFolder = shift;

	return $self->{_oneDrive}->createFolder('https://api.onedrive.com/v1.0/drive/root:/'.$parentFolder.':/children?nameConflict=fail', $folder);

}

sub uploadFolder(*$$){
	my $self = shift;
	my $path = shift;
	my $parentFolder = shift;

    my ($folder) = $path =~ m%\/([^\/]+)$%;

  	print STDOUT "path = $path\n";
   	my @fileList = pDrive::FileIO::getFilesDir($path);

	print STDOUT "folder = $folder\n";
	my $folderID = $self->createFolder($folder, $parentFolder);
	#print "resource ID = " . $folderID . "\n";
	if ($parentFolder ne ''){
		$folderID = $parentFolder . '/' . $folder;
	}else{
		$folderID = $folder;
	}

    for (my $i=0; $i <= $#fileList; $i++){

    	#empty file; skip
    	if (-z $fileList[$i]){
			next;
    	#folder
    	}elsif (-d $fileList[$i]){
	  		my $fileID = $self->uploadFolder($fileList[$i], $folderID);
    	# file
    	}else{
    		my $process = 1;
    		#look for sha1 file
    		for (my $j=0; $j <= $#fileList; $j++){
    			my $value = $fileList[$i];
    			my ($file,$sha1) = $fileList[$j] =~ m%[^\/]+\/\.(.*?)\.([^\.]+)$%;
    			my ($currentFile) = $fileList[$i] =~ m%\/([^\/]+)$%;

    			if ($file eq $currentFile and $sha1 ne ''){
    				tie(my %dbase, pDrive::Config->DBM_TYPE, $self->{_db_checksum} ,O_RDONLY, 0666) or die "can't open sha1: $!";
    				if (  (defined $dbase{$sha1.'_'} and $dbase{$sha1.'_'} ne '') or (defined $dbase{$sha1.'_0'} and $dbase{$sha1.'_0'} ne '')){
    					$process = 0;
				    	pDrive::masterLog("skipped file (sha1 $sha1 exists ".$dbase{$sha1.'_0'}.") - $fileList[$i]\n");
    					last;
	    			}
    				untie(%dbase);
    			}
    		}
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

sub uploadFile(*$$){
	my $self = shift;
	my $file = shift;
	my $folderID = shift;

    my ($filename) = $file =~ m%\/([^\/]+)$%;

	# get filesize
	my $fileSize = -s $file;

#	if ($fileSize < 100000000){
	if ($fileSize < 1000){
		$self->uploadSimpleFile($file, $folderID, $filename);
	}else{
		$self->uploadLargeFile($file, $folderID, $filename);
	}

}


sub uploadRemoteFile(*$$$){

	my $self = shift;
	my $URL = shift;
	my $path = shift;
	my $filename = shift;

	return $self->{_oneDrive}->uploadRemoteFile($URL, $path, $filename);

}


sub uploadLargeFile(*$$$){

	my $self = shift;
	my $file = shift;
	my $path = shift;
	my $filename = shift;

	# get filesize
	my $fileSize = -s $file;

	open(INPUT, "<".$file) or die ('cannot read file '.$file);
	binmode(INPUT);
	my $fileContents;

  	# - don't slurp the entire file
	#my $fileContents = do { local $/; <INPUT> };
	#my $fileSize = length $fileContents;
	print STDOUT "file size for $file is $fileSize\n" if (pDrive::Config->DEBUG);


    my $URL = $self->{_oneDrive}->createFile($path, $filename);

	# calculate the number of chunks
	my $chunkNumbers = int($fileSize/(pDrive::Config->CHUNKSIZE))+1;
	my $pointerInFile=0;
	#print STDOUT "file number is $chunkNumbers\n" if (pDrive::Config->DEBUG);
  	my $fileID=0;
  	my $retrycount=0;

	for (my $i=0; $i < $chunkNumbers; $i++){
		my $chunkSize = pDrive::Config->CHUNKSIZE;
    	my $chunk;
    	if ($i == $chunkNumbers-1){
      		$chunkSize = $fileSize - $pointerInFile;
    	}
	# read chunk from file
    #read INPUT, $chunk, $chunkSize;
    sysread INPUT, $chunk, $chunkSize;

   	# - don't slurp the entire file
	#$chunk = substr($fileContents, $pointerInFile, $chunkSize);

    print STDERR "\r".$i . '/'.$chunkNumbers;
    my $status=0;
	$retrycount=0;
	while ($status eq '0' and $retrycount < 5){
		$status = $self->{_oneDrive}->uploadFile($URL, \$chunk, $chunkSize, 'bytes '.$pointerInFile.'-'.($i == $chunkNumbers-1? $fileSize-1: ($pointerInFile+$chunkSize-1)).'/'.$fileSize);
      	print STDOUT "\r"  . $status;
	    if ($status eq '0'){
	    	print STDERR "...retry\n";
 	 		my ($token,$refreshToken) = $self->{_oneDrive}->refreshToken();
			$self->{_oneDrive}->setToken($token,$refreshToken);
	  		$self->{_login_dbm}->writeLogin( pDrive::Config->USERNAME,$token,$refreshToken);

        	sleep (5);
        	$retrycount++;
	    }

	}
	if ($retrycount >= 5){
		print STDERR "\r" . $file . "'...retry\n";

    	pDrive::masterLog("failed chunk $pointerInFile (all attempts failed) - $file\n");
    	last;
	}

  	$fileID=$status;
    $pointerInFile += $chunkSize;

  }
  if ($retrycount < 5){
		print STDOUT "\r" . $file . "'...success\n";
  }
  close(INPUT);

}


sub uploadSimpleFile(*$$$){

	my $self = shift;
	my $file = shift;
	my $path = shift;
	my $filename = shift;

	# get filesize
	my $fileSize = -s $file;

	open(INPUT, "<".$file) or die ('cannot read file '.$file);
	binmode(INPUT);
	my $fileContents = do { local $/; <INPUT> };
  	close(INPUT);

    print STDOUT 'uploading entire file '. "\n";
    my $URL = $self->{_oneDrive}->API_URL .'/drive/root:/'.$path.'/'.$filename.':/content';
    $self->{_oneDrive}->uploadEntireFile($URL, \$fileContents,$fileSize);



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


sub getPath($$$){

  my ($folders,$resourceID,@parentArray) = @_;

  if (containsFolder($resourceID,@parentArray)){

    print STDOUT "cyclical error $$folders{$resourceID}[FOLDER_TITLE]\n";
    return '';

  }
  # end of recurrsion -- root
  if (defined $resourceID and defined $$folders{$resourceID}[FOLDER_ROOT] and $$folders{$resourceID}[FOLDER_ROOT] == IS_ROOT){

    $parentArray[$#parentArray+1] = $resourceID;
    return '/'.$$folders{$resourceID}[FOLDER_TITLE].'/';

  }elsif (defined $resourceID and defined $$folders{$resourceID}[FOLDER_PARENT] and $$folders{$resourceID}[FOLDER_PARENT] eq ''){
    return '/';

  } else{

    $parentArray[$#parentArray+1] = $resourceID;
    if (defined $resourceID and defined $$folders{$resourceID}[FOLDER_TITLE]){
      return &getPath($folders,$$folders{$resourceID}[FOLDER_PARENT],@parentArray) . $$folders{$resourceID}[FOLDER_TITLE].'/';
    }else{
      return '/';
    }

  }

}


sub containsFolder($$){
  my ($resourceID,@parentArray) = @_;

  for (my $i=0; $i <= $#parentArray; $i++){
    return 1 if $resourceID eq $parentArray[$i];
  }

  return 0;

}





sub downloadFile(*$$$$$$*){

      my ($self,$path,$link,$updated,$resourceType,$resourceID,$dbase,$updatedList) = @_;
      print STDOUT "downloading $path...\n";
      my $returnStatus;
      my $finalPath = $path;

      pDrive::FileIO::traverseMKDIR(pDrive::Config->LOCAL_PATH."/$path");

      # a simple non-google-doc file
      if ($types->{$resourceType} eq ''){
        my $appendex='';
        print STDOUT 'download using writely - '. $resourceType . $types->{$resourceType} if (pDrive::Config->DEBUG);
        if (scalar (keys %{${$dbase}{$path}}) > 1){
          $appendex .= '.'.$resourceID;
          $finalPath .= '.'.$resourceID;
        }
        if (pDrive::Config->REVISIONS and defined $$dbase{$path}{$resourceID}[pDrive::DBM->D->{'local_revision'}] and $$dbase{$path}{$resourceID}[pDrive::DBM->D->{'local_revision'}] ne ''){
          $appendex .= '.(local_revision_'.$$dbase{$path}{$resourceID}[pDrive::DBM->D->{'local_revision'}].')';
          $finalPath .= '.(local_revision_'.$$dbase{$path}{$resourceID}[pDrive::DBM->D->{'local_revision'}].')';
        }

        $returnStatus = $self->{_oneDrive}->downloadFile($link,$path,'',$appendex,$updated);
      # a google-doc file
      }else{
        print STDOUT 'download using '.$types->{$resourceType}.' wise - '. $resourceType  if (pDrive::Config->DEBUG);


        # are there multiple filetypes noted for the export?
        if (ref($types->{$resourceType}) eq 'ARRAY'){
          for (my $i=0; $i <= $#{$types->{$resourceType}}; $i++){
            my $appendex='';
            if (scalar (keys %{${$dbase}{$path}}) > 1){
              $appendex .= '.'.$resourceID;
              $finalPath .= '.'.$resourceID;
            }
            if (pDrive::Config->REVISIONS and $$dbase{$path}{$resourceID}[pDrive::DBM->D->{'local_revision'}] ne ''){
              $appendex .= '.local_revision_'.$$dbase{$path}{$resourceID}[pDrive::DBM->D->{'local_revision'}];
              $finalPath .= '.local_revision_'.$$dbase{$path}{$resourceID}[pDrive::DBM->D->{'local_revision'}];
            }
#wise
            $returnStatus = $self->{_oneDrive}->downloadFile($link.'&exportFormat='.$types->{$resourceType}[$i],$path,$types->{$resourceType}[$i],$appendex,$updated);
          }
        }else{
          my $appendex='';
          if (scalar (keys %{${$dbase}{$path}}) > 1){
            $appendex .= '.'.$resourceID;
            $finalPath .= '.'.$resourceID;
          }
          if (pDrive::Config->REVISIONS and $$dbase{$path}{$resourceID}[pDrive::DBM->D->{'local_revision'}] ne ''){
            $appendex .= '.(local_revision_'.$$dbase{$path}{$resourceID}[pDrive::DBM->D->{'local_revision'}].')';
            $finalPath .= '.(local_revision_'.$$dbase{$path}{$resourceID}[pDrive::DBM->D->{'local_revision'}].')';
          }
#wise
          $returnStatus = $self->{_oneDrive}->downloadFile($link.'&exportFormat='.$types->{$resourceType},$path,$types->{$resourceType},$appendex,$updated);
        }

        #ignore export if fails; just try to download
        # noticed some spreadsheets in XLSX will fail with exportFormat, but download fine (and in XSLX otherwise)
        if ($returnStatus == 0){
          my $appendex='';
          if (scalar (keys %{${$dbase}{$path}}) > 1){
            $appendex .= '.'.$resourceID;
            $finalPath .= '.'.$resourceID;
          }
          if (pDrive::Config->REVISIONS and $$dbase{$path}{$resourceID}[pDrive::DBM->D->{'local_revision'}] ne ''){
            $appendex .= '.(local_revision_'.$$dbase{$path}{$resourceID}[pDrive::DBM->D->{'local_revision'}].')';
            $finalPath .= '.(local_revision_'.$$dbase{$path}{$resourceID}[pDrive::DBM->D->{'local_revision'}].')';
          }
#wise
          $returnStatus = $self->{_oneDrive}->downloadFile($link,$path,$types->{$resourceType},$appendex,$updated);
        }
      }

      # successful?  update the db
      if ($returnStatus == 1){

        $$dbase{$path}{$resourceID}[pDrive::DBM->D->{'local_updated'}] = $updated;
        $$dbase{$path}{$resourceID}[pDrive::DBM->D->{'server_updated'}] = $updated;
        $$dbase{$path}{$resourceID}[pDrive::DBM->D->{'local_sha1'}] = pDrive::FileIO::getsha1(pDrive::Config->LOCAL_PATH.'/'.$finalPath);

        if ($$dbase{$path}{$resourceID}[pDrive::DBM->D->{'local_sha1'}] ne $$dbase{$path}{$resourceID}[pDrive::DBM->D->{'server_sha1'}]){
          print STDOUT "sha1 check failed!!!\n";
          pDrive::masterLog("$finalPath $resourceID - sha1 check failed -- $$dbase{$path}{$resourceID}[pDrive::DBM->D->{'local_sha1'}] - $$dbase{$path}{$resourceID}[pDrive::DBM->D->{'server_sha1'}]");
        }

        if (pDrive::Config->REVISIONS){
          $$dbase{$path}{$resourceID}[pDrive::DBM->D->{'local_revision'}]++;
        }
#        $updatedList[$#updatedList++] = $path;
        if ($#{$updatedList} >= 0){
          $$updatedList[$#{$updatedList}++] = $path;
        }else{
          $$updatedList[0] = $path;
        }

        $self->{_dbm}->writeValueContainerHash($path,$resourceID,$dbase);
      }elsif($returnStatus == 0){
        #TBD
      }
}





sub updateSHA1Hash(**){

	my $self = shift;
	my $newDocuments = shift;

	my $count=0;
	tie(my %dbase, pDrive::Config->DBM_TYPE, $self->{_db_checksum} ,O_RDWR|O_CREAT, 0666) or die "can't open sha1: $!";
	foreach my $resourceID (keys $newDocuments){
		next if $$newDocuments{$resourceID}[pDrive::DBM->D->{'server_sha1'}] eq '';
		for (my $i=0; 1; $i++){
			# if MD5 exists,
			if (defined $dbase{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_sha1'}].'_'. $i}){
				# validate it is the same file, if so, skip, otherwise move onto another md5 slot
				if  ($dbase{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_sha1'}].'_'. $i}  eq $resourceID){
					print STDOUT "skipped sha1\n";
					last;
				}else{
					#move onto next slot
				}
			#	create
			}else{
				$dbase{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_sha1'}].'_'. $i} = $resourceID;
				print STDOUT "created sha1\n";
				last;
			}
		}
	}
	untie(%dbase);
	tie(%dbase, pDrive::Config->DBM_TYPE, $self->{_db_fisi} ,O_RDWR|O_CREAT, 0666) or die "can't open fisi: $!";
	foreach my $resourceID (keys $newDocuments){
		next if $$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}] eq '';
		for (my $i=0; 1; $i++){
			# if MD5 exists,
			if (defined $dbase{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}].'_'. $i}){
				# validate it is the same file, if so, skip, otherwise move onto another md5 slot
				if  ($dbase{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}].'_'. $i}  eq $resourceID){
					print STDOUT "skipped fisi\n";
					last;
				}else{
					#move onto next slot
				}
			#	create
			}else{
				$dbase{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}].'_'. $i} = $resourceID;
				print STDOUT "created fisi\n";
				last;
			}
		}
	}
	untie(%dbase);

}


1;


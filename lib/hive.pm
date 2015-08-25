package pDrive::hive;

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
  			  _username => undef,
  			  _db_checksum => undef,
  			  _db_fisi => undef};

  	my $class = shift;
  	bless $self, $class;
	$self->{_username} = shift;
	$self->{_db_fisi} = 'h.'.$self->{_username} . '.fisi.db';

  	# initialize web connections
  	$self->{_serviceapi} = pDrive::hiveAPI->new($self->{_username});

  	my $loginsDBM = pDrive::DBM->new('./h.'.$self->{_username}.'.db');
  	$self->{_login_dbm} = $loginsDBM;
  	my ($token,$refreshToken) = $loginsDBM->readLogin($self->{_username});

	# no token defined
	if ($token eq '' or  $refreshToken  eq ''){
		print STDOUT 'Input Password:';
		$password = <>;
		$password =~ s%\n%%;
		($token) = $self->{_serviceapi}->authenticate($password);
		$self->{_login_dbm}->writeLogin($self->{_username},$token,$password);
	}else{
		$self->{_serviceapi}->setToken($token,$refreshToken);
	}



	return $self;




}

sub getList(*$){

	my $self = shift;
	my $resourceID = shift;

	my $driveListings = $self->{_serviceapi}->getList($resourceID);
  	my $newDocuments = $self->{_serviceapi}->readDriveListings($driveListings);

#  	foreach my $resourceID (keys $newDocuments){
 #   	print STDOUT 'new document -> '.$$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}] . ', '. $$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}] . "\n";
#	}

	#print STDOUT $$driveListings . "\n";
	$self->{_nextURL} =  $self->{_serviceapi}->getNextURL($driveListings);
	#$self->updateMD5Hash($newDocuments);
	return $newDocuments;
}

sub getListAll(*){

	my $self = shift;

	my $nextURL = '';
	while (1){
		my $driveListings = $self->{_serviceapi}->getList($nextURL);
  		my $newDocuments = $self->{_serviceapi}->readDriveListings($driveListings);
  		$nextURL = $self->{_serviceapi}->getNextURL($driveListings);
		print STDOUT "next url " . $nextURL . "\n";
  		last if $nextURL eq '';
	}

}

sub getChangesAll(*){

	return;

}




sub createFolder(*$$){

	my $self = shift;
	my $folder = shift;
	my $parentFolder = shift;

	return $self->{_serviceapi}->createFolder('https://api.onedrive.com/v1.0/drive/root:/'.$parentFolder.':/children?nameConflict=fail', $folder);

}

sub createFolderByPath(*$){

	my $self = shift;
	my $path = shift;
	$path =~ s%^\/*%%; #remove leading /

	my $tmppath = $path;
	my $parentFolder= '';
	my $folderID;
	#$path =~ s%^\/%%;
	while(my ($folder) = $tmppath =~ m%^\/?([^\/]+)%){
		#print STDERR "in $folder";
    	$tmppath =~ s%^\/?[^\/]+%%;
		$folderID = $self->{_serviceapi}->createFolder('https://api.onedrive.com/v1.0/drive/root:/'.$parentFolder.':/children?nameConflict=fail', $folder);
		if ($parentFolder eq ''){
			$parentFolder .= $folder;
		}else{
			$parentFolder .= '/'.$folder;
		}

	}
	return $path;

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
    		#calculate the fisi
			my ($fileName) = $fileList[$i] =~ m%\/([^\/]+)$%;
			my $fileSize = -s $fileList[$i];
 			my $fisi = pDrive::FileIO::getMD5String($fileName .$fileSize);
    		tie(my %dbase, pDrive::Config->DBM_TYPE, $self->{_db_fisi} ,O_RDONLY, 0666) or die "can't open fisi: $!";
    		if (  (defined $dbase{$fisi.'_'} and $dbase{$fisi.'_'} ne '') or (defined $dbase{$fisi.'_0'} and $dbase{$fisi.'_0'} ne '')){
    					$process = 0;
				    	pDrive::masterLog("skipped file (fisi $fisi exists ".$dbase{$fisi.'_0'}.") - $fileList[$i]\n");
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

sub uploadFile(*$$$){
	my $self = shift;
	my $file = shift;
	my $folderID = shift;
	my $filename = shift;

	if ($filename eq ''){
		($filename) = $file =~ m%\/([^\/]+)$%;
	}

	# get filesize
	my $fileSize = -s $file;

	if ($fileSize < 100000000){
#	if ($fileSize < 100000){
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

	return $self->{_serviceapi}->uploadRemoteFile($URL, $path, $filename);

}


sub uploadLargeFile(*$$$){

	my $self = shift;
	my $file = shift;
	my $path = shift;
	my $filename = shift;

	$filename =~ s%^\s%%; #remove leading spaces
	$path =~ s%\/*$%%; #remove tailing /
	$path =~ s%^\/*%%; #remove leading /

	# get filesize
	my $fileSize = -s $file;

	open(INPUT, "<".$file) or die ('cannot read file '.$file);
	binmode(INPUT);
	my $fileContents;

  	# - don't slurp the entire file
	#my $fileContents = do { local $/; <INPUT> };
	#my $fileSize = length $fileContents;
	print STDOUT "file size for $file is $fileSize\n" if (pDrive::Config->DEBUG);


    my $URL = $self->{_serviceapi}->createFile($path, $filename);

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
	while (($status eq '0' or $status == -1) and $retrycount < 10){
		$status = $self->{_serviceapi}->uploadFile($URL, \$chunk, $chunkSize, 'bytes '.$pointerInFile.'-'.($i == $chunkNumbers-1? $fileSize-1: ($pointerInFile+$chunkSize-1)).'/'.$fileSize);
      	print STDOUT "\r"  . $status;
	    if ($status == -1){
	    	print STDERR "...retry\n";
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
        		sleep (2);

        	$retrycount++;
	    }elsif ($status == -2){
			$retrycount = 10;

	    }elsif ($status eq '0'){
	    	print STDERR "...retry\n";
      		sleep (10);

        	$retrycount++;
	    }

	}
	if ($retrycount >= 10){
		print STDERR "\r" . $file . "'...retry failed - $path - $file\n";

    	pDrive::masterLog("failed chunk $pointerInFile (all attempts failed) - $file\n");
    	last;
	}

  	$fileID=$status;
    $pointerInFile += $chunkSize;

  }
  if ($retrycount < 10){
		print STDOUT "\r" . $file . "'...success - $path - $file\n";
  }
  close(INPUT);

}


sub uploadSimpleFile(*$$$){

	my $self = shift;
	my $file = shift;
	my $path = shift;
	my $filename = shift;

	$filename =~ s/\+//g; #remove +s in title, will be interpret as space
	$filename =~ s%^\s%%; #remove leading spaces
	$path =~ s%\/*$%%; #remove tailing /
	$path =~ s%^\/*%%; #remove leading /

	# get filesize
	my $fileSize = -s $file;

	open(INPUT, "<".$file) or die ('cannot read file '.$file);
	binmode(INPUT);
	my $fileContents = do { local $/; <INPUT> };
  	close(INPUT);

    print STDOUT 'uploading entire file '.$file;

    my $URL = $self->{_serviceapi}->API_URL .'/drive/root:/'.$path.'/'.$filename.':/content';
    my $status = $self->{_serviceapi}->uploadEntireFile($URL, \$fileContents,$fileSize);
    if ($status == 1){
    	print "...success - $path - $filename\n";
    }else{
    	print "...failure - $path - $filename\n";
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

sub getFolderInfo(*$){

	my $self = shift;

	#not implemented

	return 'inbound';

}

sub getSubFolderIDList(*$$){

	my $self = shift;
	my $folderID= shift;
	my $URL = shift;

	my $driveListings = $self->{_serviceapi}->getList($folderID);
  	my $newDocuments = $self->{_serviceapi}->readDriveListings($driveListings, $folderID);

	$self->{_nextURL} =  $self->{_serviceapi}->getNextURL($driveListings);
	#$self->updateMD5Hash($newDocuments);
	return $newDocuments;

}



sub downloadFile(*$$$$$$*){

      my ($self,$path,$link,$updated,$resourceType,$resourceID,$dbase,$updatedList) = @_;
      print STDOUT "downloading $path...\n";
      my $returnStatus;
      my $finalPath = pDrive::Config->LOCAL_PATH."/$path";

      pDrive::FileIO::traverseMKDIR(pDrive::Config->LOCAL_PATH."/$path");
      print STDERR "URL = $link $path\n";
      `aria2c -x 4 -s 4 --user-agent="Mozilla/5.0 (Windows NT 5.2; rv:2.0.1) Gecko/20100101 Firefox/4.0.1" "$link" -o $finalPath`;
     return;
}





1;


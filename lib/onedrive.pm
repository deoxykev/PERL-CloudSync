package pDrive::oneDrive;


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
              _listURL => undef,
              _login_dbm => undef,
              _dbm => undef};

  	my $class = shift;
  	bless $self, $class;
	my $username = pDrive::Config->USERNAME;

  	# initialize web connections
  	$self->{_oneDrive} = pDrive::OneDriveAPI1->new(pDrive::Config->CLIENT_ID,pDrive::Config->CLIENT_SECRET);

  	my $loginsDBM = pDrive::DBM->new(pDrive::Config->DBM_LOGIN_FILE);
  	$self->{_login_dbm} = $loginsDBM;
  	my ($token,$refreshToken) = $loginsDBM->readLogin($username);

	# no token defined
	if ($token eq '' or  $refreshToken  eq ''){
		my $code;
		my  $URL = 'https://login.live.com/oauth20_authorize.srf?client_id='.pDrive::Config->CLIENT_ID . '&scope=onedrive.readwrite+wl.offline_access&response_type=code&redirect_uri=https://login.live.com/oauth20_desktop.srf';
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
 	 	($token,$refreshToken) = $self->{_oneDrive}->refreshToken($code);
	  	$self->{_login_dbm}->writeLogin($username,$token,$refreshToken);
	}


  	# get contents
  	#$self->{_oneDrive}->getList('https://api.onedrive.com/v1.0/drive/root/children');#?access_token='.$token);

	#simple file
  	#$self->uploadFile('/u01/pdrive/dtl_shattered_1_130705.flv', 'root','dtl_shattered_1_130705.flvi');
	#complex file
  	#$self->uploadFile('/tmp/TEST.txt');

	return $self;



  	my $dbm = pDrive::DBM->new(pDrive::Config->DBM_CONTAINER_FILE);
  	$self->{_dbm} = $dbm;
  	my ($dbase,$folders) = $dbm->readHash();

	my $resourceIDHash = $dbm->constructResourceIDHash($dbase);

  return $self;

}


sub uploadFile(*$$$){

	my $self = shift;
	my $file = shift;
	my $path = shift;
	my $filename = shift;

	# get filesize
	my $fileSize = -s $file;

#	if ($fileSize < 100000000){
	if ($fileSize < 1000){
		$self->uploadSimpleFile($file, $path, $filename);
	}else{
		$self->uploadLargeFile($file, $path, $filename);
	}

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
	print STDOUT "file number is $chunkNumbers\n" if (pDrive::Config->DEBUG);
  	my $fileID=0;
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
	my $retrycount=0;
	while ($status eq '0' and $retrycount < 5){
		$status = $self->{_oneDrive}->uploadFile($URL, \$chunk, $chunkSize, 'bytes '.$pointerInFile.'-'.($i == $chunkNumbers-1? $fileSize-1: ($pointerInFile+$chunkSize-1)).'/'.$fileSize,$path, $filename);
      	print STDOUT "\r"  . $status;
	    if ($status eq '0'){
	    	print STDERR "...retry\n";
 	 		my ($token,$refreshToken) = $self->{_oneDrive}->refreshToken($code);
	  		$self->{_login_dbm}->writeLogin( pDrive::Config->USERNAME,$token,$refreshToken);

        	sleep (5);
        	$retrycount++;
	    }

	}
    pDrive::masterLog("retry failed $file\n") if ($retrycount >= 5);

  	$fileID=$status;
    $pointerInFile += $chunkSize;

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
    $self->{_oneDrive}->uploadEntireFile(\$fileContents,$fileSize, $path, $filename);



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
        $$dbase{$path}{$resourceID}[pDrive::DBM->D->{'local_md5'}] = pDrive::FileIO::getMD5(pDrive::Config->LOCAL_PATH.'/'.$finalPath);

        if ($$dbase{$path}{$resourceID}[pDrive::DBM->D->{'local_md5'}] ne $$dbase{$path}{$resourceID}[pDrive::DBM->D->{'server_md5'}]){
          print STDOUT "MD5 check failed!!!\n";
          pDrive::masterLog("$finalPath $resourceID - MD5 check failed -- $$dbase{$path}{$resourceID}[pDrive::DBM->D->{'local_md5'}] - $$dbase{$path}{$resourceID}[pDrive::DBM->D->{'server_md5'}]");
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


sub isNewResourceID($*){
  my ($resourceID,$dbase) = @_;

  if (not defined $resourceID or $$dbase{$resourceID} eq ''){
    return 1;
  }else{
    return 0;
  }
}

sub getPathResourceID($*){

  my ($resourceID,$dbase) = @_;

  return $$dbase{$resourceID};

}

1;


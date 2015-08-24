package pDrive::hiveAPI;

#use HTTP::Cookies;
#use HTML::Form;
#use URI;
use LWP::UserAgent;
use LWP;
use strict;

use constant IS_ROOT => 1;
use constant NOT_ROOT => 0;

use constant FOLDER_TITLE => 0;
use constant FOLDER_ROOT => 1;
use constant FOLDER_PARENT => 2;
use constant FOLDER_SUBFOLDER => 3;

use constant API_URL => 'https://api.onedrive.com/v1.0';
use constant API_VER => 1;

sub new() {

	my $self = {_ident => "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/38.0.2125.104 Safari/537.36",
              _ua => undef,
              _cookiejar => undef,
              _clientID => undef,
              _clientSecret => undef,
              _refreshToken  => undef,
 			  _username => undef,
              _token => undef};

  	my $class = shift;
  	bless $self, $class;
  	$self->{_username} = shift;

 	######
	 #  Useragent
	 ###

	 # this gets logged, so it should be representative

  	# Create a user agent object
  	$self->{_ua} = new LWP::UserAgent;	# call the constructor method for this object

  	$self->{_ua}->agent($self->{_ident});		# set the identity
  	$self->{_ua}->timeout(30);		# set the timeout


  	#$self->{_cookiejar} = HTTP::Cookies->new();
  	#$self->{_ua}->cookie_jar($self->{_cookiejar});
	#  $self->{_ua}->max_redirect(0);
	#  $self->{_ua}->requests_redirectable([]);

  	$self->{_ua}->default_headers->push_header('Accept' => "image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, application/x-shockwave-flash, application/vnd.ms-excel, application/vnd.ms-powerpoint, application/msword, application/xaml+xml, application/vnd.ms-xpsdocument, application/x-ms-xbap, application/x-ms-application, */*");
  	$self->{_ua}->default_headers->push_header('Accept-Language' => "en-us");
	  #$ua->default_headers->push_header('Connection' => "close");
  	$self->{_ua}->default_headers->push_header('Connection' => "keep-alive");
  	$self->{_ua}->default_headers->push_header('Keep-Alive' => "300");
	  #$cookie_jar->load();

  	return $self;

}

##
# multiple NIC cards:
# bind to a specific IP
##
sub bindIP(*$){

 	my $self = shift;
  	my $IP = shift;

  	$self->{_ua}->local_address($IP);

}


#
# authenticate
##
sub authenticate(*$){
  	my $self = shift;
  	my $password = shift;

	my  $URL = 'https://api.hive.im/api/user/sign-in/';
	my $req = new HTTP::Request POST => $URL;
	$req->content_type("application/x-www-form-urlencoded");
	$req->protocol('HTTP/1.1');
	$req->content('email='.$self->{_username}.'&password='.$password.'&ip=MTkyLjE3MS40MC4xNg==');
	my $res = $self->{_ua}->request($req);


	my $token;
	if($res->is_success){
  		print STDOUT "success --> $URL\n\n";

  		my $block = $res->as_string;

  		while (my ($line) = $block =~ m%([^\n]*)\n%){

    		$block =~ s%[^\n]*\n%%;

    		if ($line =~ m%\"token\"\:\"[^\"]+\"%){
      			($token) = $line =~ m%\"token\"\:\"([^\"]+)\"%;
		    }

  		}
  		print STDOUT "token = $token\n" if pDrive::Config->DEBUG;

	}else{
		#print STDOUT $res->as_string;
		die ($res->as_string."error in loading page");}

	return $token;

}

#
# setTokens: access & refresh
##
sub setToken(*$$){
	my $self = shift;
	my $token = shift;
	my $refreshToken = shift;

	$self->{_refreshToken} = $refreshToken;
	$self->{_token} = $token;

}

#
# getTokens (writely and wise)
##
sub getToken(*$){
	my $self = shift;
	my $code = shift;

	my  $URL = 'https://login.live.com/oauth20_token.srf';

	my $req = new HTTP::Request POST => $URL;
	$req->content_type("application/x-www-form-urlencoded");
	$req->protocol('HTTP/1.1');
	$req->content('client_id='.$self->{_clientID}.'&redirect_uri=https://login.live.com/oauth20_desktop.srf&client_secret='.$self->{_clientSecret}.'&code='.$code.'&grant_type=authorization_code');
	my $res = $self->{_ua}->request($req);


	if (pDrive::Config->DEBUG and pDrive::Config->DEBUG_TRN){
 	 open (LOG, '>>'.pDrive::Config->DEBUG_LOG);
 	 print LOG $req->as_string;
 	 print LOG $res->as_string;
 	 close(LOG);
	}

	my $token;
	my $refreshToken;
	if($res->is_success){
  		print STDOUT "success --> $URL\n\n";

	  	my $block = $res->as_string;

		($token) = $block =~ m%\"access_token\"\:\"([^\"]+)\"%;
		($refreshToken) = $block =~ m%\"refresh_token\"\:\"([^\"]+)\"%;

	}else{
		#print STDOUT $res->as_string;
		die ($res->as_string."error in loading page");}

	$self->{_token} = $token;
	$self->{_refreshToken} = $refreshToken;
	return ($self->{_token},$self->{_refreshToken});

}


#
# refreshToken (writely and wise)
##
sub refreshToken(*){

	return; #not implemented

}


#
# get the folderID for a subfolder
##
sub getSubFolderID(*$$){

	my $self = shift;
	my $parentID = shift;
	my $folderName = shift;

	my $URL = 'https://api.hive.im/api/hive/get-children/';

	my $retryCount = 2;
	while ($retryCount){
	my $req = new HTTP::Request POST => $URL;
	$req->protocol('HTTP/1.1');
	$req->header('Content-Type' => 'application/x-www-form-urlencoded;charset=UTF-8');
	$req->content('parentId='.$parentID.'&limit=300&order=dateModified&sort=desc');
	my $res = $self->{_ua}->request($req);

	if (pDrive::Config->DEBUG and pDrive::Config->DEBUG_TRN){
  		open (LOG, '>>'.pDrive::Config->DEBUG_LOG);
  		print LOG $req->as_string;
  		print LOG $res->as_string;
  		close(LOG);
	}

	if($res->is_success){
  		return \$res->as_string;

	}elsif ($res->code == 401){
 	 	my ($token,$refreshToken) = $self->refreshToken();
		$self->setToken($token,$refreshToken);
		$retryCount--;
	}else{
		print STDOUT $res->as_string;
		$retryCount--;
		sleep(10);
		#die($res->as_string."error in loading page");
	}
	}

}

sub getList(*$){

 	my $self = shift;
  	my $resourceID = shift;


	my $URL;
	if ($resourceID eq ''){
		$URL = 'https://api.hive.im/api/hive/get/';
	}else{
		$URL = 'https://api.hive.im/api/hive/get-children/';

	}

	my $retryCount = 2;
	while ($retryCount){

		my $req;
		if ($resourceID eq ''){
			$req = new HTTP::Request GET => $URL;
			$req->protocol('HTTP/1.1');
		}else{
			$req = new HTTP::Request POST => $URL;
			$req->protocol('HTTP/1.1');
			$req->header('Content-Type' => 'application/x-www-form-urlencoded;charset=UTF-8');
			$req->content('parentId='.$resourceID.'&limit=300&order=dateModified&sort=desc');
		}
		$req->header('Client-Version' => '0.1');
		$req->header('Client-Type' => 'Browser');
		$req->header('Authorization' => $self->{_token});

		my $res = $self->{_ua}->request($req);

		if($res->is_success){
  			print STDOUT "success --> $URL\n\n"  if (pDrive::Config->DEBUG);


		}else{
			print STDOUT $res->as_string;
			$retryCount--;
			sleep(10);
			#print STDOUT $res->as_string;
			#die($res->as_string."error in loading page");
		}

  		return \$res->as_string;
	}
}




#
# get the list of changes
##
sub getChanges(*$){

	my $self = shift;
	my $URL = shift;
	my $changeID = shift;

	if ($URL eq '' and $changeID ne ''){
		$URL = 'https://api.onedrive.com/v1.0/drive/root:/:/view.changes?select=name,webUrl,size,file,folder&token='.$changeID;
	}elsif ($URL eq '' and $changeID eq ''){
		$URL = 'https://api.onedrive.com/v1.0/drive/root:/:/view.changes?select=name,webUrl,size,file,folder';
	}

	my $retryCount = 2;
	while ($retryCount){
	my $req = new HTTP::Request GET => $URL;
	$req->protocol('HTTP/1.1');
	$req->header('Authorization' => 'Bearer '.$self->{_token});
	my $res = $self->{_ua}->request($req);

	if (pDrive::Config->DEBUG and pDrive::Config->DEBUG_TRN){
  		open (LOG, '>>'.pDrive::Config->DEBUG_LOG);
  		print LOG $req->as_string;
  		print LOG $res->as_string;
  		close(LOG);
	}

	if($res->is_success){
  		print STDOUT "success --> $URL\n\n" if (pDrive::Config->DEBUG);
  		return \$res->as_string;

	}elsif ($res->code == 401){
 	 	my ($token,$refreshToken) = $self->refreshToken();
		$self->setToken($token,$refreshToken);
		$retryCount--;
	}else{
		print STDOUT $res->as_string;
		$retryCount--;
		sleep(10);
		#		print STDOUT $res->as_string;
		#die($res->as_string."error in loading page");
	}
	}

}


#
# get the next page URL
##
sub getNextURL(**){

 	my $self = shift;
  	my $listing = shift;

	my ($URL) = $$listing =~ m%\"\@odata.nextLink\"\:\s?\"([^\"]+)\"%;
	my ($hasMore) = $$listing =~ m%\"\@changes.hasMoreChanges\"\:\s?([^\,]+)\,%;

	if ($hasMore eq 'true'){
		return $URL;
	}else{
		return;
	}

}

#
# get the next change ID
##
sub getChangeID(**){

 	my $self = shift;
  	my $listing = shift;
	my ($largestChangeId) = $$listing =~ m%\"\@changes.token\"\:\s?\"([^\"]+)\"%;
	return $largestChangeId;
}


sub testAccess(*){

  	my $self = shift;

	my $URL = API_URL . '/drives/me';
	my $req = new HTTP::Request GET => $URL;
	$req->protocol('HTTP/1.1');
	$req->header('Authorization' => 'bearer '.$self->{_token});
	my $res = $self->{_ua}->request($req);

	if (pDrive::Config->DEBUG and pDrive::Config->DEBUG_TRN){
  		open (LOG, '>>'.pDrive::Config->DEBUG_LOG);
  		print LOG $req->as_string;
  		print LOG $res->as_string;
  		close(LOG);
	}

	if($res->is_success){
  		print STDOUT "success --> $URL\n\n" if (pDrive::Config->DEBUG);
  		return 1;

	}else{
		#	print STDOUT $res->as_string;
		return 0;}


}





sub downloadFile(*$$$$$$){

  my $self = shift;
  my $URL = shift;
  my $path = shift;
  my $resourceID = shift;
  my $appendex = shift;
  my $timestamp = shift;


$path .= '.'.$resourceID if ($resourceID ne '');
$path .= $appendex if ($appendex ne '');

my $req = new HTTP::Request GET => $URL;
$req->protocol('HTTP/1.1');
if ($URL =~ m%\&exportFormat%){
  $req->header('Authorization' => 'GoogleLogin auth='.$self->{_authwise});
}else{
  $req->header('Authorization' => 'GoogleLogin auth='.$self->{_authwritely});
}
$req->header('GData-Version' => '3.0');
  #$self->{_cookiejar}->add_cookie_header($req);
#my $res = $self->{_ua}->request($req);
my $res;
  open (FILE, "> ".pDrive::Config->LOCAL_PATH."/$path") or die ("Cannot save image file".pDrive::Config->LOCAL_PATH."/$path: $!\n");
  binmode(FILE);
  if ($URL =~ m%\&exportFormat%){
    $res = $self->{_ua}->get($URL,':content_cb' => \&downloadChunk,':read_size_hint' => 8192,'Authorization' => 'GoogleLogin auth='.$self->{_authwise},'GData-Version' => '3.0');
  }else{
    $res = $self->{_ua}->get($URL,':content_cb' => \&downloadChunk,':read_size_hint' => 8192,'Authorization' => 'GoogleLogin auth='.$self->{_authwritely},'GData-Version' => '3.0');
  }
  close(FILE);
  print STDOUT "saved\n";

# reduce memory consumption from slurping the entire download file in memory
#downloadChunk adapted from: http://www.perlmonks.org/?node_id=953833
# all rights reserved from original author
sub downloadChunk {
  my ($data) = @_;

  # write the $data to a filehandle or whatever should happen
  # with it here.
  print FILE $data;
}
###

if($res->is_success){
  print STDOUT "success --> $URL\n\n" if (pDrive::Config->DEBUG);

#removed (slups entire file into memory)
#  open (FILE, "> ".pDrive::Config->LOCAL_PATH."/$path") or die ("Cannot save image file".pDrive::Config->LOCAL_PATH."/$path: $!\n");
#  binmode(FILE);
#  print FILE $res->content;
#  close(FILE);
#  print STDOUT "saved\n";

  # set timestamp on file as server last updated timestamp
  utime $timestamp, $timestamp, pDrive::Config->LOCAL_PATH.'/'.$path;


#if (pDrive::Config->DEBUG){
#  open (LOG, '>'.pDrive::Config->DEBUG_LOG);
#  print LOG $req->as_string;
#  print LOG $res->as_string;
#  close(LOG);
#}

  return 1;
}else{

  if (0){
  my $block = $res->as_string;

  while (my ($line) = $block =~ m%([^\n]*)\n%){

    $block =~ s%[^\n]*\n%%;

    if ($line =~ m%^Location:%){
      ($URL) = $line =~ m%^Location:\s+(\S+)%;
      print STDERR "following location $URL\n";
      return $self->downloadFile($URL,$path,'','',$timestamp);
    }

  }
}

 # print STDOUT $req->as_string;
  print STDOUT $res->as_string;
  return 0;
}


}


###
# uplad a file in chunks
##
sub uploadFile(*$$$$){

	my $self = shift;
	my $URL = shift;
 	my $chunk = shift;
 	my $chunkSize = shift;
 	my $chunkRange = shift;




	my $retryCount = 2;
	while ($retryCount){

	my $req = new HTTP::Request PUT => $URL;
	$req->protocol('HTTP/1.1');
	$req->header('Authorization' => 'bearer '.$self->{_token});
	$req->content_type('application/octet-stream');
	$req->content_length($chunkSize);
	$req->header('Content-Range' => $chunkRange);
	$req->content($$chunk);
	my $res = $self->{_ua}->request($req);


	if (pDrive::Config->DEBUG and pDrive::Config->DEBUG_TRN){
  		open (LOG, '>>'.pDrive::Config->DEBUG_LOG);
  		print LOG $req->as_string;
  		close(LOG);
	}

	if($res->is_success or $res->code == 308){
  		my $block = $res->as_string;
		my ($resourceType,$resourceID);
		while (my ($line) = $block =~ m%([^\n]*)\n%){
			$block =~ s%[^\n]*\n%%;

		    if ($line =~ m%\"id\"\: \"%){
	    		($resourceID) = $line =~ m%\"id\"\: \"([\"]+)\"%;
	   	 	}

		}

 	 	return $resourceID;
	# need a new token?
	}elsif ($res->code == 400 ){
		if ($res->as_string =~ m%Max file size exceeded%){
	  		print STDERR "error - exceed max size";
  			return -2;  #do not retry
		}else{
	  		print STDOUT $req->headers_as_string;
  			print STDOUT $res->as_string;
  			return 0;
		}
	}elsif ($res->code == 416 ){
	  		print STDERR "range error";
  			return -2; #do not retry
	}elsif ($res->code == 401 or $res->code == 403 ){
# 	 	my ($token,$refreshToken) = $self->refreshToken();
#		$self->setToken($token,$refreshToken);
#		$retryCount--;
  		print STDERR "error";
  		print STDOUT $req->headers_as_string;
  		print STDOUT $res->as_string;
  		return -1;
	}else{
  		print STDERR "error";
  		print STDOUT $req->headers_as_string;
  		print STDOUT $res->as_string;
  		return 0;
	}
	}


}


###
# uplad an entire file (< 100MB)
##
sub uploadEntireFile(*$$$$){

  	my $self = shift;
	my $URL = shift;
	my $chunk = shift;
  	my $fileSize = shift;


	my $retryCount = 2;
	while ($retryCount){

	my $req = new HTTP::Request PUT => $URL;
	$req->protocol('HTTP/1.1');
	$req->header('Authorization' => 'bearer '.$self->{_token});
	$req->content_type('application/octet-stream');
	$req->content_length($fileSize);
	$req->content($$chunk);
	my $res = $self->{_ua}->request($req);

	if (pDrive::Config->DEBUG and pDrive::Config->DEBUG_TRN){
  		open (LOG, '>>'.pDrive::Config->DEBUG_LOG);
  		print LOG $req->as_string;
  		close(LOG);
	}

	if($res->is_success or $res->code == 308){

		return 1;
	# need a new token?
	}elsif ($res->code == 401){
 	 	my ($token,$refreshToken) = $self->refreshToken();
		$self->setToken($token,$refreshToken);
		$retryCount--;
	}else{
		print STDERR "error";
  		print STDOUT 'URL ' . $URL . "\n";
  		print STDOUT $req->headers_as_string;
  		print STDOUT $res->as_string;
  		return 0;
	}
	}


}



###
# create a file upload session
# return: URL to upload file segments
# error: return 0
##
sub createFile(*$$){

	my $self = shift;
	my $path = shift;
	my $filename = shift;

	$filename =~ s/\+//g; #remove +s in title, will be interpret as space


	my $retryCount = 2;
	while ($retryCount){
	my $req = new HTTP::Request POST  => API_URL . '/drive/root:/'.$path.'/'.$filename.':/upload.createSession';
	$req->protocol('HTTP/1.1');
	$req->header('Authorization' => 'bearer '.$self->{_token});
	$req->content_length(0);
	$req->content('');
	my $res = $self->{_ua}->request($req);



	if (pDrive::Config->DEBUG and pDrive::Config->DEBUG_TRN){
  		open (LOG, '>>'.pDrive::Config->DEBUG_LOG);
  		print LOG $req->as_string;
  		print LOG $res->as_string;
  		close(LOG);
	}

	my $uploadURL;
	if($res->is_success or $res->code == 308){

  		my $block = $res->as_string;

  		($uploadURL) = $block =~ m%\"uploadUrl\"\:\"([^\"]+)\"%;
		return $uploadURL;

	# need a new token?
	}elsif ($res->code == 401){
 	 	my ($token,$refreshToken) = $self->refreshToken();
		$self->setToken($token,$refreshToken);
		$retryCount--;

	}else{
  		print STDERR "error";
  		print STDOUT "URL = " . API_URL . '/drive/root:/'.$path.'/'.$filename.':/upload.createSession';
  		print STDOUT $req->as_string;
  		print STDOUT $res->as_string;
  		return 0;
	}
	}

}


###
#
#
#
##
sub uploadRemoteFile(*$$$){

	return; #not implemented

}

sub createFolder(*$$){

	my $self = shift;
  	my $URL = shift;
  	my $folder = shift;


  	my $content = '
{
  "name": "'.$folder.'",
  "folder":  {}
}'."\n\n";

	my $retryCount = 2;
	while ($retryCount){

	my $req = new HTTP::Request POST  => $URL;
	$req->protocol('HTTP/1.1');
	$req->header('Authorization' => 'bearer '.$self->{_token});
	$req->content_length(length $content);
	$req->content_type('application/json');
	$req->content($content);
	my $res = $self->{_ua}->request($req);



	if (pDrive::Config->DEBUG and pDrive::Config->DEBUG_TRN){
  		open (LOG, '>>'.pDrive::Config->DEBUG_LOG);
  		print LOG $req->as_string;
  		print LOG $res->as_string;
  		close(LOG);
	}

	if($res->is_success){
  		print STDOUT "success --> $URL\n\n" if (pDrive::Config->DEBUG);

  		my $block = $res->as_string;

  		while (my ($line) = $block =~ m%([^\n]*)\n%){

    		$block =~ s%[^\n]*\n%%;

		    if ($line =~ m%\"id\"\:\s?\"\d+\"%){
		    	my ($resourceID) = $line =~ m%\"id\"\:\s?\"(\d+)\"%;

	      		return $resourceID;
    		}

  		}

	# need a new token?
	}elsif ($res->code == 401){
 	 	my ($token,$refreshToken) = $self->refreshToken();
		$self->setToken($token,$refreshToken);
		$retryCount--;

	}else{
#		print STDOUT $req->as_string;
#  		print STDOUT $res->as_string;
  		return 0;
	}
	}

}

sub addFile(*$$){

	my $self = shift;
  	my $URL = shift;
  	my $file = shift;


  	my $content = '<?xml version="1.0" encoding="UTF-8"?>
<entry xmlns="http://www.w3.org/2005/Atom">
  <id>https://docs.google.com/feeds/default/private/full/file:'.$file.'</id>
</entry>'."\n\n";

	my $req = new HTTP::Request POST => $URL;
	$req->protocol('HTTP/1.1');
	$req->header('Authorization' => 'GoogleLogin auth='.$self->{_authwritely});
#	$req->header('Authorization' => 'GoogleLogin auth='.$self->{_authwise});
	$req->header('GData-Version' => '3.0');
	$req->content_length(length $content);
	$req->content_type('application/atom+xml');
	$req->content($content);

	my $res = $self->{_ua}->request($req);

	if (pDrive::Config->DEBUG and pDrive::Config->DEBUG_TRN){
  		open (LOG, '>>'.pDrive::Config->DEBUG_LOG);
  		print LOG $req->as_string;
  		print LOG $res->as_string;
  		close(LOG);
	}

	if($res->is_success){
  		print STDOUT "success --> $URL\n\n"  if (pDrive::Config->DEBUG);

  		my $block = $res->as_string;

  		while (my ($line) = $block =~ m%([^\n]*)\n%){

    		$block =~ s%[^\n]*\n%%;

		    if ($line =~ m%\<gd\:resourceId\>%){
		    	my ($resourceType,$resourceID) = $line =~ m%\<gd\:resourceId\>([^\:]*)\:?([^\<]*)\</gd:resourceId\>%;

	      		return $resourceID;
    		}

  		}

	}else{
		#print STDOUT $req->as_string;
  		print STDOUT $res->as_string;
  		return 0;
	}

}


sub deleteFile(*$$){

	return; #not implemented

}

sub editFile(*$$$$){

	return; #not implemented

}


sub readDriveListings(***){

	my $self = shift;
	my $driveListings = shift;
	my $folderID = shift;
	my %newDocuments;

	my $count=0;

  	$$driveListings =~ s%\n%%g;


#	while ($$driveListings =~ m%\"id\"\:\"[^\"]+\".*?\"title\"\:\"[^\"]+\"\,\"folder\"\:false.*?\"download\"\:\"[^\"]+\"\,.*?\"size\"\:\"\d+\"%){
#	while ($$driveListings =~ m%\"id\"\:\"[^\"]+\".*?\"title\"\:\"[^\"]+\"\,\"folder\"\:.*?\"dateModified\"\:\"[^\"]+\"%){
	while ($$driveListings =~ m%\"id\"\:\"[^\"]+\".*?\"title\"\:\"[^\"]+\"\,\"folder\"\:.*?\d\"\}%){


		my ($listing) = $$driveListings =~ m%(\"id\"\:\"[^\"]+\".*?\"title\"\:\"[^\"]+\"\,\"folder\"\:.*?\d\"\})%;
		$$driveListings =~ s%\"id\"\:\"[^\"]+\".*?\"title\"\:\"[^\"]+\"\,\"folder\"\:.*?\d\"\}%%;

		my ($resourceID,$fileName,$downloadURL,$fileSize, $folderName);
    	($resourceID,$fileName,$downloadURL,$fileSize) = $listing =~ m%\"id\"\:\"([^\"]+)\".*?\"title\"\:\"([^\"]+)\"\,\"folder\"\:false.*?\"download\"\:\"([^\"]+)\"\,.*?\"size\"\:\"(\d+)\"%;

		if ($resourceID <= 0){
			($resourceID, $folderName) = $listing =~ m%\"id\"\:\"([^\"]+)\".*?\"title\"\:\"([^\"]+)\"\,\"folder\"\:true%;
			print "FISI = $folderName $resourceID\n";
  			$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}] = $folderName;
  			$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}] = '';
		}else{
			#fix unicode
			$fileName =~ s{ \\u([0-9A-F]{4}) }{ chr hex $1 }egix;
			$fileName =~ s/\+//g; #remove +s in title for fisi
			utf8::encode($fileName);

  			$newDocuments{$resourceID}[pDrive::DBM->D->{'parent'}] = $folderID;
  			$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}] = $fileName;
  			$newDocuments{$resourceID}[pDrive::DBM->D->{'size'}] = $fileSize;
  			$newDocuments{$resourceID}[pDrive::DBM->D->{'server_link'}] = $downloadURL;
  			$newDocuments{$resourceID}[pDrive::DBM->D->{'published'}] = '';
  			$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}] = pDrive::FileIO::getMD5String($fileName .$fileSize);
#			print "FISI = $fileName $resourceID $fileSize $newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}]\n";
			print "$fileName $downloadURL\n";

		}

    	$count++;
  	}

	print STDOUT "entries = $count\n";
	return \%newDocuments;

}


#
# Parse the change listings
##
sub readChangeListings(**){

	return; #not implemented
}

1;


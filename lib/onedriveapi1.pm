package pDrive::OneDriveAPI1;

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
              _token => undef};

  	my $class = shift;
  	bless $self, $class;
	my $clientID = shift;
	my $clientSecret = shift;
	$self->{_clientID} = $clientID;
	$self->{_clientSecret} = $clientSecret;

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

#	my  $URL = 'https://login.live.com/oauth20_authorize.srf?client_id='.$self->{_clientID} . '&scope=onedrive.readwrite+wl.offline_access&response_type=code&redirect_uri=https://login.live.com/oauth20_desktop.srf';
	my  $URL = 'https://login.live.com/oauth20_token.srf';
#	my  $URL = 'http://dmdsoftware.net/api/onedrive.php';

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
	my $self = shift;

#	my  $URL = 'http://dmdsoftware.net/api/onedrive.php';
	my  $URL = 'https://login.live.com/oauth20_token.srf';
	my $req = new HTTP::Request POST => $URL;
	$req->content_type("application/x-www-form-urlencoded");
	$req->protocol('HTTP/1.1');
	$req->content('client_id='.$self->{_clientID}.'&redirect_uri=https://login.live.com/oauth20_desktop.srf&client_secret='.$self->{_clientSecret}.'&refresh_token='.$self->{_refreshToken}.'&grant_type=refresh_token');
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

	if ($token ne '' and $refreshToken ne ''){
		$self->{_token} = $token;
		$self->{_refreshToken} = $refreshToken;
	}
		return ($self->{_token},$self->{_refreshToken});


}


sub getList(*$){

  my $self = shift;
  my $URL = shift;

	if ($URL eq ''){
		$URL = 'https://www.googleapis.com/drive/v2/files?fields=nextLink%2Citems(kind%2Cid%2CmimeType%2Ctitle%2CmodifiedDate%2CcreatedDate%2CdownloadUrl%2Cparents/parentLink%2Cmd5Checksum)';
		$URL = 'https://api.onedrive.com/v1.0/drive/root:/:/view.changes?select=%40content.downloadUrl%2Cname%2Cid%2Csize%2Cfile&token=';
	}

	my $retryCount = 2;
	while ($retryCount){
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



sub getMetaData(*$){

	my $self = shift;
 	my $path = shift;
  	my $fileName = shift;

	my $URL = 'https://api.onedrive.com/v1.0/drive/root:/'.$path.'/'.$fileName;

	my $retryCount = 2;
	while ($retryCount){
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
		#$URL = 'https://api.onedrive.com/v1.0/drive/root:/:/view.changes?select=name,webUrl,size,file,folder&token='.$changeID;
		$URL = 'https://api.onedrive.com/v1.0/drive/root:/:/view.changes?select=%40content.downloadUrl%2Cname%2Cid%2Csize%2Cfile&token='.$changeID;
	}elsif ($URL eq '' and $changeID eq ''){
		$URL = 'https://api.onedrive.com/v1.0/drive/root:/:/view.changes?select=%40content.downloadUrl%2Cname%2Cid%2Csize%2Cfile';
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

	return; #not implemented


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

	my $self = shift;
	my $URL = shift;
	my $path = shift;
	my $filename = shift;

	my $req = new HTTP::Request POST  => API_URL . '/drive/root/children';
	$req->protocol('HTTP/1.1');
	$req->header('Authorization' => 'bearer '.$self->{_token});
#	$req->content_length(0);
	$req->header('Prefer' => 'respond-async');
	$req->header('Content-Type' => 'application/json');
	$req->content('{
  "@content.sourceUrl": "'.$URL.'",
  "name": "'.$filename.'",
  "file":  {}
}');
	my $res = $self->{_ua}->request($req);

	my $uploadURL;

	if (pDrive::Config->DEBUG and pDrive::Config->DEBUG_TRN){
  		open (LOG, '>>'.pDrive::Config->DEBUG_LOG);
  		print LOG $req->as_string;
  		print LOG $res->as_string;
  		close(LOG);
	}
	if($res->is_success or $res->code == 308){

  		my $block = $res->as_string;

  		my ($statusURL) = $block =~ m%Location\:\s?([^\n]+)%;
		return $statusURL;
	}else{
  		print STDERR "error";
#  		print STDOUT $req->headers_as_string;
  		print STDOUT $res->as_string;
  		return 0;
	}

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
	return; #not implemented

}


sub deleteFile(*$$){

	my $self = shift;
  	my $folderID = shift;
  	my $fileID = shift;
	return; #not implemented


}

sub editFile(*$$$$){

	my $self = shift;
	my $URL = shift;
	my $fileSize = shift;
	my $file = shift;
	my $fileType = shift;
	my $content = '';
	return; #not implemented


}


sub readDriveListings(***){

	return readChangeListings(shift,shift);
}


#
# Parse the change listings
##
sub readChangeListings(**){

	my $self = shift;
	my $driveListings = shift;
	my %newDocuments;

	my $count=0;


  	$$driveListings =~ s%\n%%g;
	#print $$driveListings;
#  	while ($$driveListings =~ m%\{\s+\"kind\"\:.*?\}\,\s+\{%){ # [^\}]+
#  	while ($$driveListings =~ m%\{\s+\"kind\"\:\s+\"drive\#file\"\,\s+\"id\"\:\s+\"[^\"]+\".*?\"md5Checksum\"\:\s+\"[^\"]+\"\s+% ){
#print STDERR $$driveListings ;
while ($$driveListings =~ m%\{\"\@content.downloadUrl\"\:\"[^\"]+\"\,\"name\"\:\"[^\"]+\"\,\"id\"\:\"[^\"]+\"\,\"size\"\:\d+\,\"file\"\:\{\"hashes\"\:\{\"crc32Hash\"\:\"[^\"]+\"\,\"sha1Hash\"\:\"[^\"]+\"\}% ){
    	my ($fileName, $resourceID, $fileSize,$sha1) = $$driveListings =~ m%\{\"\@content.downloadUrl\"\:\"[^\"]+\"\,\"name\"\:\"([^\"]+)\"\,\"id\"\:\"([^\"]+)\"\,\"size\"\:(\d+)\,\"file\"\:\{\"hashes\"\:\{\"crc32Hash\"\:\"[^\"]+\"\,\"sha1Hash\"\:\"([^\"]+)\"\}%;
		$$driveListings =~ s%\{\"\@content.downloadUrl\"\:\"[^\"]+\"\,\"name\"\:\"[^\"]+\"\,\"id\"\:\"[^\"]+\"\,\"size\"\:\d+\,\"file\"\:\{\"hashes\"\:\{\"crc32Hash\"\:\"[^\"]+\"\,\"sha1Hash\"\:\"[^\"]+\"\}%%;

		#fix unicode
		$fileName =~ s{ \\u([0-9A-F]{4}) }{ chr hex $1 }egix;
		$fileName =~ s/\+//g; #remove +s in title for fisi
		utf8::encode($fileName);


  		$newDocuments{$resourceID}[pDrive::DBM->D->{'server_sha1'}] = $sha1;
  		$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}] = $fileName;
  		$newDocuments{$resourceID}[pDrive::DBM->D->{'size'}] = $fileSize;
  		$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}] = pDrive::FileIO::getMD5String($fileName .$fileSize);
		pDrive::masterLog('saving metadata ' .$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}]. ' - fisi '.$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}].' - md5 '.$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}]. ' - size '. $newDocuments{$resourceID}[pDrive::DBM->D->{'size'}]."\n") if (pDrive::Config->DEBUG);
    	$count++;
  	}

	print STDOUT "entries = $count\n";
	return \%newDocuments;
}

1;


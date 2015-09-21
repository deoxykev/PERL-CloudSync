package pDrive::AmazonAPI;
;
use LWP::UserAgent;
use LWP;
use strict;
use IO::Handle;

use constant IS_ROOT => 1;
use constant NOT_ROOT => 0;

use constant FOLDER_TITLE => 0;
use constant FOLDER_ROOT => 1;
use constant FOLDER_PARENT => 2;
use constant FOLDER_SUBFOLDER => 3;

use constant API_URL => 'https://drive.amazonaws.com/drive/v1/';
use constant API_VER => 2;



sub new() {

	my $self = {_ident => "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/38.0.2125.104 Safari/537.36",
              _ua => undef,
              _cookiejar => undef,
              _clientID => undef,
              _clientSecret => undef,
              _refreshToken  => undef,
              _contentURL => undef,
              _metaURL => undef,
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
# getTokens
##
sub getToken(*$){
	my $self = shift;
	my $code = shift;

  	my  $URL = 'https://api.amazon.com/auth/o2/token';

	my $req = new HTTP::Request POST => $URL;
	$req->content_type("application/x-www-form-urlencoded");
	$req->protocol('HTTP/1.1');
	$req->content('grant_type=authorization_code&code='.$code.'&client_id='.$self->{_clientID}.'&client_secret='.$self->{_clientSecret}.'&redirect_uri=http%3A%2F%2Flocalhost');

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

		($token) = $block =~ m%\"access_token\"\:\s?\"([^\"]+)\"%;
		($refreshToken) = $block =~ m%\"refresh_token\"\:\s?\"([^\"]+)\"%;

	}else{
		#print STDOUT $res->as_string;
		die ($res->as_string."error in loading page");}

	$self->{_token} = $token;
	$self->{_refreshToken} = $refreshToken;
	return ($self->{_token},$self->{_refreshToken});

}


#
# refreshToken
##
sub refreshToken(*){
	my $self = shift;

	my  $URL = 'https://api.amazon.com/auth/o2/token';

	my $retryCount = 2;
	while ($retryCount){
	my $req = new HTTP::Request POST => $URL;
	$req->content_type("application/x-www-form-urlencoded");
	$req->protocol('HTTP/1.1');
	$req->content('grant_type=refresh_token&refresh_token='.$self->{_refreshToken}.'&client_id='.$self->{_clientID}.'&client_secret='.$self->{_clientSecret});
	my $res = $self->{_ua}->request($req);


	if (pDrive::Config->DEBUG and pDrive::Config->DEBUG_TRN){
 	 open (LOG, '>>'.pDrive::Config->DEBUG_LOG);
 	 print LOG $req->as_string;
 	 print LOG $res->as_string;
 	 close(LOG);
	}

	my $token;
	if($res->is_success){
  		print STDOUT "success --> $URL\n\n";

	  	my $block = $res->as_string;

		($token) = $block =~ m%\"access_token\"\:\s?\"([^\"]+)\"%;
		$retryCount=0;

	}else{
		print STDOUT $res->as_string;
		$retryCount--;
		sleep(10);
		#die ($res->as_string."error in loading page");}
	}
	if ($token ne ''){
		$self->{_token} = $token;
	}

	}
		return ($self->{_token},$self->{_refreshToken});


}


#
# Test access (validating credentials)
##
sub testAccess(*){

  	my $self = shift;
	my $URL = API_URL . 'account/endpoint';
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
  		print STDOUT "success --> $URL\n\n";
  		my ($contentURL) = $res->as_string =~ m%\"contentUrl\"\:\s?\"([^\"]+)\"%;
  		my ($metaURL) = $res->as_string =~ m%\"metadataUrl\"\:\s?\"([^\"]+)\"%;

  		$self->{_contentURL} = $contentURL;
  		$self->{_metaURL} = $metaURL;

  		return 1;

	}else{
  		print STDOUT "FAILED --> $URL\n\n";

		#	print STDOUT $res->as_string;
		return 0;}


}

#
# get list of the content
##
sub getList(*$){

	my $self = shift;
	my $URL = shift;

	if ($URL eq ''){
		#$URL = API_URL . 'nodes?filters=kind:FOLDER';
		$URL = $self->{_metaURL}. 'nodes?filters=kind:FOLDER';
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
  		print STDOUT "success --> $URL\n\n"  if (pDrive::Config->DEBUG);
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


#
#
##
sub getFolderInfo(*$){

	my $self = shift;
	my $fileID = shift;

	my $URL = 'https://www.googleapis.com/drive/v2/files/'.$fileID.'?fields=title%2Cparents';

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
  		print STDOUT "success --> $URL\n\n"  if (pDrive::Config->DEBUG);
  		my ($title) = $res->as_string =~ m%\"title\"\:\s?\"([^\"]+)\"%;
		my ($resourceID) = $res->as_string =~ m%\"parentLink\"\:\s?\"[^\"]+\/([^\"]+)\"%;
		my ($isRoot) = $res->as_string =~ m%\"isRoot\"\:\s?([^\s]+)%;
		if ($isRoot eq 'true'){
			return (0,$title,$resourceID);
		}else{
			return (1,$title,$resourceID);
		}
	}elsif ($res->code == 401){
 	 	my ($token,$refreshToken) = $self->refreshToken();
		$self->setToken($token,$refreshToken);
		$retryCount--;
	}else{
		return $fileID;

		#		print STDOUT $res->as_string;
		#die($res->as_string."error in loading page");
	}

	}
}

#
# get the root ID
##
sub getListRoot(*){

	my $self = shift;

	my $URL =  $self->{_metaURL} . 'nodes?filters=kind:FOLDER  AND isRoot:true';
	my $driveListings = $self->getList($URL);
  	my $newDocuments = $self->readDriveListings($driveListings);

  	foreach my $resourceID (keys %{$newDocuments}){
		print STDERR "returning $resourceID\n " if (pDrive::Config->DEBUG);
    	return $resourceID;
	}
	return '';

}


#
# get the list of changes
##
sub getChanges(*$){

	my $self = shift;
	my $URL = shift;
	my $changeID = shift;

	$URL = API_URL . 'changes';
  	my $content = '';
  	if ($changeID ne ''){
  		$content = '{  "checkpoint" : "'.$changeID.'" }'.  "\n\n";
	}

	my $retryCount = 2;
	while ($retryCount){
	my $req = new HTTP::Request POST => $URL;
	$req->protocol('HTTP/1.1');
	$req->header('Authorization' => 'Bearer '.$self->{_token});
	$req->content_length(length $content);
	$req->content_type('application/x-www-form-urlencoded');
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

  		}
	}elsif ($res->code == 401){
 	 	my ($token,$refreshToken) = $self->refreshToken();
		$self->setToken($token,$refreshToken);
		$retryCount--;
	}else{
		print STDOUT $res->as_string;
		$retryCount--;
		sleep(10);
		#die($res->as_string."error in loading page");}
	}
  	return \$res->decoded_content;
	}

}



#
# get the folderID for a subfolder
##
sub getSubFolderID(*$){

	my $self = shift;
	my $parentID = shift;


	#my $URL = API_URL . 'nodes/'.$folderID.'/children&filters=kind:FOLDER';

	my $URL =   $self->{_contentURL} . 'nodes?filters=kind:FOLDER';
	if ($parentID eq 'root'){
		$URL .= ' AND isRoot:true';
	}elsif ($parentID eq ''){
		$URL .= ' AND isRoot:true';
	}
	return $self->getList($URL);

}

#
# get the folderID for a subfolder
##
sub getSubFolderIDList(*$){

	my $self = shift;
	my $folderName = shift;
	return; #not implemented

}

#
# get the next page URL
##
sub getNextURL(**){

 	my $self = shift;
  	my $listing = shift;
	my ($URL) = $$listing =~ m%\"nextLink\"\:\s?\"([^\"]+)\"%;
	return $URL;
}


#
# get the next change ID
##
sub getChangeID(**){

 	my $self = shift;
  	my $listing = shift;
	my ($largestChangeId) = $$listing =~ m%\"checkpoint\"\:\s?\"([^\"]+)\"%;
	return $largestChangeId;
}




sub downloadFile(*$$$){

	my $self = shift;
  	my $path = shift;
  	my $URL = shift;
  	my $timestamp = shift;
    print STDERR "URL = $URL $self->{_token} $path\n";
    `wget --header="Authorization: Bearer $self->{_token}" "$URL" -O $path`;
    return;
	my $retryCount = 2;
	while ($retryCount){

	my $req = new HTTP::Request GET => $URL;
	$req->protocol('HTTP/1.1');
	$req->header('Authorization' => 'Bearer '.$self->{_token});
	my $res = $self->{_ua}->request($req, $path);
	 if ($res->is_success) {
     print "ok\n";
     return;
	}elsif ($res->code == 401 or $res->code == 403){

 	 	my ($token,$refreshToken) = $self->refreshToken();
		$self->setToken($token,$refreshToken);
		$retryCount--;
  }  else {

     print $res->status_line, "\n";
     return;
  }
	}
#  	open (FILE, "> ".$path) or die ("Cannot save image file".$path.": $!\n");
 # 	FILE->autoflush;
  #	binmode(FILE);
  #  $res = $self->{_ua}->get($URL,':content_cb' => \&downloadChunk,':read_size_hint' => 8192,'Authorization' => 'Bearer '.$self->{_token});
#	close(FILE);
 # 	print STDOUT "saved\n";


 	 # set timestamp on file as server last updated timestamp
 	#utime $timestamp, $timestamp, pDrive::Config->LOCAL_PATH.'/'.$path;


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



}


sub uploadFile(*$$){
	use HTTP::Request::Common;

	$HTTP::Request::Common::DYNAMIC_FILE_UPLOAD = 1;

	my $self = shift;
  	my $file = shift;
  	my $filetype = shift;
 	my $resourceID = 0;
	my ($fileName) = $file=~ m%\/([^\/]+)$%;

	if(1){
	`curl -X POST --form 'metadata={"name":"$fileName","kind":"FILE"}' --form 'content=\@$file' 'https://content-na.drive.amazonaws.com/cdproxy/nodes?localId=$fileName' --header "Authorization: Bearer $self->{_token}"`;
	}else{
	my $retryCount = 2;
	while ($retryCount){
	my $req = new HTTP::Request POST => 'https://content-na.drive.amazonaws.com/cdproxy/nodes?localId='.$file; #$self->{_contentURL}.'nodes?localId=testPhoto';
	$req->protocol('HTTP/1.1');
	$req->header('Authorization' => 'Bearer '.$self->{_token});
	$req->content_type('multipart/form-data');
	#$req->add_part(new HTTP::Message(['Content-Disposition' => 'form-data; name="metadata"'], '{"name":'.$fileName.',"kind":"FILE"}'));
	$req->add_part(new HTTP::Message(['Content-Disposition' => 'form-data; name="metadata"'], '{"name":'.$fileName.',"kind":"FILE"}'));

	#$req->content ('{"name":"test.jpg","kind":"FILE"}');
	#$req->add_part(['Content-Disposition' => 'form-data; name="metadata"'],'{"name":"test.jpg","kind":"FILE"}');

	#open(INPUT, "<".$file) or die ('cannot read file '.$file);
	#binmode(INPUT);
	#my $fileContents = do { local $/; <INPUT> };
  	#close(INPUT);

	#$req->add_part(['Content-Disposition' => 'form-data; name="content"'], 'Content => $fileContents');
	#$req->add_part(['Content-Disposition' => 'form-data; name="metadata"'],'{"name":"test.jpg","kind":"FILE"}');
	#$req->add_part(new HTTP::Message(['Content-Disposition' => 'form-data; name="content";', 'Content-Type'=>'image/jpeg', 'filename'=>'db5df4870e4e4b6cbf42727fd434701a.jpg'], $fileContents));
#my $hash = {
#  'data_file' => [ $file ],
#  'filename'  => $fileName
#};
	my $message = new HTTP::Message(['Content-Disposition' => 'form-data; name="content"; filename="'.$fileName.'"', 'Content-Type'=>'image/jpeg']);
#	my $message = new HTTP::Message(['Content-Disposition' => 'form-data; name="content"; filename="'.$fileName.'"', 'Content-Type'=>'image/jpeg'], [ file => [$file] ]);
#	my $message = new HTTP::Message(['Content-Disposition' => 'form-data; name="content"; filename="'.$fileName.'"', 'Content-Type'=>'image/jpeg'], $hash);


	open(INPUT, "<".$file) or die ('cannot read file '.$file);
	binmode(INPUT);
	#my $fileContents = do { local $/; <INPUT> };
	do { local $/; $message->add_content(<INPUT>) };
  	close(INPUT);
#	$req->add_part(new HTTP::Message(['Content-Disposition' => 'form-data; name="content"; filename="'.$fileName.'"', 'Content-Type'=>'image/jpeg'], $fileContents));
	$req->add_part($message);




	#
	#
	my $res = $self->{_ua}->request($req);



	if($res->is_success or $res->code == 308){

  		my $block = $res->as_string;
		my ($resourceType,$resourceID);
		while (my ($line) = $block =~ m%([^\n]*)\n%){
			$block =~ s%[^\n]*\n%%;

		    if ($line =~ m%\"id\"%){
		    	my ($resourceID) = $line =~ m%\"id\"\:\s?\"([^\"]+)\"%;
	      		return $resourceID;
	    	}

		}

		return $resourceID;
#	}elsif ($res->code == 401){
# 		my ($token,$refreshToken) = $self->refreshToken();
#		$self->setToken($token,$refreshToken);
#		$retryCount--;
	}else{
  		print STDERR "error";
#  		print STDOUT $req->headers_as_string;
  		print STDOUT $res->as_string;
  		return 0;
	}
	}
	}
}

#
# Create a file
##
sub createFile(*$$$$$){

	my $self = shift;
  	my $URL = shift;
  	my $fileSize = shift;
  	my $file = shift;
  	my $fileType = shift;
	my $folder = shift;


  	my $content = '{
  "title": "'.$file. '",
  "parents": [{
    "kind": "drive#fileLink",
    "id": "'.$folder.'"
  }]
}'."\n\n";

	my $retryCount = 2;
	while ($retryCount){
#  convert=false prevents plain/text from becoming docs
	my $req = new HTTP::Request POST => $URL;
	$req->protocol('HTTP/1.1');
	$req->header('Authorization' => 'Bearer '.$self->{_token});
	$req->header('X-Upload-Content-Type' => $fileType);
	$req->header('X-Upload-Content-Length' => $fileSize);
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
  		print STDOUT "success --> $URL\n\n"  if (pDrive::Config->DEBUG);

  		my $block = $res->as_string;

  		while (my ($line) = $block =~ m%([^\n]*)\n%){

    		$block =~ s%[^\n]*\n%%;

		    if ($line =~ m%^Location:%){
      			($URL) = $line =~ m%^Location:\s+(\S+)%;
	      		return $URL;
    		}

  		}
	}elsif ($res->code == 401){
 	 	my ($token,$refreshToken) = $self->refreshToken();
		$self->setToken($token,$refreshToken);
		$retryCount--;
	}else{
	#	print STDOUT $req->as_string;
  		print STDOUT $res->as_string;
  		return 0;
	}
	}

}


#
# Create a folder
##
sub createFolder(*$$){

	my $self = shift;
  	my $folder = shift;
  	my $parentFolder = shift;

	my $URL = API_URL . 'nodes';#/nodes?localId='.$folder; #$self->{_contentURL}.'nodes?localId=testPhoto';
	#"parents" : ["foo1","123"], "properties" : { "my_app_id" : {"key":"value", "key2","value2"} }
  	my $content = '{  "name" : "'.$folder.'",  '. ($parentFolder ne '' ?  '"parents" : ["'.$parentFolder.'"],':''). ' "kind" : "FOLDER" }'.  "\n\n";

	my $retryCount = 2;
	while ($retryCount){
	my $req = new HTTP::Request POST => $URL;
	$req->protocol('HTTP/1.1');
	$req->header('Authorization' => 'Bearer '.$self->{_token});
	$req->content_length(length $content);
	$req->content_type('application/x-www-form-urlencoded');
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

		    if ($line =~ m%\"id\"%){
		    	my ($resourceID) = $line =~ m%\"id\"\:\s?\"([^\"]+)\"%;
	      		return $resourceID;
    		}

  		}
	}elsif ($res->code == 401){
 	 	my ($token,$refreshToken) = $self->refreshToken();
		$self->setToken($token,$refreshToken);
		$retryCount--;

	}else{
		print STDOUT $req->as_string;
  		print STDOUT $res->as_string;
  		return 0;
	}
	}

}

#
# Add a file to a folder
# * needs updating*
##
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


#
# Delete  a file to a folder
# * needs updating*
##
sub deleteFile(*$$){

	my $self = shift;
  	my $folderID = shift;
  	my $fileID = shift;
	return; #not implemented

}


#
# Parse the drive listings
##
sub readDriveListings(**){

	my $self = shift;
	my $driveListings = shift;
	my %newDocuments;

	my $count=0;

	my $title;
  	$$driveListings =~ s%\n%%g;
#  	while ($$driveListings =~ m%\{\s*\"eTagResponse\"\:.*?\}\,\s*\{% or $$driveListings =~ m%\{\s*\"eTagResponse\"\:.*?\}\s*\]\s*\}%){
  	while ($$driveListings =~ m%\{\s*\"isRoot\"\:.*?\}\s*\]\,\"count\"% or m%\{\s*\"isRoot\"\:.*?\}\,\s*\{% or m%\{\s*\"eTagResponse\"\:.*?\}\,\s*\{% or $$driveListings =~ m%\{\s*\"eTagResponse\"\:.*?\}\s*\]\,\"count\"%){

    	my ($entry) = $$driveListings =~ m%\{\s*\"eTagResponse\"\:(.*?)\}\,\s*\{%;

		if ($entry eq ''){
    		($entry) = $$driveListings =~ m%\{\s*\"eTagResponse\"\:(.*?)\}\s*\]\,\"count\"%;
			if ($entry eq ''){
    			($entry) = $$driveListings =~ m%\{\s*\"isRoot\"\:(.*?)\}\s*\]\,\"count\"%;
				if ($entry eq ''){
    				my ($entry) = $$driveListings =~ m%\{\s*\"isRoot\"\:(.*?)\}\,\s*\{%;
    				$$driveListings =~ s%\{\s*\"isRoot\"\:(.*?)\}\,\s*%%;
			    	($title) = $entry =~ m%\"name\"\:\s?\"([^\"]+)\"%;
				}else{
	    			$$driveListings =~ s%\{\s*\"isRoot\"\:(.*?)\}\s*\]\,\"count\"%%;
		    		($title) = 'root';
    			}
			}else{
	    		$$driveListings =~ s%\{\s*\"eTagResponse\"\:(.*?)\}\s*\]\,\"count\"%%;
	    		($title) = 'root';
			}
		}else{
    		$$driveListings =~ s%\{\s*\"eTagResponse\"\:(.*?)\}\,\s*%%;
	    	($title) = $entry =~ m%\"name\"\:\s?\"([^\"]+)\"%;
		}


		my ($updated) = $entry =~ m%\"modifiedDate\"\:\s?\"([^\"]+)\"%;
		my ($published) = $entry =~ m%\"createdDate\"\:\s?\"([^\"]+)\"%;
		my ($resourceType) = $entry =~ m%\"extension\"\:\s?\"([^\"]+)\"%;
		my ($resourceID) = $entry =~ m%\"id\"\:\s?\"([^\"]+)\"%;
		#my ($downloadURL) = $entry =~ m%\"downloadUrl\"\:\s?\"([^\"]+)\"%;
		my ($parentID) = $entry =~ m%\"parents\"\:\s?\[\"([^\"]+)\"%;
		my ($md5) = $entry =~ m%\"md5\"\:\s?\"([^\"]+)\"%;
		my ($fileSize) = $entry =~ m%\"size\"\:\s?\"([^\"]+)\"%;

	    # 	is a folder
	    if ($resourceType eq '' ){


		      # is a root folder
#			}else{

#        		$$folders{$resourceID}[FOLDER_ROOT] = IS_ROOT;

 #     		}
			print STDOUT 'folder = '.(defined $title? $title:'').' '. (defined $resourceID? $resourceID:'').' *'.(defined $parentID? $parentID: '')."  \n";
  			$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}] = '';
      		$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}] = $title;

    	}else{

      		$updated =~ s%\D+%%g;
      		($updated) = $updated =~ m%^(\d{14})%;
      		$newDocuments{$resourceID}[pDrive::DBM->D->{'server_updated'}] = pDrive::Time::getEPOC($updated);
			#      $newDocuments{$resourceID}[pDrive::DBM->D->{'server_updated'}] = $updated;

      		#$newDocuments{$resourceID}[pDrive::DBM->D->{'server_link'}] = $downloadURL;
      		$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}] = $md5;
      		$newDocuments{$resourceID}[pDrive::DBM->D->{'type'}] = $resourceType;

      		($parentID) = $parentID =~ m%\/([^\/]+)$%;
      		$newDocuments{$resourceID}[pDrive::DBM->D->{'parent'}] = $parentID;

      		$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}] = $title;
      		$newDocuments{$resourceID}[pDrive::DBM->D->{'published'}] = $published;
      		$newDocuments{$resourceID}[pDrive::DBM->D->{'size'}] = $fileSize;

      		$title =~ s/\+//g; #remove +s in title for fisi)
  			$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}] = pDrive::FileIO::getMD5String($title .$fileSize);

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

	my $self = shift;
	my $driveListings = shift;
	my %newDocuments;

	my $count=0;

  	$$driveListings =~ s%\n%%g;
  	while ($$driveListings =~ m%\{\s*\"eTagResponse\"\:.*?\}\,\s*\{% or $$driveListings =~ m%\{\s*\"eTagResponse\"\:.*?\}\s*\]\s*\}%){

    	my ($entry) = $$driveListings =~ m%\{\s*\"eTagResponse\"\:(.*?)\}\,\s*\{%;

		if ($entry eq ''){
    		($entry) = $$driveListings =~ m%\{\s*\"eTagResponse\"\:(.*?)\}\s*\]\s*\}%;
	    	$$driveListings =~ s%\{\s*\"eTagResponse\"\:(.*?)\}\s*\]\s*\}%%;
		}else{
    		$$driveListings =~ s%\{\s*\"eTagResponse\"\:(.*?)\}\,\s*%%;
		}

		my ($resourceID) = $entry =~ m%\"id\"\:\s?\"([^\"]+)\"%;
		my ($md5) = $entry =~ m%\"md5\"\:\s?\"([^\"]+)\"%;
    	my ($title) = $entry =~ m%\"name\"\:\s?\"([^\"]+)\"%;
		my ($fileSize) = $entry =~ m%\"size\"\:\s?\"([^\"]+)\"%;


    	next if $md5 eq '';
#		$$driveListings =~ s%drive\#file%%;

  		$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}] = $md5;
   		$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}] = $title;
  		$newDocuments{$resourceID}[pDrive::DBM->D->{'size'}] = $fileSize;
		$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}] = pDrive::FileIO::getMD5String($title .$fileSize);

    	$count++;
  	}

	print STDOUT "entries = $count\n";
	return \%newDocuments;
}
1;

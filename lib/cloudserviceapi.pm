package pDrive::CloudServiceAPI;
	use Fcntl;


sub test(*){
	my $self = shift;
	print STDERR "in 2\n";

}


#
# getTokens
##
sub getToken(*$){
	my $self = shift;
	my $code = shift;

	my  $URL = OAUTH2_TOKEN . '/token';


	my $req = HTTP::Request->new(POST => $URL);
	$req->content_type("application/x-www-form-urlencoded");
	$req->protocol('HTTP/1.1');
	$req->content('code='.$code.'&client_id='.$self->{_clientID}.'&client_secret='.$self->{_clientSecret}.'&grant_type=authorization_code'.OAUTH2_AUTH_OTHER);
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

	my  $URL =  $self->{_oauthURL} .'/token';

	my $retryCount = 2;
	while ($retryCount){
		my $req = HTTP::Request->new(POST => $URL);

		$req->content_type("application/x-www-form-urlencoded");
		$req->protocol('HTTP/1.1');
		$req->content('client_id='.$self->{_clientID}.'&client_secret='.$self->{_clientSecret}.'&refresh_token='.$self->{_refreshToken}.'&grant_type=refresh_token');
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
# Create a file
##
sub createFile(*$$$$$){

	my $self = shift;
  	my $URL = shift;
  	my $fileSize = shift;
  	my $file = shift;
  	my $fileType = shift;
	my $folder = shift;

	return; #not implemented

}

#
# Add a file to a folder
# * needs updating*
##
sub addFile(*$$){

	my $self = shift;
  	my $URL = shift;
  	my $file = shift;

	return; #not implemented

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
# Parse the change listings
##
sub backoffDelay(*$){
	my $self = shift;
	my $retryCount = shift;

	if ($retryCount == 0){
	}elsif ($retryCount == 1){
		sleep(0.5);
	}elsif ($retryCount == 2){
		sleep(1);
	}elsif ($retryCount == 3){
		sleep(2);
	}elsif ($retryCount == 4){
		sleep(4);
	}elsif ($retryCount == 5){
		sleep(8);
	}else{
		sleep(10);
		#return 0;
	}
	return 1;

}

1;
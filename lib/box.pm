package pDrive::Box;

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
  			  _db_fisi => undef};

  	my $class = shift;
  	bless $self, $class;
	$self->{_username} = shift;
	$self->{_db_checksum} = 'bx.'.$self->{_username} . '.md5.db';
	$self->{_db_fisi} = 'bx.'.$self->{_username} . '.fisi.db';
	$self->{_dbm} = pDrive::DBM->new();


  	# initialize web connections
  	$self->{_serviceapi} = pDrive::BoxAPI->new(pDrive::Config->CLIENT_ID,pDrive::Config->CLIENT_SECRET);

  	my $loginsDBM = pDrive::DBM->new('./bx.'.$self->{_username}.'.db');
  	$self->{_login_dbm} = $loginsDBM;
  	my ($token,$refreshToken) = $loginsDBM->readLogin($self->{_username});

	$self->{_folders_dbm} = buildMemoryDBM();


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


1;
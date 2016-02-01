#
#

package pDrive;

use strict;
use Fcntl ':flock';
use Scalar::Util;

use FindBin;


#for forking
use Socket;
use IO::Handle;

# fetch hostname
use Sys::Hostname;
use constant HOSTNAME => hostname;


if (!(-e './config.cfg')){
  print STDOUT "no config file found... creating config.cfg\nYou will want to modify this file (including adding a username and password)\n";
  open(CONFIG, '>./config.cfg') or die ('cannot create config.cfg');
  print CONFIG <<EOF;
package pDrive::Config;

# must change these
use constant LOCAL_PATH => '.'; #where to download / upload from
use constant USERNAME => '';
use constant PASSWORD => '';
# google OAUTH2
use constant CLIENT_ID => '';
use constant CLIENT_SECRET => '';
# one drive OAUTH2
use constant ODCLIENT_ID => '';
use constant ODCLIENT_SECRET => '';
# amazon cloud drive OAUTH2
use constant ACDCLIENT_ID => '';
use constant ACDCLIENT_SECRET => '';

# configuration
use constant LOGFILE => '/tmp/pDrive.log';
use constant SAMPLE_LIST => 'samplelist.txt';

# when there is a new server version, save the current local as a "local_revision"
use constant REVISIONS => 1;


#for debugging
use constant DEBUG => 0;
use constant DEBUG_TRN => 0;
use constant DEBUG_LOG => '/tmp/debug.log';

#
# shouldn't need to change the values below:
#
use constant DBM_CONTAINER_FILE => LOCAL_PATH . '.pdrive.catalog.db';
use constant DBM_TYPE => 'DB_File';
use DB_File;


use constant APP_NAME => 'dmdgddperl';
1;
EOF
  close(CONFIG);
}

require './config.cfg';

use lib "$FindBin::Bin/../lib";
require 'lib/dbm.pm';
require 'lib/time.pm';
require 'lib/fileio.pm';
require 'lib/gdrive_drive.pm';
require 'lib/gdrive_photos.pm';
require 'lib/onedrive.pm';
require './lib/googledriveapi2.pm';
require './lib/onedriveapi1.pm';
require './lib/cloudservice.pm';
require './lib/googlephotosapi2.pm';
require 'lib/hive.pm';
require 'lib/hiveapi.pm';
require 'lib/amazon_clouddrive.pm';
require 'lib/amazonapi.pm';


my $filetype = {
'3gp' => 'video/3gpp',
'avi' => 'video/avi',
'mp4' => 'video/mp4',
'flv' => 'video/flv',
'mpeg' => 'video/mpeg',
'mpg' => 'video/mpeg',
'm4v' => 'video/mp4',
'pdf' => 'application/pdf'};



# magic numbers
use constant IS_ROOT => 1;
use constant NOT_ROOT => 0;

use constant FOLDER_TITLE => 0;
use constant FOLDER_ROOT => 1;
use constant FOLDER_PARENT => 2;
use constant FOLDER_SUBFOLDER => 3;

#use constant CHUNKSIZE => (256*1024);
#use constant CHUNKSIZE => 524288;
use constant CHUNKSIZE => (8*256*1024);

use Getopt::Std;
use constant USAGE => " usage: $0 [-c file.config]\n";

my %opt;
die (USAGE) unless (getopts ('c:u:p:',\%opt));

#die("missing parameter\n". USAGE) unless($opt{c} ne '');

#die("config file $opt{c} doesn't exit\n") unless (-e $opt{c});



######
#

=head1 NAME

  Scheduer Operator Script - see versioning at the end of the file

=head1 DESCRIPTION

  Main script that performs the Scheduler operator functionality.

=head2 Commands

=over

=item quit/exit

  Exit the operator script.

=back

=cut

#
###


use constant HELP => q{
 >authenticate <username> <password>
  authenticate with gdrive
 >resume
  Resume the Scheduler to allow the start of new jobs.
 >stop
  Stop and exit the Scheduler once the current jobs have finished.
 >help
  Displays the commands available.
 >quit/exits
  Exit the operator script.
};


my $currentURL;
my $nextURL;
my $driveListings;
my $createFileURL;
my $loggedInUser = '';
my $bindIP;
my @services;
my $currentService;
my $dbm = pDrive::DBM->new();
my @forkPID;
my @forkChannels;

# scripted input
my $userInput;
if ($opt{c} ne ''){

	my $command = $opt{c};
    open ($userInput, "<".$command) or  die ('cannot read file list.dir');

}else{
	$userInput = *STDIN;
}

print STDERR '>';

while (my $input = <$userInput>){

	if($input =~ m%^exit%i or$input =~ m%^quit%i){
  		last;
  	}elsif($input =~ m%^help%i or $input =~ m%\?%i){
    	print STDERR HELP;

	###
	# os-tools
	###
  	# run system os commands
  	}elsif($input =~ m%^run\s[^\n]+\n%i){

    	my ($os_command) = $input =~ m%^run\s([^\n]+)\n%;
    	print STDOUT "running $os_command\n";
    	print STDOUT `$os_command`;
  	##
	# bind to IP address
	###
  	}elsif($input =~ m%^bind\s[^\s]+%i){
    	my ($IP) = $input =~ m%^bind\s([^\s]+)%i;
    	$bindIP = $IP . ' - ';

		for (my $i=0;$i <= $#services;$i++){
			if (defined $services[$i]){
				$services[$i]->bindIP($IP);
				$loggedInUser .= ', ' if $i > 1;
				$loggedInUser .= $i. '. ' . $services[$i]->{_username};
			}
		}

    # scan local dir
  	}elsif($input =~ m%^scan dir\s[^\n]+\n%i){
    	my ($dir) = $input =~ m%^scan dir\s([^\n]+)\n%;
    	print STDOUT "directory = $dir\n";
    	pDrive::FileIO::scanDir($dir);

  	}elsif($input =~ m%^load gd\s\d+\s([^\s]+)%i){
    	my ($account,$login) = $input =~ m%^load gd\s(\d+)\s([^\s]+)%i;
		#my ($dbase,$folders) = $dbm->readHash();
		$services[$account] = pDrive::gDrive->new($login);
		$currentService = $account;

		$loggedInUser = $bindIP;
		for (my $i=0;$i <= $#services;$i++){
			if (defined $services[$i]){
				$loggedInUser .= ', ' if $i > 1;
				if ($currentService == $i){
					$loggedInUser .= '*'.$i. '*. ' . $services[$i]->{_username};
				}else{
					$loggedInUser .= $i. '. ' . $services[$i]->{_username};
				}

			}
		}
	}elsif($input =~ m%^load gds\s\d+\s([^\s]+)%i){
		require './lib/googledriveserviceapi2.pm';

    	my ($account,$login) = $input =~ m%^load gds\s(\d+)\s([^\s]+)%i;
		$services[$account] = pDrive::gDrive->newService($login);
		$currentService = $account;

		$loggedInUser = $bindIP;
		for (my $i=0;$i <= $#services;$i++){
			if (defined $services[$i]){
				$loggedInUser .= ', ' if $i > 1;
				if ($currentService == $i){
					$loggedInUser .= '*'.$i. '*. ' . $services[$i]->{_username};
				}else{
					$loggedInUser .= $i. '. ' . $services[$i]->{_username};
				}

			}
		}
	}elsif($input =~ m%^set service username\s([^\s]+)%i){

    	my ($login) = $input =~ m%^set service username\s([^\s]+)%i;
		$services[$currentService]->setService($login);
	}elsif($input =~ m%^set account\s(\d+)%i){
    	 ($currentService) = $input =~ m%^set account\s(\d+)%i;

  	}elsif($input =~ m%^load acd\s\d+\s([^\s]+)%i){
    	my ($account,$login) = $input =~ m%^load acd\s(\d+)\s([^\s]+)%i;
		$services[$account] = pDrive::amazon->new($login);
		$currentService = $account;

		$loggedInUser = $bindIP;
		for (my $i=0;$i <= $#services;$i++){
			if (defined $services[$i]){
				$loggedInUser .= ', ' if $i > 1;
				if ($currentService == $i){
					$loggedInUser .= '*'.$i. '*. ' . $services[$i]->{_username};
				}else{
					$loggedInUser .= $i. '. ' . $services[$i]->{_username};
				}

			}
		}
  	}elsif($input =~ m%^load h\s\d+\s([^\s]+)%i){
    	my ($account,$login) = $input =~ m%^load h\s(\d+)\s([^\s]+)%i;
		#my ($dbase,$folders) = $dbm->readHash();
		$services[$account] = pDrive::hive->new($login);
		$currentService = $account;

		$loggedInUser = $bindIP;
		for (my $i=0;$i <= $#services;$i++){
			if (defined $services[$i]){
				$loggedInUser .= ', ' if $i > 1;
				if ($currentService == $i){
					$loggedInUser .= '*'.$i. '*. ' . $services[$i]->{_username};
				}else{
					$loggedInUser .= $i. '. ' . $services[$i]->{_username};
				}

			}
		}
  	}elsif($input =~ m%^spawn\s+\d+\s+\-\s?[^\-]+%i){
    	my ($PID,$cmd) = $input =~ m%^spawn\s+(\d+)\s+\-\s?([^\-]+)%i;
		# send request
		print "in $cmd\n";
    	print {$forkChannels[$PID][0]} "$cmd\n";

		# receive request
		my $response;
    	chomp($response = readline($forkChannels[$PID][0]));
    	print "Parent Pid $$ just read this: `$response' -- confirmation\n";


  	}elsif($input =~ m%^fork\s+\d+%i){
    	my ($forkCount) = $input =~ m%^fork\s+(\d+)%i;
		#my ($dbase,$folders) = $dbm->readHash();
		#CHILD,PARENT
		socketpair($forkChannels[$forkCount][0], $forkChannels[$forkCount][1], AF_UNIX, SOCK_STREAM, PF_UNSPEC) or  die "socketpair: $!";
		$forkChannels[$forkCount][0]->autoflush(1);
		$forkChannels[$forkCount][1]->autoflush(1);

		my $line;
		if ($forkPID[$forkCount] = fork) {
    		close $forkChannels[$forkCount][1];

			# send request
    		print {$forkChannels[$forkCount][0]} "Parent Pid $$ is sending this work\n";

			# receive request
    		chomp($line = readline($forkChannels[$forkCount][0]));
    		print "Parent Pid $$ just read this: `$line' -- confirmation\n";

 #   		close $forkChannels[$forkCount][0];
#    		waitpid($forkPID[$forkCount],0);

		} else {
    		die "cannot fork: $!" unless defined $forkPID[$forkCount];
		    close $forkChannels[$forkCount][0];
			my $forkCmd;
			while(1){
				# receive request
	    		chomp($forkCmd = readline($forkChannels[$forkCount][1]));
    			print "Child Pid $$ just read this: `$forkCmd' -- work to process\n";
  		if($forkCmd =~ m%^load gd\s\d+\s([^\s]+)%i){
    	my ($account,$login) = $forkCmd =~ m%^load gd\s(\d+)\s([^\s]+)%i;
		$services[$account] = pDrive::gDrive->new($login);
		$currentService = $account;

		$loggedInUser = $bindIP;
		for (my $i=0;$i <= $#services;$i++){
			if (defined $services[$i]){
				$loggedInUser .= ', ' if $i > 1;
				if ($currentService == $i){
					$loggedInUser .= '*'.$i. '*. ' . $services[$i]->{_username};
				}else{
					$loggedInUser .= $i. '. ' . $services[$i]->{_username};
				}

			}
		}
  		}
    			# send request
    			print {$forkChannels[$forkCount][1]} "Child Pid $$ is sending this -- done the work\n";
			}
    		close $forkChannels[$forkCount][1];
    		exit;
		}


  	}elsif($input =~ m%^load pd\s\d+\s([^\s]+)%i){
    	my ($account,$login) = $input =~ m%^load pd\s(\d+)\s([^\s]+)%i;
		#my ($dbase,$folders) = $dbm->readHash();
		$services[$account] = pDrive::gDrive::Photos->new($login);
		$currentService = $account;

		$loggedInUser = $bindIP;
		for (my $i=0;$i <= $#services;$i++){
			if (defined $services[$i]){
				$loggedInUser .= ', ' if $i > 1;
				if ($currentService == $i){
					$loggedInUser .= '*'.$i. '*. ' . $services[$i]->{_username};
				}else{
					$loggedInUser .= $i. '. ' . $services[$i]->{_username};
				}

			}
		}

  	}elsif($input =~ m%^load od\s\d+\s([^\s]+)%i){
    	my ($account,$login) = $input =~ m%^load od\s(\d+)\s([^\s]+)%i;
		#my ($dbase,$folders) = $dbm->readHash();
		$services[$account] = pDrive::oneDrive->new($login);
		$currentService = $account;

		$loggedInUser = $bindIP;
		for (my $i=0;$i <= $#services;$i++){
			if (defined $services[$i]){
				$loggedInUser .= ', ' if $i > 1;
				if ($currentService == $i){
					$loggedInUser .= '*'.$i. '*. ' . $services[$i]->{_username};
				}else{
					$loggedInUser .= $i. '. ' . $services[$i]->{_username};
				}

			}
		}

	###
	# local-hash helpers
	###
	# dump the local-hash
  	}elsif($input =~ m%^dump dbm\s\S+%i){
    	my ($db) = $input =~ m%^dump dbm\s(\S+)\n%;
    	$dbm->printHash($db);

	# update the  the key
  	}elsif($input =~ m%^update dbm key\s\S+\s\S+\s\S+%i){
    	my ($db, $filter, $filterChange) = $input =~ m%^update dbm key\s(\S+)\s(\S+)\s(\S+)\n%;
    	$dbm->updateHashKey($db, $filter, $filterChange);




	# retrieve the datestamp for the last updated filr from the local-hash
  	#}elsif($input =~ m%^get last updated%i){
    	#my $maxTimestamp = $dbm->getLastUpdated($dbase);
    	#print STDOUT "maximum timestamp = ".$$maxTimestamp[pDrive::Time->A_DATE]." ".$$maxTimestamp[pDrive::Time->A_TIMESTAMP]."\n";


	# load MD5 with account data
  	}elsif($input =~ m%^get drive list all%i){
    	my $listURL;
    	($driveListings) = $services[$currentService]->getListAll();


  	}elsif($input =~ m%^get folderid details%i){
    	my ($folderID) = $input =~ m%^get folderid details\s([^\s]+)%i;

    	my $listURL;
    	($driveListings) = $services[$currentService]->getListAll();

  	}elsif($input =~ m%^set changeid%i){
    	my ($changeID) = $input =~ m%^set changeid\s([^\s]+)%i;
    	$services[$currentService]->updateChange($changeID);
		print STDOUT "changeID set to " . $changeID . "\n";

  	}elsif($input =~ m%^reset changeid%i){
    	$services[$currentService]->resetChange();
		print STDOUT "reset changeID\n";

	# get meta data for a file
  	}elsif($input =~ m%^get meta\s+\"[^\"]+\"\s+\"[^\"]+\"%i){
    	my ($path,$fileName) = $input =~ m%^get meta\s+\"([^\"]+)\"\s+\"([^\"]+)\"%i;
    	$services[$currentService]->getMetaData($path,$fileName);

	# load MD5 with all changes
  	}elsif($input =~ m%^get changes%i){
    	my ($driveListings) = $services[$currentService]->getChangesAll();

	# load MD5 with all changes
  	}elsif($input =~ m%^get md5\s+\"[^\"]+\"\s+\d+%i){
    	my ($fileName,$fileSize) = $input =~ m%^get md5\s+\"([^\"]+)\"\s+(\d+)%i;
		print STDOUT "fisi is ". pDrive::FileIO::getMD5String($fileName .$fileSize) . "\n";

	# load MD5 with account data of first page of results
  	}elsif($input =~ m%^get drive list%i){
    	my $listURL;
    	my ($driveListings) = $services[$currentService]->getList();

	# return the id to the root folder
  	}elsif($input =~ m%^get root id%i){
    	my ($rootID) = $services[$currentService]->getListRoot();

  	}elsif($input =~ m%^get folder path\s+\S+%i){
    	my ($id) = $input =~ m%^get folder path\s+(\S+)%i;

		my ($path) =  $services[$currentService]->getFolderInfo($id);
    	print STDOUT "returned path = $path\n";

  	}elsif($input =~ m%^get folderid\s+\S+%i){
    	my ($path) = $input =~ m%^get folderid\s+(.*)%i;

		my ($folderID) =  $services[$currentService]->getFolderIDByPath($path);
    	print STDOUT "returned path = $path, id = $folderID\n";




	# sync the entire drive in source current source with all other sources
  	}elsif($input =~ m%^sync drive\s+\S+\s+\S+%i){
    	my ($service1,$service2) = $input =~ m%^sync drive\s+(\S+)\s+(\S+)%i;

		my @drives;
		$drives[0] = $service1;
		$drives[1] = $service2;
    	#my ($rootID) = $services[$currentService]->getListRoot();
    	syncDrive(@drives);

	# sync the entire drive in source current source with all other sources
  	}elsif($input =~ m%^sync folder\s+(\S+)%i){
    	my ($folder) = $input =~ m%^sync folder\s+(\S+)%i;
		$input =~ s%^sync folder\s+\S+%%;
		my @drives;
		my $count=0;
		while ($input =~ m%^\s+\S+%){
			my ($service) = $input =~ m%^\s+(\S+)%;
			$input =~ s%^\s+\S+%%;
			$drives[$count++] = $service;
		}
    	syncFolder($folder,'',0, 0, @drives);
  	}elsif($input =~ m%^mock sync folder\s+(\S+)%i){
    	my ($folder) = $input =~ m%^mock sync folder\s+(\S+)%i;
		$input =~ s%^mock sync folder\s+\S+%%;
		my @drives;
		my $count=0;
		while ($input =~ m%^\s+\S+%){
			my ($service) = $input =~ m%^\s+(\S+)%;
			$input =~ s%^\s+\S+%%;
			$drives[$count++] = $service;
		}
    	syncFolder($folder,'',1, 0, @drives);
  	}elsif($input =~ m%^sync folderid\s\S+%i){
    	my ($folderID) = $input =~ m%^sync folderid\s+(\S+)%i;
		$input =~ s%^sync folderid\s+\S+%%;
		my @drives;
		my $count=0;
		while ($input =~ m%^\s+\S+%){
			my ($service) = $input =~ m%^\s+(\S+)%;
			$input =~ s%^\s+\S+%%;
			$drives[$count++] = $service;
			print STDOUT "service = $service\n";
		}
    	syncFolder('',$folderID,0,0, @drives);
  	}elsif($input =~ m%^copy folderid\s+\S+\spath\s+\S+%i){
    	my ($folderID, $pathTarget) = $input =~ m%^copy folderid\s+(\S+)\s+path\s+(\S+)%i;
		$input =~ s%^copy folderid\s+\S+\s+path\s+\S+%%;
		my @drives;
		my $count=0;
		while ($input =~ m%^\s+\S+%){
			my ($service) = $input =~ m%^\s+(\S+)%;
			$input =~ s%^\s+\S+%%;
			$drives[$count++] = $service;
			print STDOUT "service path = $service $pathTarget \n";
		}
    	syncGoogleFolder('',$folderID,$pathTarget,0,0, @drives);
  	}elsif($input =~ m%^copy folderid\s\S+%i){
    	my ($folderID) = $input =~ m%^copy folderid\s+(\S+)%i;
		$input =~ s%^copy folderid\s+\S+%%;
		my @drives;
		my $count=0;
		while ($input =~ m%^\s+\S+%){
			my ($service) = $input =~ m%^\s+(\S+)%;
			$input =~ s%^\s+\S+%%;
			$drives[$count++] = $service;
			print STDOUT "service = $service\n";
		}
    	syncGoogleFolder('',$folderID, '',0,0, @drives);

  	}elsif($input =~ m%^navigate folderid\s\S+%i){
    	my ($folderID) = $input =~ m%^navigate folderid\s+(\S+)%i;

    	navigateFolder('',$folderID,  $services[$currentService]);


  	}elsif($input =~ m%^sync inboundid\s\S+%i){
    	my ($folderID) = $input =~ m%^sync inboundid\s+(\S+)%i;
		$input =~ s%^sync inboundid\s+\S+%%;
		my @drives;
		my $count=0;
		while ($input =~ m%^\s+\S+%){
			my ($service) = $input =~ m%^\s+(\S+)%;
			$input =~ s%^\s+\S+%%;
			$drives[$count++] = $service;
			print STDOUT "service = $service\n";
		}
    	syncFolder('',$folderID,0,1, @drives);
  	}elsif($input =~ m%^mock sync folderid\s\S+%i){
    	my ($folderID) = $input =~ m%^mock sync folderid\s+(\S+)%i;
		$input =~ s%^mock sync folderid\s+\S+%%;
		my @drives;
		my $count=0;
		while ($input =~ m%^\s+\S+%){
			my ($service) = $input =~ m%^\s+(\S+)%;
			$input =~ s%^\s+\S+%%;
			$drives[$count++] = $service;
		}
    	syncFolder('',$folderID,1,0, @drives);
  	}elsif($input =~ m%^sync download folderid\s\S+%i){
    	my ($folderID) = $input =~ m%^sync download folderid\s+(\S+)%i;
		$input =~ s%^sync download folderid\s+\S+%%;
		my @drives;
		my $count=0;
		while ($input =~ m%^\s+\S+%){
			my ($service) = $input =~ m%^\s+(\S+)%;
			$input =~ s%^\s+\S+%%;
			$drives[$count++] = $service;
		}
    	syncFolder('DOWNLOAD',$folderID,0,0,@drives);

  	}elsif($input =~ m%^compare fisi\s+\d+\s+\d+%i){
    	my ($service1, $service2) = $input =~ m%^compare fisi\s+(\d+)\s+(\d+)%i;
		my $dbase1 = $dbm->openDBM($services[$service1]->{_db_fisi});
		my $dbase2 = $dbm->openDBM($services[$service2]->{_db_fisi});
		$dbm->compareHash($dbase1,$dbase2);
		$dbm->closeDBM($dbase1);
		$dbm->closeDBM($dbase2);


	}elsif($input =~ m%^dump md5%i){
		my $dbase = $dbm->openDBM($services[$currentService]->{_db_checksum});
		$dbm->dumpHash($dbase);
		$dbm->closeDBM($dbase);

	}elsif($input =~ m%^count dbm%i){
		my $dbase = $dbm->openDBM($services[$currentService]->{_db_checksum});
		my $count = $dbm->countHash($dbase);
		print STDOUT "hash size is records = " . $count . "\n";
		$dbm->closeDBM($dbase);
	#
  	}elsif($input =~ m%^get changeid%i){
		my $dbase = $dbm->openDBM($services[$currentService]->{_db_checksum});
		$dbm->findKey($dbase,'LAST_CHANGE');
		$dbm->closeDBM($dbase);


  	}elsif($input =~ m%^search md5%i){
    	my ($filtermd5) = $input =~ m%^search md5\s([^\s]+)%i;

		my $dbase = $dbm->openDBM($services[$currentService]->{_db_checksum});
		my $value = $dbm->findKey($dbase,$filtermd5);
		$dbm->closeDBM($dbase);
		print STDOUT "complete\n";

  	}elsif($input =~ m%^search fisi%i){
    	my ($filtermd5) = $input =~ m%^search fisi\s([^\s]+)%i;

		my $dbase = $dbm->openDBM($services[$currentService]->{_db_fisi});
		my $value = $dbm->findKey($dbase,$filtermd5);
		$dbm->closeDBM($dbase);
		print STDOUT "complete\n";

  	}elsif($input =~ m%^search file%i){
	    my ($filtermd5) = $input =~ m%^search file\s([^\s]+)%i;

		my $dbase = $dbm->openDBM($services[$currentService]->{_db_checksum});
		my $value = $dbm->findValue($dbase,$filtermd5);
		$dbm->closeDBM($dbase);
		print STDOUT "complete\n";



 	}elsif($input =~ m%^download all%i){
  		my %sortedDocuments;

   		while(1){

   			my %newDocuments = $services[$currentService]->getList();

  			foreach my $resourceID (keys %newDocuments){
		    	$sortedDocuments{$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}]} = $newDocuments{$resourceID}[pDrive::DBM->D->{'server_link'}];
	  		}
	  		last if ($services[$currentService]->{_nextURL} eq '');

  		}

  		foreach my $resourceID (sort keys %sortedDocuments){
	    	print STDOUT $sortedDocuments{$resourceID}. "\t".$resourceID. "\n";
	    	$services[$currentService]->downloadFile($sortedDocuments{$resourceID},'./'.$resourceID,'','','');
  		}

 	}elsif($input =~ m%^get download list%i){
  		my %sortedDocuments;

   		while(1){

   			my %newDocuments = $services[$currentService]->getList();

  			foreach my $resourceID (keys %newDocuments){
		    	$sortedDocuments{$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}]} = $newDocuments{$resourceID}[pDrive::DBM->D->{'server_link'}];
	  		}
	  		last if ($services[$currentService]->{_nextURL} eq '');

  		}

  		foreach my $resourceID (sort keys %sortedDocuments){
	    	print STDOUT $sortedDocuments{$resourceID}. "\t".$resourceID. "\n";
	    	$services[$currentService]->downloadFile($sortedDocuments{$resourceID},'./'.$resourceID,'','','');
  		}

  		open(OUTPUT, '>' . pDrive::Config->LOCAL_PATH . '/download.list') or die ('Cannot save to ' . pDrive::Config->LOCAL_PATH . '/download.list');
  		foreach my $resourceID (sort keys %sortedDocuments){
	    	print STDOUT $sortedDocuments{$resourceID}. "\t".$resourceID. "\n";
	#    	print OUTPUT $resourceID. "\n" . $sortedDocuments{$resourceID} . "\n";
    		print OUTPUT $resourceID. "\n" ;
  		}
  		close(OUTPUT);

	}elsif($input =~ m%^create folder%i){
    	my ($path) = $input =~ m%^create folder\s([^\n]+)\n%;

	  	my $folderID = $services[$currentService]->createFolder($path);
	    print "resource ID = " . $folderID . "\n";


	# remote upload using URL (OneDrive))
	}elsif($input =~ m%^upload url%i){
    	my ($filename,$URL) = $input =~ m%^upload url \"([^\"]+)\" ([^\n]+)\n%;
		my $statusURL = $services[$currentService]->uploadRemoteFile($URL,'',$filename);
		print STDOUT $statusURL . "\n";

	}elsif($input =~ m%^upload dir list%i){
		my ($list) = $input =~ m%^upload dir list\s([^\n]+)\n%;

		open (LIST, '<./'.$list) or  die ('cannot read file ./'.$list);
    	while (my $line = <LIST>){
			my ($dir,$folder,$filetype) = $line =~ m%([^\t]+)\t([^\t]+)\t([^\n]+)\n%;
      		print STDOUT "folder = $folder, type = $filetype\n";

      		if ($folder eq ''){
	        	print STDOUT "no files\n";
        		next;
      		}
  			$services[$currentService]->uploadFolder($dir . '/'. $folder);
    	}
    	close(LIST);


	}elsif($input =~ m%^copy fileid list%i){
		my ($list) = $input =~ m%^copy fileid list\s([^\n]+)\n%;

		open (LIST, '<./'.$list) or  die ('cannot read file ./'.$list);
    	while (my $line = <LIST>){
			my ($fileID) = $line =~ m%([^\n]+)\n%;
      		print STDOUT "fileID = $fileID\n";

  			$services[$currentService]->copyFile($fileID);
    	}
    	close(LIST);

	}elsif($input =~ m%^copy fileid%i){
		my ($fileID) = $input =~ m%^copy fileid\s([^\n]+)\n%;

		$services[$currentService]->copyFile($fileID);

	}elsif($input =~ m%^rename fileid%i){
		my ($fileID,$fileName) = $input =~ m%^rename fileid\s+(\S+)\s+([^\n]+)\n%;

		$services[$currentService]->renameFile($fileID, $fileName);

	}elsif($input =~ m%^upload list%i){
    	my ($list) = $input =~ m%^upload list\s([^\n]+)\n%;

		open (LIST, '<./'.$list) or  die ('cannot read file ./'.$list);
    	while (my $line = <LIST>){
		my ($file,$folderID) = $line =~ m%([^\t]+)\t([^\n]+)\n%;
      	print STDOUT "folder = $folderID, file = $file\n";

      	if ($folderID eq ''){
	        print STDOUT "no files\n";
        	next;
      	}

		$services[$currentService]->uploadFile($file, $folderID);

    	}
    	close(LIST);

	}elsif($input =~ m%^upload file%i){
    	my ($file) = $input =~ m%^upload file\s([^\n]+)\n%;

		$services[$currentService]->uploadFile($file, '');


	}elsif($input =~ m%^create list%i){
    	my ($list) = $input =~ m%^create list\s([^\n]+)\n%;

		my $fileHandler;
		open (LIST, '<./'.$list) or  die ('cannot read file ./'.$list);
		open (OUTPUT, '>./'.$list.'.output') or  die ('cannot read file ./'.$list.'.output');

    	while (my $line = <LIST>){
		my ($dir,$folder,$filetype) = $line =~ m%([^\t]+)\t([^\t]+)\t([^\n]+)\n%;
      	print STDOUT "folder = $folder, type = $filetype\n";

      	if ($folder eq ''){
	        print STDOUT "no files\n";
        	next;
      	}
 #     	$services[$currentService]->loadFolders();
  		$services[$currentService]->createUploadListForFolder($dir . '/'. $folder, '', '',*OUTPUT);
#		$services[$currentService]->unloadFolders();


    }
    close(LIST);
    close(OUTPUT);





  }

  if ($loggedInUser ne ''){
	print STDERR $loggedInUser.'>';
  }else{
	print STDERR '>';
  }

}

# scripted input
if ($opt{c} ne ''){
	close($userInput);
}

exit(0);

sub masterLog($){

  my $event = shift;

  my $timestamp = pDrive::Time::getTimestamp(time, 'YYYYMMDDhhmmss');
#  my $datestamp = substr($timestamp, 0, 8);

  print STDERR $event . "\n" if (pDrive::Config->DEBUG);
  open (SYSTEMLOG, '>>' . pDrive::Config->LOGFILE) or die('Cannot access application log ' . pDrive::Config->LOGFILE);
  print SYSTEMLOG HOSTNAME . ' (' . $$ . ') - ' . $timestamp . ' -  ' . $event . "\n";
  close (SYSTEMLOG);

}

sub syncDrive($){
	my (@drives) = @_;
	my @dbase;
	for(my $i=0; $i <= $#drives; $i++){
			$dbase[$drives[$i]] = $dbm->openDBM($services[$drives[$i]]->{_db_fisi});
	}
	my $nextURL = '';
	while (1){
		my $newDocuments =  $services[$drives[0]]->getList($nextURL);
  		#my $newDocuments =  $services[$currentService]->readDriveListings($driveListings);
  		foreach my $resourceID (keys %{$newDocuments}){
  			next if  $$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}] eq '';
  			#already exists; skip
  			if 	(defined($dbase[$drives[1]]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}].'_0'}) and  $dbase[$drives[1]]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}].'_0'} ne ''){
 				 print STDOUT "SKIP " . $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}] . "\n";

  			}else{
				print STDOUT "DOWNLOAD " . $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}] . "\n";
		    	$services[$drives[0]]->downloadFile('toupload',$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_link'}],$$newDocuments{$resourceID}[pDrive::DBM->D->{'published'}]);
		    	#print STDERR "parent = ". $$newDocuments{$resourceID}[pDrive::DBM->D->{'parent'}] . "\n";
		    	my $path = $services[$drives[0]]->getFolderInfo($$newDocuments{$resourceID}[pDrive::DBM->D->{'parent'}]);
				$services[$drives[1]]->createFolderByPath($path) if ($path ne '' and $path ne  '/');
				$services[$drives[1]]->uploadFile( pDrive::Config->LOCAL_PATH.'/toupload', $path, $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}]);
  			}
	  	}
	  	#

		print STDOUT "next url " . $services[0]->{_nextURL} . "\n";
  		last if  $services[0]->{_nextURL} eq '';

	}
	for(my $i=0; $i < $#drives; $i++){
		$dbm->closeDBM($dbase[$drives[$i]]);
	}

	#print STDOUT $$driveListings . "\n";

}

##
# Sync a folder (and all subfolders) from one service to one or more other services
# params: folder name OR folder ID, isMock (perform mock operation -- don't download/upload), list of services [first position is source, remaining are target]
##
sub syncFolder($){
	my ($folder, $folderID, $isMock, $isInbound, @drives) = @_;
	my @dbase;
	 print STDERR "folder = $folder\n";
	for(my $i=1; $i <= $#drives; $i++){
			$dbase[$drives[$i]][0] = $dbm->openDBM($services[$drives[$i]]->{_db_checksum});
			$dbase[$drives[$i]][1] = $dbm->openDBM($services[$drives[$i]]->{_db_fisi});
	}
	my $nextURL = '';
	my @subfolders;

	#no folder ID provided, look it up from looking at the root folder
	if ($folderID eq ''){
		$folderID =  $services[$drives[0]]->getSubFolderID($folder,'root');
	}
	push(@subfolders, $folderID);

	for (my $i=0; $i <= $#subfolders;$i++){
		$folderID = $subfolders[$i];
	while (1){

		my $newDocuments =  $services[$drives[0]]->getSubFolderIDList($folderID, $nextURL);
  		#my $newDocuments =  $services[$currentService]->readDriveListings($driveListings);

  		foreach my $resourceID (keys %{$newDocuments}){
			my $doDownload=0;
  			#folder
  			#if  ($$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}] eq ''){
  			 if  ($$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}] eq ''){
				push(@subfolders, $resourceID);
  			 }else{

				for(my $j=1; $j <= $#drives; $j++){

				#Google Drive / Amazon Cloud -> Google Drive / Amazon Cloud
	  			###
	  			#Google Drive (MD5 comparision) already exists; skip
  				if 	( (Scalar::Util::blessed($services[$drives[0]]) eq 'pDrive::gDrive' or Scalar::Util::blessed($services[$drives[0]]) eq 'pDrive::amazon')
  				and (Scalar::Util::blessed($services[$drives[$j]]) eq 'pDrive::gDrive' or Scalar::Util::blessed($services[$drives[$j]]) eq 'pDrive::amazon')
  				and  ((defined($dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_0'}) and  $dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_0'} ne '') or (defined($dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_'}) and  $dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_'} ne ''))){

				#Google -> Google Photos
	  			###
	  			#Google Drive (MD5 comparision) already exists OR > 1GB; skip
				}elsif 	(Scalar::Util::blessed($services[$drives[0]]) eq 'pDrive::gDrive' and Scalar::Util::blessed($services[$drives[$j]]) eq 'pDrive::gDrive::Photos'  and  (($$newDocuments{$resourceID}[pDrive::DBM->D->{'size'}] > 1073741824)  or (defined($dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_0'}) and  $dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_0'} ne '') or (defined($dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_'}) and  $dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_'} ne ''))){


				# TODO: check for filesystem has enough storage; skip otherwise


#				#temporary -- bypass OneDrive
#				}elsif 	(Scalar::Util::blessed($services[$drives[$j]]) eq 'pDrive::oneDrive' ){

				#Google -> OneDrive
	  			###
	  			#OneDrive > 10GB; skip
				}elsif 	(Scalar::Util::blessed($services[$drives[0]]) eq 'pDrive::gDrive' and Scalar::Util::blessed($services[$drives[$j]]) eq 'pDrive::oneDrive'  and  $$newDocuments{$resourceID}[pDrive::DBM->D->{'size'}] > 10737418240){

				#*anything* -> *anything*
	  			#	already exists; skip
  				}elsif 	((defined($dbase[$drives[$j]][1]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}].'_'}) and  $dbase[$drives[$j]][1]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}].'_'} ne '') or (defined($dbase[$drives[$j]][1]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}].'_0'}) and  $dbase[$drives[$j]][1]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}].'_0'} ne '') ){
  				}else{
  					$doDownload=1;
  				}
				}

				my $path;
				if ($doDownload and $folder eq 'DOWNLOAD'){
					print STDOUT $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}]  . ' - ' . $$newDocuments{$resourceID}[pDrive::DBM->D->{'server_link'}]  . "\n";
				}elsif ($doDownload){
  					$path = $services[$drives[0]]->getFolderInfo($$newDocuments{$resourceID}[pDrive::DBM->D->{'parent'}]);
					print STDOUT "DOWNLOAD $path " . $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}] . ' ' . $$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}]. "\n";
					unlink pDrive::Config->LOCAL_PATH.'/'.$$;
		    		$services[$drives[0]]->downloadFile($$,$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_link'}],$$newDocuments{$resourceID}[pDrive::DBM->D->{'published'}]) if !($isMock);
			    	#	print STDERR "parent = ". $$newDocsyncFoluments{$resourceID}[pDrive::DBM->D->{'parent'}] . "\n";


					for(my $j=1; $j <= $#drives; $j++){
						#Google Drive / amazon -> Google Drive / amazon
	  					###
			  			#	Google Drive (MD5 comparision) already exists; skip
  						if 	( (Scalar::Util::blessed($services[$drives[0]]) eq 'pDrive::gDrive' or Scalar::Util::blessed($services[$drives[0]]) eq 'pDrive::amazon' )
  						and (Scalar::Util::blessed($services[$drives[$j]]) eq 'pDrive::gDrive'  or Scalar::Util::blessed($services[$drives[$j]]) eq 'pDrive::amazon' )
  						and  ( (defined($dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_0'})
  								and $dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_0'} ne '')
  								or (defined($dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_'})
  								and  $dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_'} ne ''))){
							print STDOUT  "skip to service $drives[$j] (duplicate MD5)\n";


						#Google Drive -> Google Photos
	  					###
			  			#	Google Drive (MD5 comparision) already exists OR > 1GB; skip
  						}elsif 	(Scalar::Util::blessed($services[$drives[0]]) eq 'pDrive::gDrive' and Scalar::Util::blessed($services[$drives[$j]]) eq 'pDrive::gDrive::Photos'  and  (($$newDocuments{$resourceID}[pDrive::DBM->D->{'size'}] > 1073741824)  or (defined($dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_0'}) and  $dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_0'} ne '') or (defined($dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_'}) and  $dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_'} ne ''))){
							print STDOUT  "skip  to service $drives[$j] (duplicate MD5 or >1GB)\n";

			  			#		already exists; skip
#  						}elsif 	(defined($dbase[$drives[$j]]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}].'_0'}) and  $dbase[$drives[$j]]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}].'_0'} ne ''){

						#Google Drive -> One Drive
						###
  						#OneDrive > 10GB; skip
						}elsif 	(Scalar::Util::blessed($services[$drives[0]]) eq 'pDrive::gDrive' and Scalar::Util::blessed($services[$drives[$j]]) eq 'pDrive::oneDrive'  and  $$newDocuments{$resourceID}[pDrive::DBM->D->{'size'}] > 10737418240){
								print STDOUT  "skip  to service $drives[$j] (duplicate fisi or >10GB)\n";

						#*anything* -> *anything*
						}elsif 	((defined($dbase[$drives[$j]][1]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}].'_'}) and  $dbase[$drives[$j]][1]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}].'_'} ne '') or (defined($dbase[$drives[$j]][1]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}].'_0'}) and  $dbase[$drives[$j]][1]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}].'_0'} ne '') ){
							print STDOUT  "skip  to service $drives[$j] (duplicate fisi)\n";

  						}else{
  							#for inbound, remove Inbound from path when creating on target
							$path =~ s%\/inbound%%ig if ($isInbound);
							my $mypath = $services[$drives[$j]]->getFolderIDByPath($path, 1,) if ($path ne '' and $path ne  '/' and !($isMock));
							print STDOUT  "upload to service $drives[$j] ". $dbase[$drives[0]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}].'_'}."\n";
					    	pDrive::masterLog('upload to service '.Scalar::Util::blessed($services[$drives[$j]]).' #' .$drives[$j].' - '.$$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}]. ' - fisi '.$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}].' - md5 '.$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}]. ' - size '. $$newDocuments{$resourceID}[pDrive::DBM->D->{'size'}]."\n");
							$services[$drives[$j]]->uploadFile( pDrive::Config->LOCAL_PATH.'/'.$$, $mypath, $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}]) if !($isMock);
  						}
					}
					unlink pDrive::Config->LOCAL_PATH.'/'.$$;

  				}else{
 					 print STDOUT "SKIP " . $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}] . "\n";
 					 $services[$drives[0]]->deleteFile($resourceID) if ($isInbound);
  				}



			}

	  	}
		$nextURL = $services[$drives[0]]->{_nextURL};
		print STDOUT "next url " . $nextURL. "\n";
  		last if  $nextURL eq '';

	}
	}
	for(my $i=0; $i < $#drives; $i++){
		$dbm->closeDBM($dbase[$drives[$i]][0]);
		$dbm->closeDBM($dbase[$drives[$i]][1]);

	}


}


##
# Sync a folder (and all subfolders) from one Google service to one or more other Google services (using API copy command)
# params: folder name OR folder ID, isMock (perform mock operation -- don't download/upload), list of services [first position is source, remaining are target]
##
sub syncGoogleFolder($){
	my ($folder, $folderID, $pathTarget, $isMock, $isInbound, @drives) = @_;
	my @dbase;
	 print STDERR "folder = $folder\n";
	for(my $i=1; $i <= $#drives; $i++){
			$dbase[$drives[$i]][0] = $dbm->openDBM($services[$drives[$i]]->{_db_checksum});
			$dbase[$drives[$i]][1] = $dbm->openDBM($services[$drives[$i]]->{_db_fisi});
	}
	my $nextURL = '';
	my @subfolders;

	#no folder ID provided, look it up from looking at the root folder
	if ($folderID eq ''){
		$folderID =  $services[$drives[0]]->getSubFolderID($folder,'root');
	}
	push(@subfolders, $folderID);

	for (my $i=0; $i <= $#subfolders;$i++){
		$folderID = $subfolders[$i];
	while (1){

		my $newDocuments =  $services[$drives[0]]->getSubFolderIDList($folderID, $nextURL);
  		#my $newDocuments =  $services[$currentService]->readDriveListings($driveListings);

  		foreach my $resourceID (keys %{$newDocuments}){
			my $doDownload=0;
  			#folder
  			#if  ($$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}] eq ''){
  			 if  ($$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}] eq ''){
				push(@subfolders, $resourceID);
  			 }else{

				for(my $j=1; $j <= $#drives; $j++){

				#Google Drive -> Google Drive
	  			###
	  			#Google Drive (MD5 comparision) already exists; skip
  				if 	( (Scalar::Util::blessed($services[$drives[0]]) eq 'pDrive::gDrive')
  				and (Scalar::Util::blessed($services[$drives[$j]]) eq 'pDrive::gDrive')
  				and  ((defined($dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_0'}) and  $dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_0'} ne '') or (defined($dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_'}) and  $dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_'} ne ''))){

  				}else{
  					$doDownload=1;
  				}
				}

				my $path;
				if ($doDownload){
  					$path = $services[$drives[0]]->getFolderInfo($$newDocuments{$resourceID}[pDrive::DBM->D->{'parent'}]);

					for(my $j=1; $j <= $#drives; $j++){
						#Google Drive -> Google Drive
	  					###
			  			#	Google Drive (MD5 comparision) already exists; skip
  						if 	( (Scalar::Util::blessed($services[$drives[0]]) eq 'pDrive::gDrive' )
  						and (Scalar::Util::blessed($services[$drives[$j]]) eq 'pDrive::gDrive')
  						and  ( (defined($dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_0'})
  								and $dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_0'} ne '')
  								or (defined($dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_'})
  								and  $dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_'} ne ''))){
							print STDOUT  "skip to service $drives[$j] (duplicate MD5)\n";

  						}else{
  							#for inbound, remove Inbound from path when creating on target
							$path =~ s%\/[^\/]+%% if ($pathTarget ne '');
							$path = $pathTarget . '/' . $path if ($pathTarget ne '');
							my $mypath = $services[$drives[$j]]->getFolderIDByPath($path, 1,) if ($path ne '' and $path ne  '/' and !($isMock));
							print STDOUT  "copy to service $drives[$j] ". $dbase[$drives[0]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}].'_'}."\n";
					    	pDrive::masterLog('copy to service '.Scalar::Util::blessed($services[$drives[$j]]).' #' .$drives[$j].' - '.$$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}]. ' - fisi '.$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}].' - md5 '.$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}]. ' - size '. $$newDocuments{$resourceID}[pDrive::DBM->D->{'size'}]."\n");
							$services[$drives[$j]]->copyFile( $resourceID, $mypath, $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}]) if !($isMock);
  						}
					}

  				}else{
 					 print STDOUT "SKIP " . $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}] . "\n";
  				}



			}

	  	}
		$nextURL = $services[$drives[0]]->{_nextURL};
		print STDOUT "next url " . $nextURL. "\n";
  		last if  $nextURL eq '';

	}
	}
	for(my $i=0; $i < $#drives; $i++){
		$dbm->closeDBM($dbase[$drives[$i]][0]);
		$dbm->closeDBM($dbase[$drives[$i]][1]);

	}


}



##
# Sync a folder (and all subfolders) from one Google service to one or more other Google services (using API copy command)
# params: folder name OR folder ID, isMock (perform mock operation -- don't download/upload), list of services [first position is source, remaining are target]
##
sub navigateFolder($$$){
	my $folder = shift;
	my $folderID = shift;
	my $service = shift;

	my $nextURL = '';
	my @subfolders;

	push(@subfolders, $folderID);

	for (my $i=0; $i <= $#subfolders;$i++){
		$folderID = $subfolders[$i];
		while (1){

			my $newDocuments =  $service->getSubFolderIDList($folderID, $nextURL);

  			foreach my $resourceID (keys %{$newDocuments}){
	  			#	folder
  				#if  ($$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}] eq ''){
  				 if  ($$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}] eq ''){
					push(@subfolders, $resourceID);
  			 	}else{

#  					$path = $service->getFolderInfo($$newDocuments{$resourceID}[pDrive::DBM->D->{'parent'}]);

#					my $mypath = $services[$drives[$j]]->getFolderIDByPath($path, 1,) if ($path ne '' and $path ne  '/' and !($isMock));
#							print STDOUT  "copy to service $drives[$j] ". $dbase[$drives[0]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}].'_'}."\n";
#					    	pDrive::masterLog('copy to service '.Scalar::Util::blessed($services[$drives[$j]]).' #' .$drives[$j].' - '.$$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}]. ' - fisi '.$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}].' - md5 '.$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}]. ' - size '. $$newDocuments{$resourceID}[pDrive::DBM->D->{'size'}]."\n");
#							$services[$drives[$j]]->copyFile( $resourceID, $mypath, $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}]) if !($isMock);
					print STDOUT "resourceID $resourceID\n";
  				}



			}
			$nextURL = $service->{_nextURL};
			print STDOUT "next url " . $nextURL. "\n";
  			last if  $nextURL eq '';

	  	}

	}


}
__END__

=head1 AUTHORS

=over

=item * 2012.09 - initial - Dylan Durdle

=back

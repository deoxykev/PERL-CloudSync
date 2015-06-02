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
use constant LOCAL_PATH => '/u01/pdrive/'; #where to download / upload from
use constant USERNAME => '';
use constant PASSWORD => '';

# configuration
use constant LOGFILE => '/tmp/pDrive.log';
use constant SAMPLE_LIST => 'samplelist.txt';

# when there is a new server version, save the current local as a "local_revision"
use constant REVISIONS => 1;


#for debugging
use constant DEBUG => 1;
use constant DEBUG_TRN => 1;
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

    		print {$forkChannels[$forkCount][0]} "Parent Pid $$ is sending this work\n";
    		chomp($line = readline($forkChannels[$forkCount][0]));
    		print "Parent Pid $$ just read this: `$line' -- confirmation\n";
    		print {$forkChannels[$forkCount][0]} "Parent Pid $$ is sending this1 -- next\n";
 #   		chomp($line = readline($forkChannels[$forkCount][0]));
 #   		print "Parent Pid $$ just read this: `$line' -- confirmation\n";
 #   		close $forkChannels[$forkCount][0];
#    		waitpid($forkPID[$forkCount],0);
		} else {
    		die "cannot fork: $!" unless defined $forkPID[$forkCount];
		    close $forkChannels[$forkCount][0];

    		chomp($line = readline($forkChannels[$forkCount][1]));
    		print "Child Pid $$ just read this: `$line' -- work to process\n";
    		print {$forkChannels[$forkCount][1]} "Child Pid $$ is sending this -- done the work\n";
    		sleep 5;
    		chomp($line = readline($forkChannels[$forkCount][1]));
    		print "Child Pid $$ just read this: `$line'\n";
    		print {$forkChannels[$forkCount][1]} "Child Pid $$ is sending this -- done\n";

    		chomp($line = readline($forkChannels[$forkCount][1]));
    		close $forkChannels[$forkCount][1];
    		exit;
		}

#  	}elsif($input =~ m%^\d+fork\s+\d+%i){
 #   	my ($forkCount) = $input =~ m%^fork\s+(\d+)%i;

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

  	}elsif($input =~ m%^set changeid%i){
    	my ($changeID) = $input =~ m%^set changeid\s([^\s]+)%i;
    	$services[$currentService]->updateChange($changeID);
		print STDOUT "changeID set to " . $changeID . "\n";

	# load MD5 with all changes
  	}elsif($input =~ m%^get changes%i){
    	my ($driveListings) = $services[$currentService]->getChangesAll();

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



	# sync the entire drive in source current source with all other sources
  	}elsif($input =~ m%^sync drive\s+\S+\s+\S+%i){
    	my ($service1,$service2) = $input =~ m%^sync drive\s+(\S+)\s+(\S+)%i;

		my @drives;
		$drives[0] = $service1;
		$drives[1] = $service2;
    	#my ($rootID) = $services[$currentService]->getListRoot();
    	syncDrive(@drives);

	# sync the entire drive in source current source with all other sources
  	}elsif($input =~ m%^sync folder\s+\S+\s+\S+\s+\S+%i){
    	my ($folder,$service1,$service2) = $input =~ m%^sync folder\s+(\S+)\s+(\S+)\s+(\S+)%i;
		my @drives;
		$drives[0] = $service1;
		$drives[1] = $service2;
    	#my ($rootID) = $services[$currentService]->getListRoot();
    	syncFolder($folder,'',@drives);
  	}elsif($input =~ m%^sync folderid\s+\S+\s+\S+\s+\S+\s+\S+%i){
    	my ($folderID,$service1,$service2,$service3) = $input =~ m%^sync folderid\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)%i;

		my @drives;
		$drives[0] = $service1;
		$drives[1] = $service2;
		$drives[2] = $service3;
    	#my ($rootID) = $services[$currentService]->getListRoot();
    	syncFolder('',$folderID,@drives);
  	}elsif($input =~ m%^sync folderid\s+\S+\s+\S+%i){
    	my ($folderID,$service1,$service2) = $input =~ m%^sync folderid\s+(\S+)\s+(\S+)\s+(\S+)%i;

		my @drives;
		$drives[0] = $service1;
		$drives[1] = $service2;
    	#my ($rootID) = $services[$currentService]->getListRoot();
    	syncFolder('',$folderID,@drives);
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


  	}elsif($input =~ m%^search file%i){
	    my ($filtermd5) = $input =~ m%^search file\s([^\s]+)%i;

		my $dbase = $dbm->openDBM($services[$currentService]->{_db_checksum});
		my $value = $dbm->findValue($dbase,$filtermd5);
		$dbm->closeDBM($dbase);
		print STDOUT "complete\n";


 	}elsif($input =~ m%^get download list%i){
  		my %sortedDocuments;
    	my $listURL;
    	$listURL = 'https://docs.google.com/feeds/default/private/full?showfolders=true';

   		while(1){

   			($driveListings) = $services[$currentService]->getList($listURL);

  			my $nextlistURL = $services[$currentService]->getNextURL($driveListings);
  			$nextlistURL =~ s%\&amp\;%\&%g;
  			$nextlistURL =~ s%\%3A%\:%g;

	    	$listURL = $nextlistURL;



  			($createFileURL) = $services[$currentService]->getCreateURL($driveListings) if ($createFileURL eq '');
  			my %newDocuments = $services[$currentService]->readDriveListings($driveListings);

  			foreach my $resourceID (keys %newDocuments){
		    	$sortedDocuments{$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}]} = $newDocuments{$resourceID}[pDrive::DBM->D->{'server_link'}];
	  		}
	  		last if ($listURL eq '');

  		}

  		open(OUTPUT, '>' . pDrive::Config->TMP_PATH . '/download.list') or die ('Cannot save to ' . pDrive::Config->TMP_PATH . '/download.list');
  		foreach my $resourceID (sort keys %sortedDocuments){
	    	print STDOUT $sortedDocuments{$resourceID}. "\t".$resourceID. "\n";
	#    	print OUTPUT $resourceID. "\n" . $sortedDocuments{$resourceID} . "\n";
    		print OUTPUT $resourceID. "\n" ;
  		}
  		close(OUTPUT);

	#	download only all mine documents
 	#
 	}elsif($input =~ m%^download mine%i){
  		my %sortedDocuments;
    	my $listURL;
    	$listURL = 'https://docs.google.com/feeds/default/private/full/-/mine';

   		while(1){

   			($driveListings) = $services[$currentService]->getList($listURL);

  			my $nextlistURL = $services[$currentService]->getNextURL($driveListings);
  			$nextlistURL =~ s%\&amp\;%\&%g;
  			$nextlistURL =~ s%\%3A%\:%g;

	    	$listURL = $nextlistURL;


  			($createFileURL) = $services[$currentService]->getCreateURL($driveListings) if ($createFileURL eq '');
	  		my %newDocuments = $services[$currentService]->readDriveListings($driveListings);

	  		foreach my $resourceID (keys %newDocuments){
			    $sortedDocuments{$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}]} = $newDocuments{$resourceID}[pDrive::DBM->D->{'server_link'}];
		  	}
		  	last if ($listURL eq '');

  		}

  		foreach my $resourceID (sort keys %sortedDocuments){
	    	print STDOUT $sortedDocuments{$resourceID}. "\t".$resourceID. "\n";
	    	$services[$currentService]->downloadFile($sortedDocuments{$resourceID},'./'.$resourceID,'','','');
  		}

 	}elsif($input =~ m%^download all%i){
  		my %sortedDocuments;
    	my $listURL;
    	$listURL = 'https://docs.google.com/feeds/default/private/full?showfolders=true';

   		while(1){

   			($driveListings) = $services[$currentService]->getList($listURL);

  			my $nextlistURL = $services[$currentService]->getNextURL($driveListings);
  			$nextlistURL =~ s%\&amp\;%\&%g;
  			$nextlistURL =~ s%\%3A%\:%g;

	    	$listURL = $nextlistURL;

	  		($createFileURL) = $services[$currentService]->getCreateURL($driveListings) if ($createFileURL eq '');
  			my %newDocuments = $services[$currentService]->readDriveListings($driveListings);

  			foreach my $resourceID (keys %newDocuments){
		    	$sortedDocuments{$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}]} = $newDocuments{$resourceID}[pDrive::DBM->D->{'server_link'}];
	  		}
	  		last if ($listURL eq '');

  		}

  		foreach my $resourceID (sort keys %sortedDocuments){
	    	print STDOUT $sortedDocuments{$resourceID}. "\t".$resourceID. "\n";
	    	$services[$currentService]->downloadFile($sortedDocuments{$resourceID},'./'.$resourceID,'','','');
  		}


	}elsif($input =~ m%^create dir\s[^\n]+\n%i){
    	my ($dir) = $input =~ m%^create dir\s([^\n]+)\n%;

  		my $folderID = $services[$currentService]->createFolder('https://docs.google.com/feeds/default/private/full/folder%3Aroot/contents',$dir);
    	print "resource ID = " . $folderID . "\n";


	}elsif($input =~ m%^create folder%i){
    	my ($folder) = $input =~ m%^create folder\s([^\n]+)\n%;

	  	my $folderID = $services[$currentService]->createFolder($folder);
	    print "resource ID = " . $folderID . "\n";

	}elsif($input =~ m%^create path%i){
    	my ($path) = $input =~ m%^create path\s([^\n]+)\n%;

	  	my $folderID = $services[$currentService]->createFolderByPath($path);
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
 #     	$services[$currentService]->loadFolders();
  		$services[$currentService]->uploadFolder($dir . '/'. $folder);
#		$services[$currentService]->unloadFolders();


    }




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
  		foreach my $resourceID (keys $newDocuments){
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
	  	#		$services[$service1]->{_nextURL} =  $services[$service1]->{_serviceapi}->getNextURL($driveListings);

		print STDOUT "next url " . $services[0]->{_nextURL} . "\n";
  		last if  $services[0]->{_nextURL} eq '';

	}
	for(my $i=0; $i < $#drives; $i++){
		$dbm->closeDBM($dbase[$drives[$i]]);
	}

	#print STDOUT $$driveListings . "\n";

}

sub syncFolder($){
	my ($folder, $folderID, @drives) = @_;
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

  		foreach my $resourceID (keys $newDocuments){
			my $doDownload=0;
  			#folder
  			 if  ($$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}] eq ''){
				push(@subfolders, $resourceID);
  			 }else{

				for(my $j=1; $j <= $#drives; $j++){
	  			#Google Drive (MD5 comparision) already exists; skip
  				if 	(Scalar::Util::blessed($services[$drives[0]]) eq 'pDrive::gDrive' and Scalar::Util::blessed($services[$drives[$j]]) eq 'pDrive::gDrive'  and  ((defined($dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_0'}) and  $dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_0'} ne '') or (defined($dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_'}) and  $dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_'} ne ''))){
	  			#Google Drive (MD5 comparision) already exists OR > 1GB; skip
				}elsif 	(Scalar::Util::blessed($services[$drives[0]]) eq 'pDrive::gDrive' and Scalar::Util::blessed($services[$drives[$j]]) eq 'pDrive::gDrive::Photos'  and  (($$newDocuments{$resourceID}[pDrive::DBM->D->{'size'}] > 1073741824)  or (defined($dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_0'}) and  $dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_0'} ne '') or (defined($dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_'}) and  $dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_'} ne ''))){
	  			#	already exists; skip
  				}elsif 	((defined($dbase[$drives[$j]][1]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}].'_'}) and  $dbase[$drives[$j]][1]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}].'_'} ne '') or (defined($dbase[$drives[$j]][1]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}].'_0'}) and  $dbase[$drives[$j]][1]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}].'_0'} ne '') ){
  				}else{
  					$doDownload=1;
  				}
				}

				my $path;
  				if ($doDownload){
  					$path = $services[$drives[0]]->getFolderInfo($$newDocuments{$resourceID}[pDrive::DBM->D->{'parent'}]);
					print STDOUT "DOWNLOAD $path " . $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}] . ' ' . $$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}]. "\n";
					unlink pDrive::Config->LOCAL_PATH.'/'.$$;
		    		$services[$drives[0]]->downloadFile($$,$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_link'}],$$newDocuments{$resourceID}[pDrive::DBM->D->{'published'}]);
			    	#	print STDERR "parent = ". $$newDocuments{$resourceID}[pDrive::DBM->D->{'parent'}] . "\n";

					for(my $j=1; $j <= $#drives; $j++){
			  			#	Google Drive (MD5 comparision) already exists; skip
  						if 	(Scalar::Util::blessed($services[$drives[0]]) eq 'pDrive::gDrive' and Scalar::Util::blessed($services[$drives[$j]]) eq 'pDrive::gDrive'  and  ((defined($dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_0'}) and  $dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_0'} ne '') or (defined($dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_'}) and  $dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_'} ne ''))){
							print STDOUT  "skip  to service $j\n";
			  			#	Google Drive (MD5 comparision) already exists OR > 1GB; skip
  						}elsif 	(Scalar::Util::blessed($services[$drives[0]]) eq 'pDrive::gDrive' and Scalar::Util::blessed($services[$drives[$j]]) eq 'pDrive::gDrive::Photos'  and  (($$newDocuments{$resourceID}[pDrive::DBM->D->{'size'}] > 1073741824)  or (defined($dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_0'}) and  $dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_0'} ne '') or (defined($dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_'}) and  $dbase[$drives[$j]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_'} ne ''))){
							print STDOUT  "skip  to service $j\n";
			  			#		already exists; skip
#  						}elsif 	(defined($dbase[$drives[$j]]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}].'_0'}) and  $dbase[$drives[$j]]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}].'_0'} ne ''){
  						}elsif 	((defined($dbase[$drives[$j]][1]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}].'_'}) and  $dbase[$drives[$j]][1]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}].'_'} ne '') or (defined($dbase[$drives[$j]][1]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}].'_0'}) and  $dbase[$drives[$j]][1]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_fisi'}].'_0'} ne '') ){
							print STDOUT  "skip  to service $j\n";
  						}else{
							my $mypath = $services[$drives[$j]]->createFolderByPath($path) if ($path ne '' and $path ne  '/');
							print STDOUT  "upload to service $j ". $dbase[$drives[0]][0]{$$newDocuments{$resourceID}[pDrive::DBM->D->{'server_md5'}].'_'}."\n";

							$services[$drives[$j]]->uploadFile( pDrive::Config->LOCAL_PATH.'/'.$$, $mypath, $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}]);
  						}
					}

  				}else{
 					 print STDOUT "SKIP " . $$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}] . "\n";
  				}


			}

	  	}
	  	#		$services[$service1]->{_nextURL} =  $services[$service1]->{_serviceapi}->getNextURL($driveListings);

		print STDOUT "next url " . $services[0]->{_nextURL} . "\n";
  		last if  $services[0]->{_nextURL} eq '';

	}
	}
	for(my $i=0; $i < $#drives; $i++){
		$dbm->closeDBM($dbase[$drives[$i]][0]);
		$dbm->closeDBM($dbase[$drives[$i]][1]);

	}


}

__END__

=head1 AUTHORS

=over

=item * 2012.09 - initial - Dylan Durdle

=back

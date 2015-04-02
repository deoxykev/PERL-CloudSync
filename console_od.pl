#
#

package pDrive;

use strict;
use Fcntl ':flock';

use FindBin;

# fetch hostname
use Sys::Hostname;
use constant HOSTNAME => hostname;


if (!(-e './config_od.cfg')){
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

require './config_od.cfg';

use lib "$FindBin::Bin/../lib";
require 'lib/dbm.pm';
require 'lib/time.pm';
require 'lib/fileio.pm';
require 'lib/onedrive.pm';
require './lib/onedriveapi1.pm';



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
  authenticate
 >resume
  Resume the Scheduler to allow the start of new jobs.
 >stop
  Stop and exit the Scheduler once the current jobs have finished.
 >help
  Displays the commands available.
 >quit/exits
  Exit the operator script.
};


my $dbm = pDrive::DBM->new();
my ($dbase,$folders) = $dbm->readHash();
my $service;
my $currentURL;
my $nextURL;
my $driveListings;
my $createFileURL;
my $loggedInUser = '';


$service = pDrive::oneDrive->new();


# 	scripted input
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

  		}elsif($input =~ m%^help%){
    		print STDERR HELP;
		   # 	run system os commands
  		}elsif($input =~ m%^run\s[^\n]+\n%i){

	    	my ($os_command) = $input =~ m%^run\s([^\n]+)\n%;
    		print STDOUT "running $os_command\n";
    		print STDOUT `$os_command`;

		}elsif($input =~ m%^dump dbm%i){

    		my ($parameter) = $input =~ m%^dump dbm\s+(\S+)%i;
    		$dbm->printHash($parameter);

		##
		# bind to IP address
		###
  		}elsif($input =~ m%^bind\s[^\s]+%i){
    		my ($IP) = $input =~ m%^bind\s([^\s]+)%i;
    		$service->bindIP($IP);
    		$loggedInUser .= '-' .$IP;

		}elsif($input =~ m%^create dir\s[^\n]+\n%i){
    		my ($dir) = $input =~ m%^create dir\s([^\n]+)\n%;

  			my $folderID = $service->createFolder('https://docs.google.com/feeds/default/private/full/folder%3Aroot/contents',$dir);
		    print "resource ID = " . $folderID . "\n";

		}elsif($input =~ m%^upload test%i){

			$service->uploadFile('/tmp/TEST.txt', 'uploaded', 'TEST.txt');
			print STDOUT "complete\n";
		}elsif($input =~ m%^upload url%i){
    		my ($filename,$URL) = $input =~ m%^upload url \"([^\"]+)\" ([^\n]+)\n%;
			my $statusURL = $service->uploadRemoteFile($URL,'',$filename);
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
  				$dir = $dir . '/' . $folder;
    			print STDOUT "directory = $dir\n";
    			my @fileList = pDrive::FileIO::getFilesDir($dir);

    			for (my $i=0; $i <= $#fileList; $i++){
					print STDOUT $fileList[$i] . "\n";

    				my ($fileName) = $fileList[$i] =~ m%\/([^\/]+)$%;

					$service->uploadFile($fileList[$i], 'new', $fileName);

	    		}
    		}
	  	}
	  	print STDERR '>';

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

__END__

=head1 AUTHORS

=over

=item * 2012.09 - initial - Dylan Durdle

=back

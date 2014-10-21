#
#

package pDrive;

use strict;
use Fcntl ':flock';

use FindBin;

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
require 'lib/gdrive.pm';
require './lib/googledocsapi3.pm';



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
use constant CHUNKSIZE => 524288;

#use Getopt::Std;
#use constant USAGE => " usage: $0 [-c file.config]\n";

#my %opt;
#die (USAGE) unless (getopts ('c:',\%opt));

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


my $dbm = pDrive::DBM->new();
my ($dbase,$folders) = $dbm->readHash();
my $gdrive;
my $currentURL;
my $nextURL;
my $driveListings;
my $createFileURL;

print STDERR '>';
while (my $input = <STDIN>){

  if($input =~ m%^exit%i or$input =~ m%^quit%i){
    last;
  }elsif($input =~ m%^help%i or $input =~ m%\?%i){
    print STDERR HELP;
  }elsif($input =~ m%^fix server md5%i){

    $dbm->fixServerMD5($dbase);
    $dbm->writeHash($dbase,$folders);
  }elsif($input =~ m%^clear local md5%i){

    $dbm->clearLocalMD5($dbase);
    $dbm->writeHash($dbase,$folders);

  }elsif($input =~ m%^fix timestamps%i){

    $dbm->fixTimestamps($dbase);
    $dbm->writeHash($dbase,$folders);

  }elsif($input =~ m%^dump dbm%i){

    my ($parameter) = $input =~ m%^dump dbm\s+(\S+)%i;
    $dbm->printHash($parameter);

  }elsif($input =~ m%^get lastupdated%i){
    my $maxTimestamp = $dbm->getLastUpdated($dbase);
    print STDOUT "maximum timestamp = ".$$maxTimestamp[pDrive::Time->A_DATE]." ".$$maxTimestamp[pDrive::Time->A_TIMESTAMP]."\n";


  }elsif($input =~ m%^get drive list%i){
    my $listURL;
    ($driveListings) = $gdrive->getList($gdrive->getListURL());

  	my ($nextlistURL) = $gdrive->getNextURL($driveListings);
  	$nextlistURL =~ s%\&amp\;%\&%g;
  	$nextlistURL =~ s%\%3A%\:%g;

  	if ($nextlistURL eq $listURL){
	    print STDERR "reset fetch\n";
	    $listURL = 'https://docs.google.com/feeds/default/private/full?showfolders=true';
  	}else{
	    $listURL = $nextlistURL;
  	}

  	($createFileURL) = $gdrive->getCreateURL($driveListings) if ($createFileURL eq '');
  	my %newDocuments = $gdrive->readDriveListings($driveListings,$folders);

  	foreach my $resourceID (keys %newDocuments){
    	print STDOUT "new document -> ".$newDocuments{$resourceID}[pDrive::DBM->D->{'title'}]. "\n";
	}

 }elsif($input =~ m%^get download list%i){
  	my %sortedDocuments;
    my $listURL;
    $listURL = 'https://docs.google.com/feeds/default/private/full?showfolders=true';

   	while(1){

   		($driveListings) = $gdrive->getList($listURL);

  		my $nextlistURL = $gdrive->getNextURL($driveListings);
  		$nextlistURL =~ s%\&amp\;%\&%g;
  		$nextlistURL =~ s%\%3A%\:%g;

	    $listURL = $nextlistURL;



  		($createFileURL) = $gdrive->getCreateURL($driveListings) if ($createFileURL eq '');
  		my %newDocuments = $gdrive->readDriveListings($driveListings,$folders);

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

  }elsif($input =~ m%^authenticate\s[^\s]+\s[^\s]+%i){
    my ($username, $password) = $input =~ m%^authenticate\s([^\s]+)\s([^\s]+)%i;
    $gdrive = pDrive::GoogleDocsAPI3->new();
    $gdrive->authenticate($username,$password);

  }elsif($input =~ m%^upload test%i){

  my $file = './201309.pdf';
  my $fileSize =  -s "$file";
  my $filetype = 'application/pdf';
  print STDOUT "file size for $file is $fileSize\n" if (pDrive::Config->DEBUG);

  my $uploadURL = $gdrive->createFile($createFileURL,$fileSize,$file,$filetype);

  my $chunkNumbers = int($fileSize/(CHUNKSIZE))+1;
  my $pointerInFile=0;
  print STDOUT "file number is $chunkNumbers\n" if (pDrive::Config->DEBUG);
  open(INPUT, "<".$file) or die ('cannot read file '.$file);
  binmode(INPUT);


  for (my $i=0; $i < $chunkNumbers; $i++){
    my $chunkSize = CHUNKSIZE;

    my $chunk;
    if ($i == $chunkNumbers-1){
      $chunkSize = $fileSize - $pointerInFile;
    }
    sysread INPUT, $chunk, CHUNKSIZE;
    print STDOUT 'uploading chunk ' . $i.  "\n";
    $gdrive->uploadFile($uploadURL,\$chunk,$chunkSize,'bytes '.$pointerInFile.'-'.($i == $chunkNumbers-1? $fileSize-1: ($pointerInFile+$chunkSize-1)).'/'.$fileSize,$filetype);
    print STDOUT 'next location = '.$uploadURL."\n";
    $pointerInFile += $chunkSize;
  }
  close(INPUT);


  }elsif($input =~ m%^upload list%i){


#    my $uploadURL = $gdrive->createFile($createFileURL);
#    my $file = '/tmp/test_receipt.pdf';

    open (LIST, "<./list.txt") or  die ('cannot read file list.txt');
    while (my $line = <LIST>){
		my ($path,$file,$filetype) = $line =~ m%([^\t]+)\t([^\t]+)\t([^\n]+)\n%;
      	print STDOUT "file = $file, type = $filetype\n";

      	if ($file eq ''){
	        print STDOUT "no files\n";
        	next;
      	}

#  open(INPUT, "<".$path.'/'.$file) or die ('cannot read file '.$path.'/'.$file);
#  binmode(INPUT);
#  my $fileContents = do { local $/; <INPUT> };
#  close(INPUT);
#  my $fileSize = length $fileContents;
#  print STDOUT "file size for $file is $fileSize\n" if (pDrive::Config->DEBUG);
#
#  my $uploadURL = $gdrive->createFile($createFileURL,$fileSize,$file,$filetype);
#
#  my $chunkNumbers = int($fileSize/(CHUNKSIZE))+1;
#  my $pointerInFile=0;
#  print STDOUT "file number is $chunkNumbers\n" if (pDrive::Config->DEBUG);
#  for (my $i=0; $i < $chunkNumbers; $i++){
#    my $chunkSize = CHUNKSIZE;

#    my $chunk;
#    if ($i == $chunkNumbers-1){
#      $chunkSize = $fileSize - $pointerInFile;
#    }
#    $chunk = substr($fileContents, $pointerInFile, $chunkSize);
#    print STDOUT 'uploading chunk ' . $i.  "\n";
#    $gdrive->uploadFile($uploadURL,\$chunk,$chunkSize,'bytes '.$pointerInFile.'-'.($i == $chunkNumbers-1? $fileSize-1: ($pointerInFile+$chunkSize-1)).'/'.$fileSize,$filetype);
#    print STDOUT 'next location = '.$uploadURL."\n";
#    $pointerInFile += $chunkSize;
#  }

	  	my $fileSize =  -s "$path/$file";
	  	print STDOUT "file size for $file is $fileSize of type $filetype\n" if (pDrive::Config->DEBUG);

  		my $uploadURL = $gdrive->createFile($createFileURL,$fileSize,$file,$filetype);

  		my $chunkNumbers = int($fileSize/(CHUNKSIZE))+1;
  		my $pointerInFile=0;
  		print STDOUT "file number is $chunkNumbers\n" if (pDrive::Config->DEBUG);
  		open(INPUT, "<".$path.'/'.$file) or die ('cannot read file '.$path.'/'.$file);
  		binmode(INPUT);

	  	print STDERR 'uploading chunks [' . $chunkNumbers.  "]...";
	  	for (my $i=0; $i < $chunkNumbers; $i++){
		    my $chunkSize = CHUNKSIZE;

	    	my $chunk;
	    	if ($i == $chunkNumbers-1){
	      		$chunkSize = $fileSize - $pointerInFile;
    		}
    		sysread INPUT, $chunk, CHUNKSIZE;
    		print STDERR $i;
    		my $status=0;
    		while ($status == 0){
	      		$status = $gdrive->uploadFile($uploadURL,\$chunk,$chunkSize,'bytes '.$pointerInFile.'-'.($i == $chunkNumbers-1? $fileSize-1: ($pointerInFile+$chunkSize-1)).'/'.$fileSize,$filetype);
    	  		if ($status == 0){
        			print STDERR "retry\n";
        			sleep (5);
		    	}
    		}

	    	$pointerInFile += $chunkSize;
  		}
  		close(INPUT);
  		print STDOUT "\n";

	}
    close (LIST);

  }elsif($input =~ m%^scan dir\s[^\n]+\n%i){
    my ($dir) = $input =~ m%^upload dir\s([^\n]+)\n%;
    print STDOUT "directory = $dir\n";
    pDrive::FileIO::scanDir($dir);

  }elsif($input =~ m%^get edit\s[^\s]+\s[^\n]+\n%i){
    my ($resourceID,$path) = $input =~ m%^get edit\s([^\s]+)\s([^\n]+)\n%;
    print STDOUT "resource $resourceID, path = $path\n";
    print STDOUT "value = $$dbase{$path}{$resourceID}[pDrive::DBM->D->{'server_edit'}]\n";

  }elsif($input =~ m%^upload edit\s[^\s]+\s[^\n]+\n%i){
    my ($resourceID,$path) = $input =~ m%^upload edit\s([^\s]+)\s([^\n]+)\n%;
    my $fullPath = pDrive::Config->LOCAL_PATH . $path;
    print STDOUT "resource $resourceID, path = $fullPath\n";
    print STDOUT "value = $$dbase{$path}{$resourceID}[pDrive::DBM->D->{'server_edit'}]\n";
  	my $fileSize =  -s $fullPath;
  	my $filetype = 'text/plain';
  	print STDOUT "file size for $fullPath is $fileSize of type $filetype\n" if (pDrive::Config->DEBUG);

  	my $uploadURL = $gdrive->editFile($$dbase{$path}{$resourceID}[pDrive::DBM->D->{'server_edit'}],$fileSize,$fullPath,$filetype);

  	my $chunkNumbers = int($fileSize/(CHUNKSIZE))+1;
  	my $pointerInFile=0;
  	print STDOUT "file number is $chunkNumbers\n" if (pDrive::Config->DEBUG);
  	open(INPUT, "<".$fullPath) or die ('cannot read file '.$fullPath);
  	binmode(INPUT);

  	print STDERR 'uploading chunks [' . $chunkNumbers.  "]...";
  	for (my $i=0; $i < $chunkNumbers; $i++){
	    my $chunkSize = CHUNKSIZE;

	    my $chunk;
	    if ($i == $chunkNumbers-1){
      		$chunkSize = $fileSize - $pointerInFile;
    	}
    	sysread INPUT, $chunk, CHUNKSIZE;
    	print STDERR $i;
    	my $status=0;
    	while ($status == 0){
      		$status = $gdrive->uploadFile($uploadURL,\$chunk,$chunkSize,'bytes '.$pointerInFile.'-'.($i == $chunkNumbers-1? $fileSize-1: ($pointerInFile+$chunkSize-1)).'/'.$fileSize,$filetype);
      		if ($status == 0){
        		print STDERR "retry\n";
        		sleep (5);
      		}
    	}
	    $pointerInFile += $chunkSize;
  	}
  	close(INPUT);
  	print STDOUT "\n";


  }elsif($input =~ m%^upload dir\s[^\n]+\n%i){
    my ($dir) = $input =~ m%^upload dir\s([^\n]+)\n%;
    print STDOUT "directory = $dir\n";
    my @fileList = pDrive::FileIO::getFilesDir($dir);

    for (my $i=0; $i <= $#fileList; $i++){
      print STDOUT $fileList[$i] . "\n";

  	my $fileSize =  -s $fileList[$i];
  	my $filetype = 'text/plain';
  	print STDOUT "file size for $fileList[$i] is $fileSize of type $filetype\n" if (pDrive::Config->DEBUG);

  	my $uploadURL = $gdrive->createFile($createFileURL,$fileSize,$fileList[$i],$filetype);


  	my $chunkNumbers = int($fileSize/(CHUNKSIZE))+1;
	my $pointerInFile=0;
  	print STDOUT "file number is $chunkNumbers\n" if (pDrive::Config->DEBUG);
  	open(INPUT, "<".$fileList[$i]) or die ('cannot read file '.$fileList[$i]);

  	binmode(INPUT);

  	print STDERR 'uploading chunks [' . $chunkNumbers.  "]...";
  	for (my $i=0; $i < $chunkNumbers; $i++){
	    my $chunkSize = CHUNKSIZE;


    my $chunk;
    if ($i == $chunkNumbers-1){
      $chunkSize = $fileSize - $pointerInFile;
    }

    sysread INPUT, $chunk, CHUNKSIZE;
    print STDERR $i;
    my $status=0;
    while ($status == 0){

      $status = $gdrive->uploadFile($uploadURL,\$chunk,$chunkSize,'bytes '.$pointerInFile.'-'.($i == $chunkNumbers-1? $fileSize-1: ($pointerInFile+$chunkSize-1)).'/'.$fileSize,$filetype);
      if ($status == 0){
        print STDERR "retry\n";
        sleep (5);
      }
    }
#    print STDOUT 'next location = '.$uploadURL."\n";
    $pointerInFile += $chunkSize;
  }
  close(INPUT);
  print STDOUT "\n";
    }



  }elsif($input =~ m%^set listurl%i){


    my ($parameter) = $input =~ m%^set listurl\s+(\S+)%i;
    if ($parameter ne ''){
      $currentURL = 'https://docs.google.com/feeds/default/private/full?showfolders=true&q=after:'.$parameter;
    }else{
      $currentURL = 'https://docs.google.com/feeds/default/private/full?showfolders=true';
    }
    print STDOUT "list list URL = $currentURL\n";



  }elsif($input =~ m%^get current%i){

    my ($driveListings) = $gdrive->getList($currentURL);

    ($nextURL) = $gdrive->getNextURL($driveListings);
    $nextURL =~ s%\&amp\;%\&%g;
    $nextURL =~ s%\%3A%\:%g;
    $nextURL .= '&showfolders=true' if ($nextURL ne '' and !($nextURL =~ m%showfolders%));


    print STDOUT "next list URL = $nextURL\n";

  }

  print STDERR '>';

}



exit(0);


__END__

=head1 AUTHORS

=over

=item * 2012.09 - initial - Dylan Durdle

=back

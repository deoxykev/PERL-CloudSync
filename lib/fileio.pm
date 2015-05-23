package pDrive::FileIO;

use strict;
use Digest::MD5;
use File::stat;


####
#retrieve MD5 of the local stored file
#
####
sub getMD5($){
  my $file = shift;

  return 0 unless (-e $file and !(-d $file));

  my $md5 = Digest::MD5->new;
  open(FILE, $file);
  binmode(FILE);

  my $md5sum = $md5->addfile(*FILE)->hexdigest;
  close(FILE);

  return $md5sum;

}

####
#retrieve MD5 of the string
#
####
sub getMD5String($){
  my $md5String = shift;

  my $md5 = Digest::MD5->new;
  my $md5sum = $md5->add($md5String)->hexdigest;
  return $md5sum;

}

####
# mkdir
# /dir1/dir2/dir3
####
sub traverseMKDIR($){

  my $path = shift;

  #strip filenames
  $path =~ s%[^/]+$%%;
  print STDOUT "mkdir test path $path\n"  if (pDrive::Config->DEBUG);
  if (!(-e $path) and ($path =~ m%/.*/[^/]+/%)){
#    my ($newPath) = ;
    &traverseMKDIR($path =~ m%(/.*/)[^/]+/%);

    mkdir $path;
  }elsif (!(-e $path)){
    mkdir $path;
  }

}


#
# Scan a directory recursively
#
sub scanDir($){

my $directory = shift;
#print STDERR 'Scanning dir '.$directory."\n";
opendir(IMD, $directory) || die("Cannot open directory");
my @dirContents = readdir(IMD);

#scan dirs
foreach my $item (@dirContents)
{
  my $fullPath = $directory . '/' . $item;
  #ignore . and ..
  if (-l $fullPath){

  }elsif (-d $fullPath and ($item eq '.' or $item eq '..') ){

  #item is a directory
  }elsif (-d $fullPath and ($item ne '.' and $item ne '..') ){
    &scanDir($fullPath);

  }else{
    print STDOUT 'file '. $fullPath."\n";
  }

}
closedir(IMD);
}


#
# Return a list of files in the directory provided (don't recursively scan / don't tranverse)
#
sub getFilesDir($){

my $directory = shift;
opendir(IMD, $directory) || die("Cannot open directory" . $directory);
my @dirContents = readdir(IMD);
my @fileList;
my $count=0;

#scan dirs
foreach my $item (@dirContents)
{
  my $fullPath = $directory . '/' . $item;
  #ignore . and ..
  if (-l $fullPath){

  }elsif (-d $fullPath and ($item eq '.' or $item eq '..') ){

  #item is a directory
  }elsif (-d $fullPath and ($item ne '.' and $item ne '..') ){
    $fileList[$count++] = $fullPath;
  }else{
    $fileList[$count++] = $fullPath;
  }

}
closedir(IMD);
return @fileList;
}

1;


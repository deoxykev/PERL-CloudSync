package pDrive::FileIO;

use strict;
use Digest::MD5;
use File::stat;

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
# mkdir 
# /dir1/dir2/dir3
####
sub traverseMKDIR($){

  my $path = shift;

  #strip filenames
  $path =~ s%[^/]+$%%;
print STDOUT "mkdir test path $path\n";
  if (!(-e $path) and ($path =~ m%/.*/[^/]+/%)){
#    my ($newPath) = ;
    traverseMKDIR($path =~ m%(/.*/)[^/]+/%);

    mkdir $path;
  }elsif (!(-e $path)){
    mkdir $path;
  }

}

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
    scanDir($fullPath);

  }else{
    print STDOUT 'file '. $fullPath."\n";
  }

}
closedir(IMD);
}

sub getFilesDir($){

my $directory = shift;
opendir(IMD, $directory) || die("Cannot open directory");
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

  }else{
    $fileList[$count++] = $fullPath;
  }

}
closedir(IMD);
return @fileList;
}

1;


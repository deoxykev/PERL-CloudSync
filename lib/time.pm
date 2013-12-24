package pDrive::Time;

use Time::Local;
use strict;

use constant A_DATE => 0;
use constant A_TIMESTAMP => 1;

sub getTimestamp($$){
  my ($Second, $Minute, $Hour, $Day, $Month, $Year) = gmtime(shift);
#  return sprintf("%4d%02d%02d%02d%02d%02d", $Year+1900, ++$Month, $Day, $Hour, $Minute, $Second);
  my $format = shift;

  if ($format eq 'YYYYMMDD'){
    return sprintf("%4d%02d%02d", $Year+1900, ++$Month, $Day);
  }elsif($format eq 'YYYYMMDDhh'){
    return sprintf("%4d%02d%02d%02d", $Year+1900, ++$Month, $Day, $Hour);
  }elsif($format eq 'YYYYMMDDhhmm'){
    return sprintf("%4d%02d%02d%02d%02d", $Year+1900, ++$Month, $Day, $Hour, $Minute);
  }else{
    return sprintf("%4d%02d%02d%02d%02d%02d", $Year+1900, ++$Month, $Day, $Hour, $Minute, $Second);
  }
}


sub getEPOC($){
  my ($Year, $Month, $Day, $Hour, $Minute, $Second) = shift =~ m%(^\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})%;
  return timegm($Second,$Minute,$Hour,$Day,$Month-1,$Year-1900);
}

sub getDateEPOC($$){
  my $EPOC = shift;
  my $offset = shift;

  my ($Second, $Minute, $Hour, $Day, $Month, $Year) = gmtime($EPOC+$offset);
  return sprintf("%4d-%02d-%02d", $Year+1900, ++$Month, $Day);

}

sub isNewerTimestamp($$){
  my $timestamp1 = shift;
  my $timestamp2 = shift;

  if ($timestamp1 > $timestamp2){
    return 1;
  }elsif ($timestamp1 < $timestamp2){
    return -1;
  }elsif ($timestamp1 eq '' or $timestamp2 eq ''){
    return -2;
  }else {
    return 0
  }

}

sub convertTimestampINT($){
  my $timestamp = shift;

  $timestamp =~ s/\D//g;
 
  return $timestamp;

}


1;

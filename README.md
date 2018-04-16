PERL-CloudSync
(previously known as PERL-pDrive)
=================================

A PERL implementation of Google Drive for cross-platform



FOR USAGE and help, see the WIKI -- https://github.com/ddurdle/PERL-CloudSync/wiki

Amazon Cloud Drive - RETIRED
-------------------------------

Amazon has closed down developer access.  Consider Amazon Cloud Drive DEAD and you should stop using it if you has respect to your data.

Google Drive API 2 -
-------------------------------

service accounts are supported
for service account support:
requires: JSON
to install JSON, two different methods:
 method 1)
  sudo cpan install JSON
  sudo cpan install JSON::WebToken
  sudo apt-get install libssl-dev
  sudo perl -MCPAN -e 'install Crypt::OpenSSL::RSA'
 or method 2)
  sudo apt-get install libjson-pp-perl
  sudo apt-get install libcrypt-openssl-rsa-perl
  sudo cpan install JSON::WebToken


for non-service account:
- no requirements

what works:
- OAUTH2 auhentication
- upload files
- create folders
- recurisively uploading all files in a folder supplied by user (in list or adhoc)
- constructing a memory hash of files using md5 and fisi against file id (for purposes of syncing)
- multiple accounts
- downloading all files
- downloading all owner files
- copy file from public or shared access to own account (using Google copy service)
- rename files

being worked on:
- track local files vs server files (dropbox sync ability)

Google Photos -
--------------------------
what works:
- OAUTH2 auhentication
- upload of pictures and video files (<1GB in size)
- recurisively uploading all files in a folder supplied by user (in list or adhoc)
- constructing a memory hash of files using md5 and fisi against file id (for purposes of syncing)
- multiple accounts

Hive.IM - RETIRED - end of life on service

One Drive API 1 - RETIRED - end of life on API

Google Docs API 3 - RETIRED - end of life on API

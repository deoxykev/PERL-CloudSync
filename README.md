PERL-CloudSync
(previously known as PERL-pDrive)
=================================

A PERL implementation of Google Drive for cross-platform


FOR USAGE and help, see the WIKI -- https://github.com/ddurdle/PERL-CloudSync/wiki

Amazon Cloud Drive -
-------------------------------

requires:
apt-get install libio-compress-perl
apt-get install aria2 [optional]

what works:
- OAUTH2 auhentication
- upload files
- create folders
- recurisively uploading all files in a folder supplied by user (in list or adhoc)
- constructing a memory hash of files using md5 and fisi against file id (for purposes of syncing)
- multiple accounts

being worked on:
- track local files vs server files (dropbox sync ability)


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

Hive.IM (retired)-
----------------
what works:
- email auhentication
- recurisively downloading of files files for a specified folder
- constructing a memory hash of files using fisi against file id (for purposes of syncing)
- multiple accounts

Amazon Cloud Drive -
--------------------------------
what works:
- OAUTH2 auhentication
- upload a single file (upload file x)
- multiple accounts

One Drive API 1:
-------------------------
what works:
- OAUTH2 auhentication
- upload files
- create folders
- recurisively uploading all files in a folder supplied by user (in list or adhoc)
- constructing a memory hash of files using sha5 and fisi against file id (for purposes of syncing)
- multiple accounts

being worked on:
- downloading all files
- downloading all owner files
- track local files vs server files (dropbox sync ability)


Google Docs API 3 (retired)-
-------------------------------
*obsolete, no longer being developed
what works:
- client login with username & password or username & application password
- downloading all files
- downloading all owner files
- upload files
- create folders, add files to folders, delete files from folders
- uploading all files in a folder supplied by user (in list or adhoc)
- track local files vs server files (dropbox sync ability)
- constructing a memory hash of files in local vs server copy


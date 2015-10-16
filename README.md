PERL-CloudSync
(previously known as PERL-pDrive)
=================================

A PERL implementation of Google Drive for cross-platform



Amazon Cloud Drive -
-------------------------------
requires:
apt-get install libio-compress-perl
apt-get install aria2

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
requires: JSON
apt-get install libjson-pp-perl
apt-get install libcrypt-openssl-rsa-perl
using cpan, install JSON::WebToken

what works:
- OAUTH2 auhentication
- upload files
- create folders
- recurisively uploading all files in a folder supplied by user (in list or adhoc)
- constructing a memory hash of files using md5 and fisi against file id (for purposes of syncing)
- multiple accounts
- downloading all files
- downloading all owner files

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

Hive.IM -
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


Google Docs API 3 -
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


PERL-CloudSync
(previously known as PERL-pDrive)
=================================

A PERL implementation of Google Drive for cross-platform

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

Google Drive API 2 -
-------------------------------
what works:
- OAUTH2 auhentication
- upload files
- create folders
- recurisively uploading all files in a folder supplied by user (in list or adhoc)
- constructing a memory hash of files using md5 and fisi against file id (for purposes of syncing)
- multiple accounts

being worked on:
- downloading all files
- downloading all owner files
- track local files vs server files (dropbox sync ability)

One Drive API 1:
-------------------------
what works:
- OAUTH2 auhentication
- upload files
- create folders
- recurisively uploading all files in a folder supplied by user (in list or adhoc)
- constructing a memory hash of files using md5 and fisi against file id (for purposes of syncing)
- multiple accounts

being worked on:
- downloading all files
- downloading all owner files
- track local files vs server files (dropbox sync ability)




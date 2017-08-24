package pDrive::BoxAPI2;

our @ISA = qw(pDrive::CloudServiceAPI);

use LWP::UserAgent;
use LWP;
use strict;
use IO::Handle;

use constant IS_ROOT => 1;
use constant NOT_ROOT => 0;

use constant FOLDER_TITLE => 0;
use constant FOLDER_ROOT => 1;
use constant FOLDER_PARENT => 2;
use constant FOLDER_SUBFOLDER => 3;

use constant API_URL => '1';
use constant API_VER => 1;

1;
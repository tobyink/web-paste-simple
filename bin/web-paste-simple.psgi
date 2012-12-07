#!/home/tai/perl5/perlbrew/perls/thr-5.16.0/bin/plackup

use lib '/home/tai/src/web/web-paste-simple/lib';
use Web::Paste::Simple;
Web::Paste::Simple->new->app;

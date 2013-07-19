#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;
use FindBin;
use lib "$FindBin::Bin/../lib";
use MessageQ;

#
# send a single command
#
my $m = MessageQ->new(user => 'worker', password => 'worker');

my $command = shift @ARGV or die 'no command given';
$m->delegate('render', 'de-DE.render', $command, { @ARGV } );

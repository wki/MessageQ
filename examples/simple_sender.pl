#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;
use FindBin;
use lib "$FindBin::Bin/../lib";
use MessageQ;

#
# send a single message
#
my $m = MessageQ->new(user => 'worker', password => 'worker');

$m->publish(render => {foo => 'bar', baz => 42, argv => \@ARGV});

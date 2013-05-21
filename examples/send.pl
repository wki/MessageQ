#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;
use FindBin;
use lib "$FindBin::Bin/../lib";
use MessageQ;

#
# send a single message to a given queue
#
my $m = MessageQ->new(user => 'worker', password => 'worker');

my $exchange    = shift @ARGV or die '1st argument must be EXCHANGE';
my $routing_key = shift @ARGV or die '2nd argument must be ROUTING.KEY';

$m->publish(
    $routing_key,
    { foo => 'bar', baz => 42, argv => \@ARGV },
    { exchange => $exchange }
);

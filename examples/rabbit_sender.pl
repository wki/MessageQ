#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Messager;

#
# send a single message
#
my $m = Messager->new(user => 'worker', password => 'worker');

$m->publish(proof => {foo => 'bar', baz => 42, argv => \@ARGV});

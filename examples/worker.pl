#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;
use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin";
use MessageQ::Worker;

my $worker = MessageQ::Worker->new(
    user        => 'worker',
    password    => 'worker',
    queue       => 'render',
    search_path => 'Command',
);

say 'Worker: waiting for commands...';
$worker->work;

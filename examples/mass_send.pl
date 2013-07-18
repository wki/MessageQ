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
my $exchange    = shift @ARGV or die '1st argument must be EXCHANGE';
my $routing_key = shift @ARGV or die '2nd argument must be ROUTING.KEY';

my $m = MessageQ->new(user => 'worker', password => 'worker');

my $size = 8192;
my $data = join '', map { chr(32 + rand(64)) } (1 .. $size * 1024);

for my $i (1 .. 100_000) {
    say $i if $i % 500 == 0;
    
    $m->publish(
        $exchange,
        $routing_key,
        { foo => 'bar', baz => 42, argv => $i, data => $data }
    );
}

__END__

Benchmark by message size:

  4K: 1000/s
 32K:  640/s
128K:  270/s
512K:   83/s
  2M:   24/s
  8M:    6/s


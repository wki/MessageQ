#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Messager;
use Data::Dumper;

my $m = Messager->new(user => 'worker', password => 'worker');

$m->consume('proof', { no_ack => 0 });

while (my $message = $m->recv) {
    say Data::Dumper->Dump([$message->data], ['received_data']);
    
    # if we had consume('proof', { no_ack => 0 }), we need:
    $message->ack;
}

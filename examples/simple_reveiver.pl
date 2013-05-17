#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;
use FindBin;
use lib "$FindBin::Bin/../lib";
use MessageQ;
use Data::Dumper;

#
# continuously receive messages.
#
my $m = MessageQ->new(user => 'worker', password => 'worker');

$m->consume('render', { no_ack => 0 });

while (my $message = $m->recv) {
    say Data::Dumper->Dump([$message->data], ['received_data']);
    
    # if we had consume('proof', { no_ack => 0 }), we need:
    $message->ack;
}

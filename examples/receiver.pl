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

my $queue = shift @ARGV // 'render';
$m->consume($queue, { no_ack => 0 });

say "[*] listening for messages on '$queue'...";

while (my $message = $m->re cv) {
    say Data::Dumper->Dump([$message->data], ['received_data']);

    # if we had consume('proof', { no_ack => 0 }), we need:
    $message->ack;
}

__END__

Alternative receiver:

use Data::Dumper;
use Net::Thumper;

my $m = Net::Thumper->new(server => "localhost", amqp_definition => "amqp0-9-1.xml");
$m->connect;
$m->open_channel();
my $c = $m->consume("render");
my $msg = $m->receive();

say Dumper $msg;

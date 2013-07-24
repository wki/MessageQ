use strict;
use warnings;
use Test::More;
use Test::Exception;

use ok 'MessageQ::Broker::HashStore';

my $h = MessageQ::Broker::HashStore->new;

$h->publish(thumbnail => { file => '/x.jpg' });
$h->publish(render => { file => '/x.tex' });
$h->publish('render:xxx' => { file => '/y.tex' });

is scalar keys %{$h->queue_for},
    2,
    '2 queues defined';

is $h->queue('thumbnail')->nr_messages,
    1,
    '1 thumbnail-operation in queue';
is $h->queue('render')->nr_messages,
    2,
    '2 render-operations in queue';

dies_ok { $h->receive('xxx') }
    'trying to receive "xxx" dies';
dies_ok { $h->receive('render') }
    'trying to receive "render" dies';

$h->consume('thumbnail');

my $m = $h->receive();
isa_ok $m, 'MessageQ::Broker::HashStoreMessage';

$m->reject;
is $h->queue('thumbnail')->nr_messages,
    1,
    '1 thumbnail-operation in queue after reject';

$m = $h->receive();
isa_ok $m, 'MessageQ::Broker::HashStoreMessage';

is_deeply $m->data,
    { file => '/x.jpg' },
    'data is the same as saved';

$m->reject;
is $h->queue('thumbnail')->nr_messages,
    1,
    '1 thumbnail-operation in queue after reject';

$m = $h->receive();
$m->ack;
is $h->queue('thumbnail')->nr_messages,
    0,
    'no thumbnail-operation in queue after ack';

done_testing;

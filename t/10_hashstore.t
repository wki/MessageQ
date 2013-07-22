use strict;
use warnings;
use Test::More;
use Test::Exception;

use ok 'MessageQ::Broker::HashStore';

note 'hashstorage usage cycle';
{
    my $h = MessageQ::Broker::HashStore->new;
    
    $h->publish(thumbnail => { file => '/x.jpg' });
    $h->publish(render => { file => '/x.tex' });
    $h->publish(render => { file => '/y.tex' });
    
    is scalar keys %{$h->messages_for_queue},
        2,
        '2 queues defined';
    
    is scalar @{$h->messages_for_queue->{thumbnail}},
        1,
        '1 thumbnail-operation in queue';
    is scalar @{$h->messages_for_queue->{render}},
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
    is scalar @{$h->messages_for_queue->{thumbnail}},
        1,
        '1 thumbnail-operation in queue after reject';
    
    $m = $h->receive();
    isa_ok $m, 'MessageQ::Broker::HashStoreMessage';
    
    is_deeply $m->data,
        { file => '/x.jpg' },
        'data is the same as saved';
    
    $m->ack;
    is scalar @{$h->messages_for_queue->{thumbnail}},
        1,
        '1 thumbnail-operation in queue after reject';
}

done_testing;

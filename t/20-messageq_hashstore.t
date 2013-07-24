use strict;
use warnings;
use MessageQ;
use Test::More;
use Test::Exception;

note 'load broker_class';
{
    dies_ok { MessageQ->new(broker_class => 'Dummy')->broker }
        'accessing a not-loadable broker class (Dummy) dies';
    
    my $m1 = MessageQ->new(broker_class => 'HashStore');
    isa_ok $m1->broker,
        'MessageQ::Broker::HashStore';
    
    my $m2 = MessageQ->new(broker_class => 'MessageQ::Broker::HashStore');
    isa_ok $m2->broker,
        'MessageQ::Broker::HashStore';
}

note 'publish/subscribe';
{
    my $m = MessageQ->new(broker_class => 'HashStore');
    
    $m->publish(do_this => {foo => 'bar', baz => 42});
    
    dies_ok { $m->receive }
        'trying to receive in non-consuming state dies';
    
    $m->consume('do_this');
    my $msg = $m->receive;
    is_deeply $msg->data,
        {foo => 'bar', baz => 42},
        'data received';
    $msg->ack;
    
    is $m->receive, undef, 'last message gives undef';
}

done_testing;
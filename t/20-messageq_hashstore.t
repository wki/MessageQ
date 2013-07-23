use strict;
use warnings;
use MessageQ;
use Test::More;
use Test::Exception;

note 'loading broker_class';
{
    dies_ok { MessageQ->new(broker_class => 'Dummy')->broker }
        'accessing a not-loadable broker class dies';
    
    my $m1 = MessageQ->new(broker_class => 'HashStore');
    isa_ok $m1->broker,
        'MessageQ::Broker::HashStore';
    
    my $m2 = MessageQ->new(broker_class => 'MessageQ::Broker::HashStore');
    isa_ok $m2->broker,
        'MessageQ::Broker::HashStore';
}


done_testing;
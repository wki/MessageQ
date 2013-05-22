package MessageQ::RabbitMQ;
use Moose;

extends 'Net::Thumper';

sub ack {
    my $self = shift;
    my $delivery_tag = shift;
    
    my $ack = Net::AMQP::Protocol::Basic::Ack->new(
        delivery_tag => $delivery_tag,
        multiple     => 0,
    );
    
    $self->_write_frame($ack);
}

__PACKAGE__->meta->make_immutable;
1;

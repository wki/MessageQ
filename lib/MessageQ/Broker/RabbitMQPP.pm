package MessageQ::Broker::RabbitMQPP;
use Moose;
use JSON::XS;
use Net::RabbitMQ::PP;
use namespace::autoclean;

extends 'MessageQ::Broker';

=head1 NAME

MessageQ::Broker::RabbitMQPP - a Net::RabitMQ::PP broker for MessageQ

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 ATTRIBUTES

=cut

has rabbitmq => (
    is  => 'ro',
    isa => 'Net::RabbitMQ::PP',
    lazy_build => 1,
);

sub _build_rabbitmq {
    my $self = shift;
    
    Net::RabbitMQ::PP->new(
        # Net::RabbitMQ::PP has meaningful defaults
        # host => 'localhost', ... not needed.
        $self->all_connect_options
    );
}

has channel => (
    is => 'ro',
    isa => 'Net::RabbitMQ::Channel',
    lazy_build => 1,
);

sub _build_channel {
    my $self = shift;
    
    $self->rabbitmq->channel(1)
}

=head1 METHODS

=cut

=head2 publish ( $destination, \%data )

publish a message onto a given exchange. Exchange is a RabbitMQ specific
term for the input side of a queue. The exchange name may consist of special
characters interpreted by the broker implementation.

C<$exchange> is divided into parts, the exchange name, a routing key and
a series of header values.

=cut

sub publish {
    my ($self, $destination, $data) = @_;
    
    my ($exchange, $routing_key, %header) = split ':', $destination;
    
    $self->channel->publish(
        exchange => $exchange,
        data     => encode_json($data),
        header   => \%header,
    );
}

=head2 consume ( $queue )

tell the queue that this process wants to consume it

=cut

sub consume {
    my ($self, $queue) = @_;
    
    $self->channel->consume(
        queue => $queue,
    );
}

=head2 receive

receive the next message from a consuming queue. Will block until a message
is present.

=cut

sub receive {
    my $self = shift;
    
    my $response = $self->channel->receive;
    
    return MessageQ::Broker::RabbitMQPP::Message->new(
        channel => $self->channel,
        data    => $response,
    );
}

=head2 has_message

tell if a message is present.

=cut

sub has_message {
    die 'not implemented';
    
    # does channel->get() work here?
}

__PACKAGE__->meta->make_immutable;
1;

=head1 AUTHOR

Wolfgang Kinkeldei, E<lt>wolfgang@kinkeldei.deE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

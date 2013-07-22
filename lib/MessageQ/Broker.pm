package MessageQ::Broker;
use Carp;
use Moose;
use namespace::autoclean;

=head1 NAME

MessageQ::Broker - an abstract Base class for a broker

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 ATTRIBUTES

=cut

has connect_options => (
    traits  => ['Hash'],
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { +{} },
    handles => {
        all_connect_options => 'elements',
    }
);

=head1 METHODS

=cut

=head2 connect

connect to the backend server

=cut

sub connect {
    # ignore this method call for convenience
    # croak 'abstract method "connect" not implemented';
}

=head2 disconnect

disconnect from the backend server

=cut

sub disconnect {
    # ignore this method call for convenience
    # croak 'abstract method "disconnect" not implemented';
}

=head2 publish ( $destination, \%data )

publish a message onto a given exchange. The destination name may consist of
special characters interpreted by the broker implementation.

RabbitMQ versions of brokers use the shape
C<exchange:routing.key:header:value> to split up the exchange from the routing
key at the colon.

=cut

sub publish {
    croak 'abstract method "publish" not implemented';
}

=head2 delegate ( $command, $destination, \%data )

construct a message from command and data and hand it over to the publish
method.

=cut

sub delegate {
    my ($self, $command, $destination, $data) = @_;
    
    $self->publish(
        $destination,
        {
            command => $command,
            data    => $data
        }
    );
}

=head2 consume ( $queue )

tell the queue that this process wants to consume it

=cut

sub consume {
    croak 'abstract method "consume" not implemented';
}

=head2 receive

receive the next message from a consuming queue. Will block until a message
is present.

=cut

sub receive {
    croak 'abstract method "consume" not implemented';
}

=head2 has_message

tell if a message is present.

=cut

sub has_message {
    croak 'abstract method "has_message" not implemented';
}

__PACKAGE__->meta->make_immutable;
1;

=head1 AUTHOR

Wolfgang Kinkeldei, E<lt>wolfgang@kinkeldei.deE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

package MessageQ::Broker::HashStoreMessage;
use Moose;
use namespace::autoclean;

extends 'MessageQ::Message';

=head1 NAME

MessageQ::Broker::RabbitMQPPMessage - a message for HashStore broker

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 ATTRIBUTES

=cut

=head1 METHODS

=cut

has queue => (
    is       => 'ro',
    isa      => 'MessageQ::Broker::HashStoreQueue',
    required => 1,
);

=head2 ack

mark a message as processed. Only possible if C<consume> is called with
option C<<< no_ack => 0 >>> set.

=cut

sub ack {
    my $self = shift;
    
    $self->queue->get_message;
}

=head2 reject

=cut

sub reject {
    # do nothing -- next request will re-read the message again
}

__PACKAGE__->meta->make_immutable;
1;

=head1 AUTHOR

Wolfgang Kinkeldei, E<lt>wolfgang@kinkeldei.deE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

package MessageQ::Broker::RabbitMQPPMessage;
use Moose;
use namespace::autoclean;

extends 'MessageQ::Message';

=head1 NAME

MessageQ::Broker::RabbitMQPPMessage - a message for RabbitMQPP broker

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 ATTRIBUTES

=cut

=head1 METHODS

=cut

### channel ?

=head2 ack

mark a message as processed. Only possible if C<consume> is called with
option C<<< no_ack => 0 >>> set.

=cut

sub ack {
    croak 'method "ack" not implemented'
}

=head2 reject

=cut

sub reject {
    croak 'method "reject" not implemented'
}

__PACKAGE__->meta->make_immutable;
1;

=head1 AUTHOR

Wolfgang Kinkeldei, E<lt>wolfgang@kinkeldei.deE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

package MessageQ::Message;
use 5.010;
use Moose;
use JSON::XS;
use namespace::autoclean;

=head1 NAME

MessageQ::Message - represents a message

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 ATTRIBUTES

=cut

has messager => (
    is       => 'ro',
    isa      => 'MessageQ',
    required => 1,
    handles  => [
        'broker',
        'channel_nr',
    ],
);

has raw_message => (
    is       => 'ro',
    isa      => 'Any',
    required => 1,
);

=head1 METHODS

=cut

=head2 data

give back the data of the message

=cut

sub data {
    my $self = shift;
    
    return decode_json($self->raw_message->{body});
}

=head2 ack

mark a message as processed. Only possible if C<consume> is called with
option C<<< no_ack => 0 >>> set.

=cut

sub ack {
    my $self = shift;
    
    $self->broker->ack(
        $self->channel_nr,
        $self->raw_message->{delivery_tag},
    );
}

=head2 reject

=cut

sub reject {
    my $self = shift;
    
    $self->broker->reject(
        $self->channel_nr,
        $self->raw_message->{delivery_tag},
    );
}

=head1 AUTHOR

Wolfgang Kinkeldei, E<lt>wolfgang@kinkeldei.deE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;
1;

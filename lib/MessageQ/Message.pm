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

has channel => (
    is       => 'ro',
    isa      => 'Object',
    required => 1,
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
    
    $self->raw_message->ack(@_);
}

### FIXME: is reject/return neccesary? or is one negative method sufficient?

=head2 reject

=cut

sub reject {
    my $self = shift;
    
    $self->raw_message->reject(@_);
}

=head2 return ( $error_text )

returns a message to an error queue

=cut

sub return ( $error_text ) {
    
}


=head1 AUTHOR

Wolfgang Kinkeldei, E<lt>wolfgang@kinkeldei.deE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;
1;

package Net::RabbitMQ::PP::Message;
use Moose;
use namespace::autoclean;

with 'Net::RabbitMQ::PP::Role::FrameIO';

### TODO: instead of frame_io: have a 'broker' attr, responding to all frame_io methods

has channel => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

has body => (
    is       => 'ro',
    isa      => 'Any',
    required => 1,
);

has delivery_tag => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has reply_to => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has correlation_id => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

=head2 ack

Ack a received message

=cut

sub ack {
    my $self = shift;
    my %args = @_;
    
    $self->write_frame(
        $self->channel,
        'Basic::Ack',
        multiple     => 0,
        delivery_tag => $self->delivery_tag,
        %args
    );
}

__PACKAGE__->meta->make_immutable;
1;

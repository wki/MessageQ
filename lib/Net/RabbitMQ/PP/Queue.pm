package Net::RabbitMQ::PP::Queue;
use Moose;
use Try::Tiny;
use namespace::autoclean;

with 'Net::RabbitMQ::PP::Role::FrameIO';

# TODO: does it make sense to have accessors for message-count, consumer-count

has name => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

=head2 declare

declare a queue

=cut

sub declare {
    my $self = shift;
    my %args = @_;
    
    $self->write_frame(
        0,
        'Queue::Declare',
        queue       => $self->name,
        durable     => 0,
        passive     => 0,
        exclusive   => 0, 
        auto_delete => 0, 
        no_wait     => 0,
        %args,
    );
    
    my $declare_ok = $self->read_frame(0, 'Queue::DeclareOk');
    # contains queue, message-count, consumer-count
}

=head2 bind

bind a queue to an exchange

=cut

sub bind {
    my $self = shift;
    my %args = @_;
    
    $self->write_frame(
        0,
        'Queue::Bind',
        queue       => $self->name,
        exchange    => '', # must be given as arg
        routing_key => '',
        no_wait     => 0,
        %args,
    );
    
    $self->read_frame(0, 'Queue::BindOk');
}

=head2 unbind

unbind a queue from an exchange

=cut

sub unbind {
    my $self = shift;
    my %args = @_;
    
    $self->write_frame(
        0,
        'Queue::Unbind',
        queue       => $self->name,
        exchange    => '', # must be given as arg
        routing_key => '',
        %args,
    );
    
    $self->read_frame(0, 'Queue::UnbindOk');
}

=head2 purge

remove all messages from the queue

=cut

sub purge {
    my $self = shift;
    my %args = @_;
    
    $self->write_frame(
        0,
        'Queue::Purge',
        queue   => $self->name,
        no_wait => 0,
        %args,
    );
    
    $self->read_frame(0, 'Queue::PurgeOk');
}

=head2 delete

deletes a queue

=cut

sub delete {
    my $self = shift;
    my %args = @_;
    
    $self->write_frame(
        0,
        'Queue::Delete',
        queue     => $self->name,
        if_unused => 0,
        if_empty  => 0,
        no_wait   => 0,
        %args,
    );
    
    $self->read_frame(0, 'Queue::DeleteOk');
}

__PACKAGE__->meta->make_immutable;
1;

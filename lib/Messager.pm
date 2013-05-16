package Messager;
use 5.010;
use Moose;
use JSON::XS;
use Sys::Hostname;
use Net::RabbitMQ;
use Messager::Message;
use namespace::autoclean;

=head1 NAME

Messager - simple message exchange using a RabbitMQ backend

=head1 SYNOPSIS

    # sender
    
    use Messager;
    
    my $m = Messager->new(
        host     => 'localhost',
        user     => 'worker',
        password => 'worker',
    );
    
    $m->publish(queue_name => { message => 'structure', with => 'info' });


    # reveiver:
    
    use Messager;
    
    my $m = Messager->new(
        host     => 'localhost',
        user     => 'worker',
        password => 'worker',
    );
    
    $m->consume('queue_name');
    
    while (my $message = $m->recv) {
        # so something with $message->data
    }

=head1 DESCRIPTION

=head1 ATTRIBUTES

=cut

has host => (
    is      => 'ro',
    isa     => 'Str',
    default => 'localhost',
);

has user => (
    is      => 'ro',
    isa     => 'Str',
    default => 'guest',
);

has password => (
    is      => 'ro',
    isa     => 'Str',
    default => 'guest',
);

has broker => (
    is         => 'ro',
    isa        => 'Net::RabbitMQ',
    lazy_build => 1,
);

sub _build_broker {
    my $self = shift;

    my $broker = Net::RabbitMQ->new;
    $broker->connect(
        $self->host,
        {
            user     => $self->user,
            password => $self->password,
        }
    );

    return $broker;
}

has channel_nr => (
    is         => 'ro',
    isa        => 'Int',
    lazy_build => 1,
    init_arg   => undef,
);

sub _build_channel_nr {
    my $self = shift;
    state $channel_nr = 0;

    ++$channel_nr;
    $self->broker->channel_open($channel_nr);

    return $channel_nr;
}

has _queues => (
    traits  => ['Hash'],
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { {} },
    handles => {
        has_queue => 'exists',
    }
);

=head1 METHODS

=cut

sub DEMOLISH {
    my $self = shift;

    $self->broker->disconnect;
}

=head2 publish ( $queue, { ... } )

publish a message (typically as hashref) onto a queue.

=cut

sub publish {
    my ($self, $queue_name, $data) = @_;

    $self->ensure_queue_exists($queue_name);

    $self->broker->publish(
        $self->channel_nr,
        $queue_name,
        encode_json($data)
    );
}

=head2 ensure_queue_exists ( $queue [, { options }] )

creates a queue if not yet existing

=cut

sub ensure_queue_exists {
    my $self = shift;
    my $queue_name = shift;
    my %options = (
        passive     => 0,
        durable     => 1,
        auto_delete => 1,
        exclusive   => 0,

        ref $_[0] eq 'HASH' ? %{$_[0]} : @_
    );

    return if $self->has_queue($queue_name);

    $self->broker->queue_declare(
        $self->channel_nr,
        $queue_name,
        \%options,
    );

    $self->_queues->{$queue_name} = 1;
}

=head2 consume ( $queue [, { options } ] )

start a consumer on the given queue. Valid options are:

=over

=item consumer_tag

=item no_local

=item no_ack

=item exclusive

=back

=cut

sub consume {
    my $self = shift;
    my $queue_name = shift;
    my %options = (
        consumer_tag => "${\hostname}_$$",
        no_local     => 0,
        no_ack       => 1,
        exclusive    => 0,

        ref $_[0] eq 'HASH' ? %{$_[0]} : @_
    );

    $self->ensure_queue_exists($queue_name);

    $self->broker->consume(
        $self->channel_nr,
        $queue_name,
        \%options
    );
}

=head2 recv ( $queue )

read one message from the given queue. Will block until a message is present,
returns C<undef> then server is down

=cut

sub recv {
    my $self = shift;

    my $raw_message = $self->broker->recv
        or return;

    return Messager::Message->new(
        messager    => $self,
        raw_message => $raw_message,
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

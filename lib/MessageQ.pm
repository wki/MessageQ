package MessageQ;
use 5.010;
use Moose;
use JSON::XS;
use Sys::Hostname;
use File::ShareDir ':ALL';
use Path::Class;
use Try::Tiny;
use Net::RabbitMQ::PP;
use MessageQ::Message;
use namespace::autoclean;

=head1 NAME

MessageQ - simple message exchange using a RabbitMQ backend

=head1 SYNOPSIS

    # sender
    
    use MessageQ;
    
    my $m = MessageQ->new(
        host     => 'localhost',
        user     => 'worker',
        password => 'worker',
    );
    
    $m->publish(queue_name => { message => 'structure', with => 'info' });


    # reveiver:
    
    use MessageQ;
    
    my $m = MessageQ->new(
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

has connect_options => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { +{} },
);

has broker => (
    is         => 'ro',
    isa        => 'Object',
    lazy_build => 1,
);

sub _build_broker {
    my $self = shift;

    my $broker = Net::RabbitMQ::PP->new($self->connect_options);
    $broker->connect;

    return $broker;
}

has channel => (
    is         => 'ro',
    isa        => 'Object',
    lazy_build => 1,
);

sub _build_channel {
    my $self = shift;
    
    return $self->broker->channel(1);
}

=head1 METHODS

=cut

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
    
    return $class->$orig(
        connect_options => ref $_[0] eq 'HASH' ? $_[0] : { @_ }
    );
};

sub DEMOLISH {
    my $self = shift;
    
    $self->broker->disconnect;
}

=head2 publish ( $exchange, $routing_key, \%data [ , \%options ] )

=cut

sub publish {
    my $self        = shift;
    my $exchange    = shift;
    my $routing_key = shift;
    my $data        = shift;
    my %options     = @_;

    $self->channel->publish(
        exchange => $exchange,
        routing_key => $routing_key,
        data => encode_json($data),
        %options
    );
}

=head2 delegate ( $exchange, $routing_key, $command, \%data )

publishes a command for getting executed by a client. The command is assumed
to be part of a package name for obtaining and instantiating an executable
object at the remote side.

=cut

sub delegate {
    my ($self, $exchange, $routing_key, $command, $data) = @_;
    
    $self->publish(
        $exchange, $routing_key,
        {
            command => $command,
            data    => $data,
        }
    );
}

# =head2 ensure_queue_exists ( $queue [, \%options ] )
# 
# creates a queue if not yet existing
# 
# =cut
# 
# sub ensure_queue_exists {
#     my $self = shift;
#     my $queue = shift;
#     my %options = (
#         passive     => 0,
#         durable     => 1,
#         auto_delete => 0,
#         exclusive   => 0,
# 
#         ref $_[0] eq 'HASH' ? %{$_[0]} : @_
#     );
# 
#     return if $self->has_queue($queue_name);
# 
#     $self->broker->queue_declare(
#         $self->channel_nr,
#         $queue_name,
#         \%options,
#     );
# 
#     $self->_queues->{$queue_name} = 1;
# }

=head2 consume ( $queue [, \%options ] )

start a consumer on the given queue. Valid options are:

=over

=item consumer_tag

=item no_local

=item no_ack

=item exclusive

=back

=cut

sub consume {
    my $self    = shift;
    my $queue   = shift;
    my %options = (
        consumer_tag => "${\hostname}_$$",
        no_local     => 0,
        no_ack       => 1,
        exclusive    => 0,

        ref $_[0] eq 'HASH' ? %{$_[0]} : @_
    );

    # $self->ensure_queue_exists($queue_name);

    $self->channel->consume(
        queue => $queue,
        %options
    );
}

=head2 receive ( $timeout )

read one message from the given queue. Will block until a message is present,
returns C<undef> then server is down

FIXME: timeout is currently ignored.

=cut

sub receive {
    my $self    = shift;
    my $timeout = shift // 0;

    my $raw_message = $self->channel->receive;
    
    if (!$raw_message) {
        warn 'receive: timeout reached...';
        return;
    }

    return MessageQ::Message->new(
        channel     => $self->channel,
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

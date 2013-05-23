package Net::RabbitMQ::PP;
use Moose;
use Net::RabbitMQ::PP::Network;
use Net::RabbitMQ::PP::FrameIO;
use Net::RabbitMQ::PP::Channel;
use Try::Tiny;
use namespace::autoclean;

=head1 NAME

Net::RabbitMQ::PP - a pure perl RabbitMQ binding

=head1 SYNOPSIS

    use Net::RabbitMQ::PP;
    
    my $broker = Net::RabbitMQ::PP->new;
    my $channel = $broker->open_channel(1);
    
    # TODO: work with exchanges
    my $exchange = $broker->exchange('xxx');
    #### MORE
    
    # TODO: work with queues
    my $queue = $broker->queue('xxx');
    #### MORE
    
    # a producer
    $channel->publish(
        exchange    => 'send_mail',
        routing_key => 'foo.bar',
        data        => 'Dear Reader, ...',
    );
    
    # a consumer
    $channel->consume(queue => 'send_mail', no_ack => 0);
    while (my $message = $channel->receive) {
        say 'received:', $message->body;
        
        $message->ack;
    }

=head1 DESCRIPTION

TODO: write something

=head1 ATTRIBUTES

=cut

=head1 ATTRIBUTES

=cut

has host => (
    is      => 'ro',
    isa     => 'Str',
    default => 'localhost',
);

has port => (
    is      => 'ro',
    isa     => 'Int',
    default => 5672,
);

has timeout => (
    is      => 'ro',
    isa     => 'Int',
    default => 0,
);

has virtual_host => (
    is      => 'ro',
    isa     => 'Str',
    default => '/',
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

has debug => (
    is      => 'ro',
    isa     => 'Int',
    default => 0,
);

has is_connected => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has network => (
    is         => 'ro',
    isa        => 'Net::RabbitMQ::PP::Network',
    lazy_build => 1,
);

sub _build_network {
    my $self = shift;
    
    return Net::RabbitMQ::PP::Network->new(
        host    => $self->host,
        port    => $self->port,
        timeout => $self->timeout,
        debug   => $self->debug,
    );
}

has frame_io => (
    is => 'ro',
    isa => 'Net::RabbitMQ::PP::FrameIO',
    lazy_build => 1,
    handles => {
        write_frame    => 'write',
        write_greeting => 'write_greeting',
        write_header   => 'write_header',
        write_body     => 'write_body',
        read_frame     => 'read',
        next_frame_is  => 'next_frame_is',
    }
);

sub _build_frame_io {
    my $self = shift;
    
    return Net::RabbitMQ::PP::FrameIO->new(
        network => $self->network,
        debug   => $self->debug,
    );
}

=head2 connect

connect with the RabbitMQ server

=cut

sub connect {
    my $self = shift;
    
    $self->write_greeting;

    $self->read_frame(0, 'Connection::Start');
    $self->write_frame(
        0, 'Connection::StartOk',
        client_properties => {
            platform    => 'Perl',
            product     => 'Net-RabbitMQ-PP',
            version     => '0.01',
        },
        mechanism => 'AMQPLAIN',
        response => {
            LOGIN    => $self->user,
            PASSWORD => $self->password,
        },
        locale => 'en_US',
    );

    my $tune_info = $self->read_frame(0, 'Connection::Tune');
    $self->write_frame(
        0, 'Connection::TuneOk',
        channel_max => $tune_info->method_frame->channel_max,
        frame_max   => $tune_info->method_frame->frame_max,
        heartbeat   => $tune_info->method_frame->heartbeat,
    );

    my $connection_open = $self->write_frame(
        0, 'Connection::Open',
        virtual_host => $self->virtual_host,
        capabilities => '',
        insist       => 1,
    );
    $self->read_frame(0, 'Connection::OpenOk');
    
    $self->is_connected(1);
}

=head2 ensure_connected

connect unless already done

=cut

sub ensure_connected {
    my $self = shift;
    
    $self->connect if !$self->is_connected;
}

before [qw(
    open_channel
)] => sub { $_[0]->ensure_connected };

=head2 disconnect

disconnect from the RabbitMQ server

=cut

sub disconnect {
    my $self = shift;
    
    try {
        $self->write_frame(0, 'Connection::Close');
        $self->read_frame(0, 'Connection::CloseOk');
    };
    
    $self->clear_frame_io;
    $self->clear_network;
    
    $self->is_connected(0);
}

=head2 open_channel ( $nr )

=cut

sub open_channel {
    my $self = shift;
    my $channel_nr = shift
        or die 'need channel nr to open';
    
    $self->write_frame($channel_nr, 'Channel::Open');
    $self->read_frame($channel_nr, 'Channel::OpenOk');
    
    return Net::RabbitMQ::PP::Channel->new(
        frame_io => $self->frame_io,
        channel  => $channel_nr,
    );
}

# - exchange('name') --> returns ::Exchange instance
# - queue('name') --> returns ::Queue instance

# - qos()
# - cancel()
# - return()
# - deliver()
# - reject()
# - recover()

__PACKAGE__->meta->make_immutable;
1;

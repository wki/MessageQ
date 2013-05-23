package Net::RabbitMQ::PP;
use Moose;
use Net::RabbitMQ::PP::Network;
use Net::RabbitMQ::PP::FrameIO;
use namespace::autoclean;

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

has vhost => (
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
    isa     => 'Bool',
    default => 0,
);

has is_connected => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has is_consuming => (
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

    $self->read_frame('Connection::Start');
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

    my $tune_info = $self->read_frame('Connection::Tune');
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
    $self->read_frame('Connection::OpenOk');
    
    $self->is_connected(1);
}

=head2 ensure_connected

connect unless already done

=cut

sub ensure_connected {
    my $self = shift;
    
    $self->connect if !$self->is_connected;
}

=head2 disconnect

disconnect from the RabbitMQ server

=cut

sub disconnect {
    my $self = shift;
    
    ### TODO: teardown
    
    $self->clear_frame_io;
    $self->clear_network;
    
    $self->is_connected(0);
    $self->is_consuming(0);
}


# - exchange('name') --> returns ::Exchange instance
# - queue('name') --> returns ::Queue instance

# - qos()
# - cancel()
# - return()
# - deliver()
# - reject()
# - recover()

=head2 publish ( [ $channel ], data => ..., fields => ..., header => { ... } )

publish a message

data must be a string, header fields are added to ContentHeader

=cut

sub publish {
    my $self = shift;
    my %args = @_;
    
    my $data   = delete $args{data}
        or die 'no data to publish';
    my $header = delete $args{header};
    
    $self->write_frame(
        'Basic::Publish',
        mandatory => 0,
        immediate => 0,
        ticket    => 0,
        %args,
    );
    
    $self->write_header(
        weight    => 0,
        body_size => length $data,
        header    => $header // {},
    );
    
    # We split the body into frames of 30000 characters.
    # TODO: this size should really be based on the max_frame_size set
    #  in the Tune/TuneOk frames during connection
    my @chunks = unpack '(a30000)*', $data;
    
    $self->write_body($_) for @chunks;
}

=head2 get ( queue => 'queue', ... )

Get a message from $queue. Return a hashref with the message details, or undef
if there is no message. This is essentially a poll of a given queue. %params is
an optional hash containing parameters to the Get request.

The message returned in a hashref with the following keys:

* body - the body of the message

* reply_to - the reply_to header of the message

* correlation_id - the correlation_id of the message

* delivery_tag - used in acking messages.

=cut

sub get {
    my $self = shift;
    my %args = @_;
        
    $self->write_frame(
        'Basic::Get',
        no_ack => 1,
        ticket => 0,
        %args,
    );
    
    return if $self->next_frame_is('Basic::GetEmpty');
    
    my $get_ok = $self->read_frame('Basic::GetOK')
        or return;
    
    return $self->_read_response;
}

sub _read_response {
    my $self = shift;
    
    ...
    
    # # solange lesen bis body length erreicht
    # my ($header, @bodies) = $self->_read_resp();
    # 
    # return $self->_create_resp($get_ok, $header, @bodies);
}

=head2 consume ( queue => 'queue', ... )

Indicate that a given queue should be consumed from. %params contains 
params to be passed to the Consume request.

Returns the consumer tag. Once the client is consuming from a queue,
receive() can be called to get any messages.

=cut

sub consume {
    my $self = shift;
    my %args = @_;
    
    $self->write_frame(
        'Basic::Consume',
        consumer_tag => '',
        no_local     => 0,
        no_ack       => 1,
        exclusive    => 0,
        ticket       => 0,
        nowait       => 0,
        %args,
    );
    my $consume_ok = $self->read_frame('Basic::ConsumeOk');

    $self->is_consuming(1);
    
    return $consume_ok->method_frame->{consumer_tag};
}

=head2 receive

Receive a message from a queue that has previously been consumed from.

The message returned is of the same format as that returned from get()

=cut

sub receive {
    my $self = shift;
    
    die 'receive called without consuming a queue'
        if !$self->is_consuming;

    return $self->_read_response;
}

__PACKAGE__->meta->make_immutable;
1;

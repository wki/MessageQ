package Net::RabbitMQ::PP::Channel;
use Moose;
use Data::Dumper;
use namespace::autoclean;

has frame_io => (
    is       => 'ro',
    isa      => 'Net::RabbitMQ::PP::FrameIO',
    required => 1,
    weak_ref => 1,
    handles  => {
        write_frame    => 'write',
        write_greeting => 'write_greeting',
        write_header   => 'write_header',
        write_body     => 'write_body',
        read_frame     => 'read',
        next_frame_is  => 'next_frame_is',
    }
);

has channel => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

has is_consuming => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

=head2 publish ( data => ..., fields => ..., header => { ... } )

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
        $self->channel,
        'Basic::Publish',
        mandatory => 0,
        immediate => 0,
        ticket    => 0,
        %args,
    );
    
    $self->write_header(
        $self->channel,
        weight    => 0,
        body_size => length $data,
        header    => $header // {},
    );
    
    # We split the body into frames of 30000 characters.
    # TODO: this size should really be based on the max_frame_size set
    #  in the Tune/TuneOk frames during connection
    my @chunks = unpack '(a30000)*', $data;
    
    $self->write_body($self->channel, $_) for @chunks;
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
    
    die 'not implemented';
    
    $self->write_frame(
        $self->channel,
        'Basic::Get',
        no_ack => 1,
        ticket => 0,
        %args,
    );
    
    return if $self->next_frame_is($self->channel, 'Basic::GetEmpty');
    
    my $get_ok = $self->read_frame($self->channel, 'Basic::GetOK')
        or return;
    
    return $self->_read_response;
}

sub _read_response {
    my $self = shift;
    
    my $deliver = $self->read_frame($self->channel, 'Basic::Deliver');
    print 'DELIVER:', Dumper $deliver;
    my $header  = $self->read_frame($self->channel, 'Frame::Header');
    print 'HEADER:', Dumper $header;
    
    my $body = '';
    while (length $body < $header->body_size) {
        my $frame = $self->read_frame($self->channel, 'Frame::Body');
        print Dumper $frame;
        
        $body .= $frame->payload;
    }
    
    return {
        body           => $body,
        delivery_tag   => $deliver->method_frame->delivery_tag,
        reply_to       => $header->header_frame->headers->{reply_to},
        correlation_id => $header->header_frame->headers->{correlation_id},
    };
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
        $self->channel,
        'Basic::Consume',
        consumer_tag => '',
        no_local     => 0,
        no_ack       => 1,
        exclusive    => 0,
        ticket       => 0,
        nowait       => 0,
        %args,
    );
    my $consume_ok = $self->read_frame($self->channel, 'Basic::ConsumeOk');

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

=head2 ack

Ack a received message

=cut

sub ack {
    my $self = shift;
    my %args = @_;
    
    $self->write_frame(
        $self->channel,
        'Basic::Ack',
        multiple => 0,
        %args
    );
}

__PACKAGE__->meta->make_immutable;
1;

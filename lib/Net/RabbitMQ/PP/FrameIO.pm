package Net::RabbitMQ::PP::FrameIO;
use 5.010;
use Moose;
use Net::AMQP;
use Net::RabbitMQ::PP::Network;
use File::ShareDir ':ALL';
use Path::Class;
use Try::Tiny;
use Data::Dumper;
use namespace::autoclean;

### must have amqp_definition

has network => (
    is       => 'ro',
    isa      => 'Net::RabbitMQ::PP::Network',
    required => 1,
);

has debug => (
    is      => 'ro',
    isa     => 'Int',
    default => 0,
);

has _pre_read_data => (
    is      => 'rw',
    isa     => 'Str',
    default => '',
);

### FIXME: conceptionally wrong. read frames are associated to a channel.
has _cached_frames => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { +{} },
);

sub cache_frame {
    my $self    = shift;
    my $channel = shift;
    
    push @{$self->_cached_frames->{$channel}}, @_;
}

sub has_cached_frames {
    my $self    = shift;
    my $channel = shift;
    
    return scalar @{$self->_cached_frames->{$channel} //= []};
}

sub get_cached_frame {
    my $self    = shift;
    my $channel = shift;
    
    return shift @{$self->_cached_frames->{$channel}};
}

sub BUILD {
    my $self = shift;
    state $spec_loaded = 0;

    if (!$spec_loaded) {
        my $dist_dir;
        try {
            $dist_dir = dir(dist_dir('MessageQ'));
        } catch {
            $dist_dir = file(__FILE__)->absolute->resolve->dir->parent->parent->parent->parent->subdir('share');
        };

        my $spec_file = $dist_dir->file('amqp0-9-1.xml');
        my $spec = scalar $spec_file->slurp; # ??? (iomode => '<:encoding(UTF-8)')

        Net::AMQP::Protocol->load_xml_spec(undef, \$spec);

        $spec_loaded++;
    }
}

sub print_debug {
    my $self = shift;
    my $level = shift;

    say @_ if $self->debug >= $level;
}

=head2 write ( $channel, $frame_type [, %args ] )

construct and write a frame

    # FIXME: is channel.declare allowed ???
    # FIXME: do we rewrite no_ack => 1 to 'no-ack' => 1 ???
    #
    $xxx->write('Channel::Declare', ...)

=cut

sub write {
    my $self       = shift;
    my $channel    = shift;
    my $frame_type = shift;

    my $frame = "Net::AMQP::Protocol::$frame_type"->new(@_);

    # what is the meaning of this?
    if ($frame->isa('Net::AMQP::Protocol::Base')) {
        $frame = $frame->frame_wrap;
    }

    $frame->channel($channel);
    $self->_write_frame($frame);
}

sub _write_frame {
    my $self  = shift;
    my $frame = shift;

    $self->print_debug(1, 'Writing Frame:',
        $frame->can('method_frame')
            ? ref $frame->method_frame
            : ref $frame
        );
    $self->print_debug(2, 'Frame:', Dumper $frame);
    $self->network->write($frame->to_raw_frame);
}

=head2 write_greeting

writes a greeting frame for the start of a connection

=cut

sub write_greeting {
    my $self = shift;

    $self->network->write(Net::AMQP::Protocol->header);
}

=head2 write_header ( $channel, $frame)

write a header frame

=cut

sub write_header {
    my $self    = shift;
    my $channel = shift;
    my %args    = @_;

    my $body_size = delete $args{body_size} // 0;
    
    my $header = Net::AMQP::Frame::Header->new(
        weight       => 0,
        body_size    => $body_size,
        header_frame => Net::AMQP::Protocol::Basic::ContentHeader->new(
            content_type     => 'application/octet-stream',
            content_encoding => undef,
            headers          => {},
            delivery_mode    => 1,
            priority         => 1,
            correlation_id   => undef,
            expiration       => undef,
            message_id       => undef,
            timestamp        => time,
            type             => undef,
            user_id          => undef,
            app_id           => undef,
            cluster_id       => undef,
            %{$args{header}},
        ),
    );

    $header->channel($channel);
    $self->_write_frame($header);
}

=head2 write_body

write a body frame with some payload

=cut

sub write_body {
    my $self    = shift;
    my $channel = shift;
    my $payload = shift;

    my $body = Net::AMQP::Frame::Body->new(payload => $payload);
    $body->channel($channel);
    $self->_write_frame($body);
}

=head2 read ( $channel [ , $expected_frame_type ] )

read a frame optionally expecting a certain type

=cut

sub read {
    my $self                = shift;
    my $channel             = shift;
    my $expected_frame_type = shift;

    $self->_read_frames_into_cache($channel);

    my $frame = $self->get_cached_frame($channel)
        or die "Could not read a frame - cache ($channel) is empty";

    if ($expected_frame_type) {
        if (!$self->frame_is($frame, $expected_frame_type)) {
            my $got = $frame->can('method_frame')
                ? $frame->method_frame
                : ref $frame;
            die "Expected '$expected_frame_type' but got '$got'";
        }
    }

    return $frame;
}

sub _read_frames_into_cache {
    my $self    = shift;
    my $channel = shift;

    return if $self->has_cached_frames($channel);

    my $data = $self->_read_data;
    my @frames = Net::AMQP->parse_raw_frames(\$data);

    foreach my $frame (@frames) {
        $self->print_debug(1, "Caching Frame (${\$frame->channel}):",
            $frame->can('method_frame')
                ? ref $frame->method_frame
                : ref $frame
        );
        $self->print_debug(2, "Frame:", Dumper $frame);
    }

    $self->cache_frame($_->channel, $_) for @frames;
}

=head2 next_frame_is

checks next frame against a type and returns a boolean reflecting the type check

=cut

sub next_frame_is {
    my $self = shift;
    my $channel = shift;
    my $expected_frame_type = shift
        or return 1;

    $self->_read_frames_into_cache($channel);

    return 0 if !$self->has_cached_frames($channel);

    return $self->frame_is($self->_cached_frames->{$channel}->[0], $expected_frame_type);
}

sub frame_is {
    my $self = shift;
    my $frame = shift;
    my $expected_frame_type = shift
        or return 1;

    my $got = $frame->can('method_frame')
        ? ref $frame->method_frame
        : ref $frame;

    $self->print_debug(2, "testing '$got' against '$expected_frame_type'...");

    return $got =~ m{\Q$expected_frame_type\E \z}xms;
}

# unused
# sub _assert_frame_is {
#     my $self = shift;
#     my $frame = shift;
#     my $expected_class = shift;
#
#     die "Expected $expected_class but got a non-blessed scalar!\nFrame Dump:" . Dumper $frame
#         unless blessed $frame;
#
#     if (! $frame->can('method_frame')) {
#         die "Exepected $expected_class, but got " . ref($frame) . "\nFrame Dump:" . Dumper $frame;
#     }
#
#     if (! $frame->method_frame->isa($expected_class)) {
#         if (! $frame->method_frame->can('reply_text')) {
#             die "Exepected $expected_class, but got " . ref($frame->method_frame) . "\nFrame Dump:" . Dumper $frame;
#         }
#         die $frame->method_frame->reply_text . "\n";
#     }
# }

# unused
# sub _read_frame {
#     my $self = shift;
#
#     my $data = $self->_read_data($timeout);
#
#     return unless $data;
#
#     my @frames = Net::AMQP->parse_raw_frames(\$data);
#
#     # # $self->_debug("Read frames: " . Dumper \@frames);
#     # # $self->_debug("Raw data: $data") if ! @frames;
#     #
#     # @frames = $self->_strip_receive_frames($timeout, $expecting_receive, @frames);
#     #
#     # if (length($data) > 0 && ! @frames) {
#     #     die "Read " . length($data) . " bytes of data, but it contained no parsable frames\n";
#     # }
#     #
#     # return @frames;
# }

# Strip out any receive frames, and add them to the cache
# sub _strip_receive_frames {
#     my $self = shift;
#     my $timeout = shift;
#     my $expecting_receive = shift;
#     my $frame = shift;
#
#     # Only do something if we're consuming
#     return $frame unless $self->{consuming};
#
#     my @messages;
#
#     my @other_frames;
#
#     while (1) {
#         my $deliver = $frame;
#
#         try {
#             $self->_assert_frame_is($deliver, 'Net::AMQP::Protocol::Basic::Deliver');
#         }
#         catch {
#             undef $deliver;
#         };
#
#         last unless $deliver;
#
#         my ($header, @bodies) = $self->_read_resp();
#
#         push @messages, {
#             deliver => $deliver,
#             header => $header,
#             bodies => \@bodies
#         };
#
#         # See if there's a new frame to read, unless we were
#         #  expecting a receive, in which case there may not be anything
#         #  more.
#         if ($expecting_receive) {
#             last;
#         }
#         else {
#             ($frame) = $self->_read_frames($timeout);
#         }
#     }
#
#     $self->receive_cache_push(@messages);
#
#     return $frame;
# }


# read raw data, keep superfluous data in _pre_read_data,
# return data for one frame
sub _read_data {
    my $self = shift;

    my $data = $self->_pre_read_data;

    # If we have less than 7 bytes of data, we need to read more so we at least get the header
    if (length $data < 7) {
        $data .= $self->network->read(1024) // '';
    }

    # Read header
    my $header = substr $data, 0, 7, '';

    return unless $header;

    my ($type_id, $channel, $size) = unpack 'CnN', $header;

    # Read body
    my $body = substr $data, 0, $size, '';

    # If we haven't got the full body and the footer, we have more to read
    if (length $body < $size || length $data == 0) {
        # Add 1 to the size to make sure we get the footer
        my $size_remaining = $size+1 - length $body;

        while ($size_remaining > 0) {
            my $chunk = $self->network->read($size_remaining);

            $size_remaining -= length $chunk;
            $data .= $chunk;
        }

        $body .= substr($data, 0, $size-length($body), '');
    }

    # Read footer
    my $footer = substr $data, 0, 1, '';
    my $footer_octet = unpack 'C', $footer;

    die "Invalid footer: $footer_octet\n" unless $footer_octet == 206;

    $self->_pre_read_data($data);

    return $header . $body . $footer;
}

__PACKAGE__->meta->make_immutable;
1;

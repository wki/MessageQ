use strict;
use warnings;
use Test::More;

use ok 'Net::RabbitMQ::PP::FrameIO';

note 'raw packet input';
{
    my $f = frameio();
    
    is length $f->_pre_read_data, 0, 'no preread data before read';
    
    is $f->_read_data, undef, 'undef read from empty buffer';
    
    my $packet = packet(2,'Net::AMQP::Protocol::Channel::Open');
    $TestNetwork::read_buffer = "$packet.ABC";

    my $p = $f->_read_data;
    is length $p, length $packet, 'full packet is read as raw data';
    
    is length $f->_pre_read_data, 4, '4 bytes pre read';
    is length $TestNetwork::read_buffer, 0, 'read buffer is empty';
}

note 'packet decoding';
{
    my $f = frameio();
    
    my $packet1 = packet(11,'Net::AMQP::Protocol::Channel::Open');
    my $packet2 = packet(42,'Net::AMQP::Protocol::Channel::OpenOk');
    
    $TestNetwork::read_buffer = $packet1. $packet2;
    
    ok !scalar keys %{$f->_cached_frames_for_channel}, 'no frames in cache';
    $f->_read_frames_into_cache;
    
    is join(' ', grep { length $_ } sort keys %{$f->_cached_frames_for_channel}),
       '11',
       'cached frames exist for first read frame';
}

# diagnostics:
# print ord . ' ' for split //, packet(42, 'Net::AMQP::Protocol::Channel::OpenOk');

done_testing;

sub frameio {
    $TestNetwork::read_buffer = $TestNetwork::write_buffer = '';
    
    return Net::RabbitMQ::PP::FrameIO->new(network => TestNetwork->new);
}

# construct a raw Net::AMQP::Protocol::Xxx::Yyy packet as string
sub packet {
    my $channel = shift;
    my $type = shift;
    
    my $frame = $type->new(@_)->frame_wrap;
    $frame->channel($channel);
    
    return $frame->to_raw_frame;
}

{
    package TestNetwork;
    use Moose;
    
    our $read_buffer;
    our $write_buffer;
    
    sub BUILD {
        $read_buffer = $write_buffer = '';
    }
    
    sub write {
        my $self = shift;
        my $data = shift;
        
        $write_buffer .= $data;
    }
    
    sub read {
        my $self      = shift;
        my $read_size = shift
            or die 'test-network-read: read_size required';
    
        return substr($read_buffer, 0, $read_size, '');
    }
}

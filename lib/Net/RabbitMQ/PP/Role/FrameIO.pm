package Net::RabbitMQ::PP::Role::FrameIO;
use Moose::Role;

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

no Moose::Role;
1;

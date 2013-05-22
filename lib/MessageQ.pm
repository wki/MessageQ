package MessageQ;
use 5.010;
use Moose;
use JSON::XS;
use Sys::Hostname;
use File::ShareDir ':ALL';
use Path::Class;
use Try::Tiny;
use MessageQ::RabbitMQ;
use MessageQ::Message;
use namespace::autoclean;

with 'MessageQ::Role::LoginAttributes';

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

has amqp_definition => (
    is         => 'ro',
    isa        => 'Str',
    lazy_build => 1,
);

sub _build_amqp_definition {
    my $self;
    
    my $dist_dir;
    try {
        $dist_dir = dir(dist_dir('MessageQ'));
    } catch {
        $dist_dir = file(__FILE__)->absolute->dir->parent->subdir('share');
    };
    
    # warn "DIST dir = '$dist_dir'";
    
    return $dist_dir->file('amqp0-9-1.xml')->stringify;
}

has broker => (
    is         => 'ro',
    isa        => 'Object',
    lazy_build => 1,
);

sub _build_broker {
    my $self = shift;

    my $broker = MessageQ::RabbitMQ->new(
        server          => $self->host,
        amqp_definition => $self->amqp_definition,
      # debug           => 1,
    );
    
    $broker->connect(
        login    => $self->user,
        password => $self->password,
    );
    
    $broker->open_channel;

    return $broker;
}

# has channel_nr => (
#     is         => 'ro',
#     isa        => 'Int',
#     lazy_build => 1,
#     init_arg   => undef,
# );
# 
# sub _build_channel_nr {
#     my $self = shift;
#     state $channel_nr = 0;
# 
#     ++$channel_nr;
#     $self->broker->channel_open($channel_nr);
# 
#     return $channel_nr;
# }

# has _queues => (
#     traits  => ['Hash'],
#     is      => 'ro',
#     isa     => 'HashRef',
#     default => sub { {} },
#     handles => {
#         has_queue => 'exists',
#     }
# );

=head1 METHODS

=cut

sub DEMOLISH {
    my $self = shift;
    
    $self->broker->disconnect;
}

=head2 publish ( $exchange, $routing_key, \%data [ , \%options [ , \%props ] ] )

=cut

sub publish {
    my $self        = shift;
    my $exchange    = shift;
    my $routing_key = shift;
    my $data        = shift;
    my $options     = shift // {};
    my $props       = shift // {};

    $self->broker->publish(
        $exchange,
        $routing_key,
        encode_json($data),
        $options, $props
    );
}

# =head2 delegate ( $queue_name, $command, \%data )
# 
# publishes a command for getting executed by a client. The command is assumed
# to be part of a package name for obtaining and instantiating an executable
# object at the remote side.
# 
# =cut
# 
# sub delegate {
#     my ($self, $queue_name, $command, $data) = @_;
#     
#     $self->publish(
#         $queue_name,
#         {
#             command => $command,
#             data    => $data,
#         }
#     );
# }

# =head2 ensure_queue_exists ( $queue [, \%options ] )
# 
# creates a queue if not yet existing
# 
# =cut
# 
# sub ensure_queue_exists {
#     my $self = shift;
#     my $queue_name = shift;
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
    my $self = shift;
    my $queue_name = shift;
    my %options = (
        consumer_tag => "${\hostname}_$$",
        no_local     => 0,
        no_ack       => 1,
        exclusive    => 0,

        ref $_[0] eq 'HASH' ? %{$_[0]} : @_
    );

    # $self->ensure_queue_exists($queue_name);

    $self->broker->consume(
        $queue_name,
        %options
    );
}

=head2 receive ( $timeout )

read one message from the given queue. Will block until a message is present,
returns C<undef> then server is down

=cut

sub receive {
    my $self = shift;
    my $timeout = shift // 0;

    my $raw_message = $self->broker->receive($timeout);
    
    if (!$raw_message) {
        warn 'receive: timeout reached...';
        return;
    }

    return MessageQ::Message->new(
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

package MessageQ;
use Moose;
use Module::Load;
use Try::Tiny;
use namespace::autoclean;

=head1 NAME

MessageQ - simple message exchange using a RabbitMQ backend

=head1 SYNOPSIS

    # sender
    
    use MessageQ;
    
    my $m = MessageQ->new(
        connect_options => {
            host     => 'localhost',
            user     => 'worker',
            password => 'worker',
        },
        broker_class => 'RabbitMQPP', # means: MessageQ::Broker::RabbitMQPP
    );
    
    $m->publish(destination => { message => 'structure', with => 'info' });
    
    # additional info (RabbitMQ: routing key) appended to queue name
    $m->publish('render:proof.de_DE' => { ... });


    # reveiver:
    
    use MessageQ;
    
    my $m = MessageQ->new(
        connect_options => {
            host     => 'localhost',
            user     => 'worker',
            password => 'worker',
        },
    );
    
    $m->consume('queue_name');
    
    while (my $message = $m->receive) {
        # do something with $message->data
        
        $message->ack; # or $message->reject;
    }
    
    # if we reach this point the connection got torn down

=head1 DESCRIPTION

=head1 ATTRIBUTES

=cut

has connect_options => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { +{} },
);

has broker_class => (
    is      => 'ro',
    isa     => 'Str',
    default => 'MessageQ::Broker::RabbitMQPP',
);

has broker => (
    is         => 'ro',
    isa        => 'Object',
    lazy_build => 1,
    handles    => [qw(
        connect disconnect
        publish delegate 
        consume receive has_message
    )],
);

sub _build_broker {
    my $self = shift;
    
    my $c = $self->broker_class;
    my $broker;
    
    foreach my $class ($c, "MessageQ::Broker::$c") {
        try {
            load $class;
            $broker = $class->new($self->connect_options);
            $broker->connect;
        } catch {
            undef $broker;
        };
        
        return $broker if $broker;
    }
    
    die "Could not find requested broker '$c'";
}

=head1 METHODS

=cut

sub DEMOLISH {
    my $self = shift;
    
    $self->disconnect if $self->has_broker;
}

=head1 AUTHOR

Wolfgang Kinkeldei, E<lt>wolfgang@kinkeldei.deE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;
1;

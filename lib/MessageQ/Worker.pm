package MessageQ::Worker;
use 5.010;
use Moose;
use MessageQ;
use Try::Tiny;
use namespace::autoclean;

with 'MessageQ::Role::LoginAttributes';

=head1 NAME

MessageQ::Worker - a worker handling delegated messages

=head1 SYNOPSIS

    use MessageQ::Worker;

    my $w = MessageQ::Worker->new(
        user        => 'worker',
        password    => 'worker,
        queue       => 'image',
        search_path => 'My::Worker',
    );

    $w->work;

=head1 DESCRIPTION

=head1 ATTRIBUTES

=cut

=head2 mq

an instance to a MessageQ object which got constructed from the given
C<user>, C<password> and optionally C<host> attributes.

=cut

has mq => (
    is         => 'ro',
    isa        => 'MessageQ',
    lazy_build => 1,
);

sub _build_mq {
    my $self = shift;

    return MessageQ->new(
        host     => $self->host,
        user     => $self->user,
        password => $self->password,
    );
}

=head2 search_path

the packge search path to locate given commands as packages in

=cut

has search_path => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

=head2 queue

the queue to listen to

=cut

has queue => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

=head1 METHODS

=cut

=head2 work

start a loop waiting and processing messages.

=cut

sub work {
    my $self = shift;

    $self->mq->consume($self->queue, { no_ack => 0 });

    while (my $message = $self->mq->recv) {
        my $data = $message->data;

        try {
            say "execute $data->{command}";
            $self->execute_work_child_process($data->{command}, $data->{data});
            $message->ack;
        } catch {
            warn "job died: $data->{command} ($_)";
            $message->reject;
        };
    }
}

=head2 execute_work_child_process ( $class, \%data )

executes a freshly constructed object of the given class with some data
in a new process

=cut

sub execute_work_child_process {
    my ($self, $class, $data) = @_;

    my $pid = fork;
    if (!$pid) {
        my $package = "${\$self->search_path}::$class";
        
        # very poor man's serialization.
        my $args = join ',', map { s{"}{\\"}xmsg; qq{"$_"} } %$data;
        
        # close STDERR;
        
        exec $^X,
            (map { "-I$_" } @INC),
            "-M$package",
            '-E', "$package->new($args)->process"
            ;
        exit 1;
    }
    
    waitpid $pid, 0;
    die "child process died with status: ${\($? >> 8)}" if $?;
}


__PACKAGE__->meta->make_immutable;
1;

=head1 AUTHOR

Wolfgang Kinkeldei, E<lt>wolfgang@kinkeldei.deE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

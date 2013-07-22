package MessageQ::Broker::HashStoreQueue;
use Moose;
use namespace::autoclean;

=head1 NAME

MessageQ::Broker::HashStoreQueue - a simple queue implementation for HashStore

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 ATTRIBUTES

=cut

=head1 ATTRIBUTES

=cut

has messages => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
    handles => {
        has_messages => 'count',
        is_empty     => 'is_empty',
        add_message  => 'push',
        get_message  => 'shift',
    }
);

__PACKAGE__->meta->make_immutable;
1;

=head1 AUTHOR

Wolfgang Kinkeldei, E<lt>wolfgang@kinkeldei.deE<gt>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

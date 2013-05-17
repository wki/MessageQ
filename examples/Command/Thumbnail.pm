package Command::Thumbnail;
use 5.010;
use Moose;

has file => (
    is  => 'ro',
    isa => 'Str',
);

sub process {
    my $self = shift;
    
    say "Thumbnail: FILE = ${\$self->file}";
}

__PACKAGE__->meta->make_immutable;
1;

package Command::Thumbnail;
use 5.010;
use Moose;

has file => (
    is  => 'ro',
    isa => 'Str',
);

sub process {
    my $self = shift;
    
    say "Thumbnail: PID=$$, FILE='${\$self->file}'";
    
    die 'stop for testing';
}

__PACKAGE__->meta->make_immutable;
1;

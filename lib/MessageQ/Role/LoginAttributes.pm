package MessageQ::Role::LoginAttributes;
use Moose::Role;

has host => (
    is      => 'ro',
    isa     => 'Str',
    default => 'localhost',
);

has user => (
    is      => 'ro',
    isa     => 'Str',
    default => 'guest',
);

has password => (
    is      => 'ro',
    isa     => 'Str',
    default => 'guest',
);

no Moose::Role;
1;

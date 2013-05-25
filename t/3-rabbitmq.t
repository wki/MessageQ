use strict;
use warnings;
use Test::More;

our $VHOST = "test_$$";

# test against a test-<<PID>> vhost of a running rabbitmq instance
# needs an entry in /etc/sudoers to allow switching to rabbitmq-user

# this mit be executable:
# sudo -k ; sudo -H -n -u rabbitmq rabbitmqctl list_vhosts

if (!user_can_switch_to_rabbitmq()) {
    plan skip_all => 'cannot become rabbitmq user via su without password, test impossible';
}

add_vhost();



# delete_vhost();

ok 1==1;

done_testing;

sub user_can_switch_to_rabbitmq {
    system 'sudo -k 2>/dev/null';
    system 'sudo -Hnu rabbitmq true 2>/dev/null';
    
    return $? == 0;
}

sub delete_vhost {
    rabbitmqctl("delete_user $VHOST");
    rabbitmqctl("delete_vhost $VHOST");
}

sub add_vhost {
    delete_vhost();
    rabbitmqctl("add_vhost $VHOST");
    rabbitmqctl("add_user $VHOST $VHOST");
    rabbitmqctl("set_permissions -p $VHOST $VHOST '.*' '.*' '.*'")
}

sub rabbitmqctl {
    my $command = shift;
    
    system "sudo -Hnu rabbitmq rabbitmqctl $command >/dev/null 2>/dev/null";
}

use strict;
use warnings;
use Test::More;

use ok 'Net::RabbitMQ::PP';

our $VHOST = "test_$$";

# test against a test-<<PID>> vhost of a running rabbitmq instance
# needs an entry in /etc/sudoers to allow switching to rabbitmq-user

# this mit be executable:
# sudo -k ; sudo -H -n -u rabbitmq rabbitmqctl list_vhosts

if (!user_can_switch_to_rabbitmq()) {
    plan skip_all => 'cannot become rabbitmq user via su without password, test impossible';
}

note "Adding vhost $VHOST";
add_vhost();

my $broker = Net::RabbitMQ::PP->new(virtual_host => $VHOST, debug => 0);

note 'channel handling';
{
    my $c27_1 = $broker->channel(27);
    my $c27_2 = $broker->channel(27);
    
    is $c27_1, $c27_2, 'successive channel() calls yield the same object';
    is $c27_1->channel_nr, 27, 'channel_nr reported right';
    is $c27_1->broker, $broker, 'broker reported right';
}

note 'declaring exchange thumbnail';
my $exchange = $broker->exchange('thumbnail');
$exchange->declare(type => 'topic');

note 'declaring queue render';
my $queue = $broker->queue('render');
$queue->declare;
$queue->bind(exchange => 'thumbnail', routing_key => '#.render');

note 'message handling';
{
    my $channel = $broker->channel(42);
    
    is $channel->get(queue => 'render'), undef, 'get returns undef if queue is empty';

    $channel->publish(data => 'foo42', exchange => 'thumbnail', routing_key => 'bar.render');
    
    my $message = $channel->get(queue => 'render');
    isa_ok $message, 'Net::RabbitMQ::PP::Message';
    is $message->body, 'foo42', 'sent data is returned';
    
    $message->ack;
}

done_testing;

END { delete_vhost() }

sub user_can_switch_to_rabbitmq {
    system 'sudo -k 2>/dev/null';
    system 'sudo -Hnu rabbitmq true 2>/dev/null';
    
    return $? == 0;
}

sub delete_vhost {
    return if !user_can_switch_to_rabbitmq();

    rabbitmqctl("delete_user $VHOST");
    rabbitmqctl("delete_vhost $VHOST");
}

sub add_vhost {
    delete_vhost();
    rabbitmqctl("add_vhost $VHOST");
    rabbitmqctl("add_user $VHOST $VHOST");
    rabbitmqctl("set_permissions -p $VHOST $VHOST '.*' '.*' '.*'");
    rabbitmqctl("set_permissions -p $VHOST guest '.*' '.*' '.*'");
}

sub rabbitmqctl {
    my $command = shift;
    
    system "sudo -Hnu rabbitmq rabbitmqctl $command >/dev/null 2>/dev/null";
}

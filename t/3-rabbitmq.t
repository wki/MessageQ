use strict;
use warnings;
use Test::More;
use Test::Exception;

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
    # publish and get a single message
    my $channel = $broker->channel(42);
    
    is $channel->get(queue => 'render'), undef, 'get returns undef if queue is empty';

    $channel->publish(data => 'foo42', exchange => 'thumbnail', routing_key => 'bar.render');
    
    my $message = $channel->get(queue => 'render');
    isa_ok $message, 'Net::RabbitMQ::PP::Message';
    is $message->body, 'foo42', 'sent data is returned';
    
    $message->ack;
    
    is $channel->get(queue => 'render'), undef, 'get returns undef after queue is cleared';
    
    # publish 2 messages, consume and stop after 2 messages read
    $channel->publish(data => 'msg01', exchange => 'thumbnail', routing_key => 'bar.render');
    $channel->publish(data => 'msg02', exchange => 'thumbnail', routing_key => 'bar.render');
    
    dies_ok { $channel->receive } 'receive on a non-consuming channel fails';
    
    my $consumer_tag = $channel->consume(queue => 'render', consumer_tag => 'xxxbar');
    is $consumer_tag, 'xxxbar', 'consumer tag returned by consume command';
    
    my $m1 = $channel->receive;
    is $m1->body, 'msg01', 'message 1 body is returned';
    $m1->ack;
    
    my $m2 = $channel->receive;
    is $m2->body, 'msg02', 'message 2 body is returned';
    $m2->ack;
    
    $channel->cancel;
    dies_ok { $channel->receive } 'receive on a no-more-consuming channel fails';

    is $channel->get(queue => 'render'), undef, 'all messages are consumed';
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

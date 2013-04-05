use strict;
use warnings;
use Test::More;

use AnyEvent::ZeroMQ;
use ZMQ;
use ZMQ::Constants qw(ZMQ_NOBLOCK ZMQ_PUB ZMQ_SUB ZMQ_SUBSCRIBE);

my $V2 = ($ZMQ::BACKEND eq 'ZMQ::LibZMQ2');
my $sendmsg = $V2 ? 'send' : 'sendmsg';
my $recvmsg = $V2 ? 'recv' : 'recvmsg';

my $c   = ZMQ::Context->new(10);
my $pub = $c->socket(ZMQ_PUB);
my $sub = $c->socket(ZMQ_SUB);
$pub->bind('tcp://127.0.0.1:1234');
$sub->connect('tcp://127.0.0.1:1234');
$sub->setsockopt(ZMQ_SUBSCRIBE, '');

my $cv = AnyEvent->condvar;
$cv->begin; # wait for writability
$cv->begin; # wait for readability

my $got;

my $r = AnyEvent::ZeroMQ->io( poll => 'r', socket => $sub, cb => sub {
    $got = $sub->$recvmsg;
    $cv->end;
});

my $w; $w = AnyEvent::ZeroMQ->io( poll => 'w', socket => $pub, cb => sub {
    my $to_send = ZMQ::Message->new("hello, world!");
    $pub->$sendmsg($to_send);
    $cv->end;
    undef $w;
});

$cv->recv;
ok $got, 'got got';
is $got->data, 'hello, world!', 'got message!';

done_testing;

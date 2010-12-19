use strict;
use warnings;
use Test::More;

use AnyEvent::ZeroMQ;
use ZeroMQ::Raw;
use ZeroMQ::Raw::Constants qw(ZMQ_NOBLOCK ZMQ_PUB ZMQ_SUB ZMQ_SUBSCRIBE);

my $c   = ZeroMQ::Raw::Context->new( threads => 10 );
my $pub = ZeroMQ::Raw::Socket->new($c, ZMQ_PUB);
my $sub = ZeroMQ::Raw::Socket->new($c, ZMQ_SUB);
$pub->bind('tcp://127.0.0.1:1234');
$sub->connect('tcp://127.0.0.1:1234');
$sub->setsockopt(ZMQ_SUBSCRIBE, '');

my $cv = AnyEvent->condvar;
$cv->begin; # wait for writability
$cv->begin; # wait for readability

my $got;

my $r = AnyEvent::ZeroMQ->io( poll => 'r', socket => $sub, cb => sub {
    $got = ZeroMQ::Raw::Message->new;
    $sub->recv($got, ZMQ_NOBLOCK);
    $cv->end;
});

my $w; $w = AnyEvent::ZeroMQ->io( poll => 'w', socket => $pub, cb => sub {
    my $to_send = ZeroMQ::Raw::Message->new_from_scalar("hello, world!");
    $pub->send($to_send, ZMQ_NOBLOCK);
    $cv->end;
    undef $w;
});

$cv->recv;
ok $got, 'got got';
is $got->data, 'hello, world!', 'got message!';

done_testing;

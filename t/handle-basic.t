use strict;
use warnings;
use Test::More;

use EV;
use AnyEvent::ZeroMQ::Handle;
use ZeroMQ::Raw;
use ZeroMQ::Raw::Constants qw(ZMQ_SUBSCRIBE ZMQ_PUB ZMQ_SUB ZMQ_NOBLOCK);

my $c   = ZeroMQ::Raw::Context->new( threads => 10 );
my $pub = ZeroMQ::Raw::Socket->new($c, ZMQ_PUB);
my $sub = ZeroMQ::Raw::Socket->new($c, ZMQ_SUB);
$pub->bind('tcp://127.0.0.1:1234');
$sub->connect('tcp://127.0.0.1:1234');
$sub->setsockopt(ZMQ_SUBSCRIBE, '');

my $pub_h = AnyEvent::ZeroMQ::Handle->new( socket => $pub );
my $sub_h = AnyEvent::ZeroMQ::Handle->new( socket => $sub );

ok $pub_h, 'got publish handle';
ok $sub_h, 'got subscribe handle';

my $cv = AnyEvent->condvar;
$cv->begin for 1..2; # read x2

my ($a, $b);
$sub_h->push_read(sub {
    my ($h, $data) = @_;
    $a = $data;
    $cv->end;
});

$sub_h->push_read(sub {
    my ($h, $data) = @_;
    $b = $data;
    $cv->end;
});

$pub_h->push_write('a');
$pub_h->push_write('b');

$cv->recv;

is $a, 'a', 'got a';
is $b, 'b', 'got b';

$pub_h->push_write('c');
$pub_h->push_write('never read');

$cv = AnyEvent->condvar;
my $t = AnyEvent->timer(
    after => 1,
    cb => sub { $sub_h->push_read(sub { $cv->send($_[1]) }) }
);

is $cv->recv, 'c', 'got c';

EV::loop(); # ensure that no watchers remain

done_testing;

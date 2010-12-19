use strict;
use warnings;
use Test::More;

use ok 'AnyEvent::ZeroMQ::Role::WithHandle';
use ok 'AnyEvent::ZeroMQ::Publish';
use ok 'AnyEvent::ZeroMQ::Subscribe';

my $ENDPOINT1 = 'inproc://#1';
my $ENDPOINT2 = 'inproc://#2';

my $c = ZeroMQ::Raw::Context->new( threads => 0 );

my $sub = AnyEvent::ZeroMQ::Subscribe->new(
    context => $c,
    bind    => $ENDPOINT1,
);

my $pub = AnyEvent::ZeroMQ::Publish->new(
    context => $c,
    connect => $ENDPOINT1,
);


# $pub pushes messages to $sub
my $cv = AnyEvent->condvar;
$pub->push_write('foo');
$sub->push_read(sub { $cv->send($_[1]) });
is $cv->recv, 'foo';

# now $pub2 is also pushing messages to $sub
my $pub2 = AnyEvent::ZeroMQ::Publish->new(
    context => $c,
    connect => $ENDPOINT1,
);

$cv = AnyEvent->condvar;
my @got;
$cv->begin for 1..2;
my $cb = sub { push @got, $_[1], $cv->end };
$sub->push_read($cb) for 1..2;
$pub->push_write('foo');
$pub2->push_write('bar');
$cv->recv;
is_deeply [sort @got], [qw/bar foo/], 'got messages from two publishers';

# now $pub2 is also accepting other subscribers
$pub2->bind($ENDPOINT2);

# and $sub2 is accepting $pub2's messages
my $sub2 = AnyEvent::ZeroMQ::Subscribe->new(
    context => $c,
    connect => $ENDPOINT2,
);

# $pub2 publishes a message, and both subscribers get it
@got = ();
$cv = AnyEvent->condvar;
$cv->begin for 1..2;
$sub->push_read($cb);
$sub2->push_read($cb);
$pub2->push_write('oh hai');
$cv->recv;
is_deeply \@got, ['oh hai', 'oh hai'],
    'got the message on both subscribers';

# my mind is blown.

done_testing;

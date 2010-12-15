use strict;
use warnings;
use Test::More;

use ok 'AnyEvent::ZeroMQ::Role::WithHandle';
use ok 'AnyEvent::ZeroMQ::Publish';
use ok 'AnyEvent::ZeroMQ::Subscribe';

my $ENDPOINT = 'inproc://#1';
my $c = ZeroMQ::Raw::Context->new( threads => 0 );

my $pub = AnyEvent::ZeroMQ::Publish->new(
    context => $c,
    bind    => $ENDPOINT,
);

my $all = AnyEvent::ZeroMQ::Subscribe->new(
    context => $c,
    connect => $ENDPOINT,
);

my $foo = AnyEvent::ZeroMQ::Subscribe->new(
    context => $c,
    connect => $ENDPOINT,
    topics  => [qw/foo:/],
);

my $foobar = AnyEvent::ZeroMQ::Subscribe->new(
    context => $c,
    connect => $ENDPOINT,
);

$foobar->topics([qw/foo: bar:/]);

$pub->publish('foo: bar');
$pub->publish('bar: baz');
$pub->publish('baz: qux');

my $cv = AnyEvent->condvar;
$cv->begin for 1..6;

my $results = {};

$all   ->on_read(sub { $cv->end; push @{$results->{all}   }, $_[1] });
$foo   ->on_read(sub { $cv->end; push @{$results->{foo}   }, $_[1] });
$foobar->on_read(sub { $cv->end; push @{$results->{foobar}}, $_[1] });

$cv->recv;

is_deeply $results, { all    => [ 'foo: bar', 'bar: baz', 'baz: qux' ],
                      foo    => [ 'foo: bar' ],
                      foobar => [ 'foo: bar', 'bar: baz' ],
                    },
    'got results';

$cv = AnyEvent->condvar;
$cv->begin for 1..3;
$results = {};

# change subscriptions
$all->topics([]);
$foo->topics([]);
$foobar->topics([qw/bar: qux: gorch:/]);

# use this opportunity to ensure that push_read works as on_read does
$foobar->push_read(sub { $cv->end; push @{$results->{foobar}}, lc $_[1] });

# send data
$pub->publish('foo: no');
$pub->publish('bar: YES');
$pub->publish('qux: yes');
$pub->publish('gorch: yes');
$cv->recv;

# subscriptions updated and push_read works?
is_deeply $results, { foobar => [ map { "$_: yes" } qw/bar qux gorch/] },
    'subscriptions mirror $topics attribute';

done_testing;

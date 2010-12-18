use strict;
use warnings;
use Test::More;

use ok 'AnyEvent::ZeroMQ::Push';
use ok 'AnyEvent::ZeroMQ::Pull';

my $ENDPOINT = 'inproc://#1';

my @c = (context => ZeroMQ::Raw::Context->new( threads => 0 ));

my $server   = AnyEvent::ZeroMQ::Push->new( @c, bind    => $ENDPOINT );
my $client_a = AnyEvent::ZeroMQ::Pull->new( @c, connect => $ENDPOINT );

my $cv = AnyEvent->condvar;
my @to_write = qw/a b/;
my ($a, $b, $drain) = (0, 0, 0);

$cv->begin for 1..8;
$client_a->on_read(sub { $a++; $cv->end });

my $client_b = AnyEvent::ZeroMQ::Pull->new(
    @c,
    connect => $ENDPOINT,
    # test that on_read gets passed thru
    on_read => sub { $b++; $cv->end },
);

ok $client_a->has_on_read, 'a has on_read';
ok $client_b->has_on_read, 'b has on_read';
ok !$server->has_on_drain, 'no on_drain yet';
$server->on_drain(sub { $drain++ });
ok $server->has_on_drain, 'now we have one';

$server->push_write(sub { $cv->end; 'first' });
$server->push_write(sub { $cv->end; 'second' });
$server->push_write(sub { $cv->end; 'third' });
$server->push_write(sub { $cv->end; 'fourth' });

$cv->recv;

is $a, 2, 'got one request to a';
is $b, 2, 'got one request to b';
cmp_ok $drain, '>', 1, 'drained at least once';

done_testing;

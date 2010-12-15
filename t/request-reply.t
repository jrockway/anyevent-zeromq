use strict;
use warnings;
use Test::More;

use ok 'AnyEvent::ZeroMQ::Role::WithHandle';
use ok 'AnyEvent::ZeroMQ::Request';
use ok 'AnyEvent::ZeroMQ::Reply';

my $on_request;
my $_on_request = sub { eval { $on_request->() } };

my $ENDPOINT = 'inproc://#1';
my $c = ZeroMQ::Raw::Context->new( threads => 0 );

my $req = AnyEvent::ZeroMQ::Request->new(
    context => $c,
    bind    => $ENDPOINT,
);

my $rep = AnyEvent::ZeroMQ::Reply->new(
    context    => $c,
    connect    => $ENDPOINT,
    on_request => sub {
        my ($h, $req) = @_;
        $_on_request->();
        $req++;
        return $req;
    },
);

my $reply;
my $cv = AnyEvent->condvar;
$cv->begin for 1..2;
$on_request = sub { $cv->end; undef $on_request };
$req->push_request( "1", sub {
    my ($h, $msg, $hint) = @_;
    $reply = [$hint, $msg];
    $cv->end;
}, 'hint');

$cv->recv;
is_deeply $reply, ['hint', 2], 'the cycle works';

done_testing;

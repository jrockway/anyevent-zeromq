use strict;
use warnings;
use Test::More;
use ZeroMQ::Raw::Context;

use ok 'AnyEvent::ZeroMQ::Push';
use ok 'AnyEvent::ZeroMQ::Pull';

my $ENDPOINT_A = 'inproc://#A';
my $ENDPOINT_B = 'inproc://#B';
my $ENDPOINT_C = 'inproc://#C';

my $c = ZeroMQ::Raw::Context->new( threads => 0 );

#     __PULL____                 __PULL____
#    /          \               /          \
#    | worker a |               | worker b |
#    \__________/ [B]<-\        \__________/ [C]
#           \           \       /             ^
#            \           \     /             /
#             \           \   /             /
#              \           \ /             |
#               \->[A]<-----X              /
#    -------------           \  -------------
#    | manager a |            \-| manager b |
#    -------------              -------------
#      PUSH                         PUSH
#

my $manager_a = AnyEvent::ZeroMQ::Push->new(
    context => $c,
    bind    => $ENDPOINT_A,
);

my $worker_a = AnyEvent::ZeroMQ::Pull->new(
    context => $c,
    bind    => $ENDPOINT_B,
    connect => $ENDPOINT_A,
);

my $worker_b = AnyEvent::ZeroMQ::Pull->new(
    context => $c,
    bind    => $ENDPOINT_C,
    connect => $ENDPOINT_A,
);

my $manager_b = AnyEvent::ZeroMQ::Push->new(
    context => $c,
    connect => $ENDPOINT_B,
    connect => $ENDPOINT_C,
);

my %results;

my $cv = AE::cv;
my $read = sub {
    my $name = shift;
    return sub {
        $results{$name} ||= [];
        push @{$results{$name}}, $_[1];
        $cv->end;
    },
};

$worker_a->push_read($read->('a')) for 1..4;
$worker_b->push_read($read->('b')) for 1..4;

my $write = sub {
    my $what = shift;
    return sub {
        $cv->end;
        return $what;
    };
};

$cv->begin for 1..16;
for(1..2){
    $manager_a->push_write($write->('from a to a'));
    $manager_a->push_write($write->('from a to b'));
    $manager_b->push_write($write->('from b to a'));
    $manager_b->push_write($write->('from b to b'));
}

$cv->recv;

is_deeply \%results, {
    a => [
        'from a to a',
        'from b to a',
        'from a to a',
        'from b to a',
    ],
    b => [
        'from a to b',
        'from b to b',
        'from a to b',
        'from b to b',
    ],
}, 'each worker got the expected messages';

done_testing;

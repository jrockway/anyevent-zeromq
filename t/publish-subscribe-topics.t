use strict;
use warnings;
use Test::More;

use AnyEvent::ZeroMQ::Publish;
use AnyEvent::ZeroMQ::Subscribe;

my $ENDPOINT = 'inproc://#1';
my $c = ZeroMQ::Raw::Context->new( threads => 0 );

my $pub = AnyEvent::ZeroMQ::Publish->with_traits('Topics')->new(
    context => $c,
    bind    => $ENDPOINT,
);

my $sub = AnyEvent::ZeroMQ::Subscribe->with_traits('Topics')->new(
    context => $c,
    connect => $ENDPOINT,
    topics  => [qw/foo: bar:/],
);

my $cv = AE::cv;
$cv->begin for 1..2;

my @results;
my $get_item = sub { push @results, [$_[2], $_[1]]; $cv->end };
$sub->push_read($get_item);
$sub->push_read($get_item);

$pub->publish( 'foo:this is foo');
$pub->publish( 'bar:this is bar');
$cv->recv;

is_deeply \@results, [['foo:', 'this is foo'], ['bar:', 'this is bar']],
    'got parsed results';

$sub->topics([qw/bar: baz:/]);

$cv = AE::cv;
$cv->begin for 1..2;
@results = ();

$sub->push_read($get_item);
$sub->push_read($get_item);

$pub->publish( 'foo:this is foo');
$pub->publish( 'this is bar', topic => 'bar:');
$pub->publish( sub { 'this is baz' }, topic => 'baz:');
$cv->recv;

is_deeply \@results, [['bar:', 'this is bar'], ['baz:', 'this is baz']],
    'got parsed results after topic change';

done_testing;

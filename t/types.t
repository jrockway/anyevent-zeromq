use strict;
use warnings;
use AnyEvent::ZeroMQ::Types qw(Endpoint);
use Test::TableDriven (
    endpoint => {
        'foo'                          => 0,
        'tcp://127.0.0.1:123/'         => 0,
        'tcp://127.0.0.1:123'          => 1,
        'tcp://host-name.com:123'      => 1,
        'tcp://eth0:123'               => 1,
        'inproc://#1'                  => 1,
        'ipc://file/name.goes_here'    => 1,
        'pgm://eth0;239.1.1.1:123'     => 1,
        'epgm://1.2.3.4;239.1.1.1:123' => 1,
        'pgm://foo:123/'               => 0,
        'tcp://'                       => 0,
        'inproc://'                    => 0,
        'pgm://'                       => 0,
        'egpm://'                      => 0,
        'ipc://'                       => 0,
        'tcp://*:1234'                 => 1,
    },
);

sub endpoint {
    my $in = shift;
    return Endpoint()->validate($in) ? 0 : 1;
}

runtests;

package AnyEvent::ZeroMQ::Types;
# ABSTRACT: Type constraints for data passed to the ZMQ library
use strict;
use warnings;
use Regexp::Common qw /net/;

my @socket_constants =
    qw(ZMQ_REQ ZMQ_REP ZMQ_PUSH ZMQ_PULL ZMQ_PUB ZMQ_SUB);

use ZeroMQ::Raw::Constants (@socket_constants);
use MooseX::Types::Moose qw(Str Int);
use MooseX::Types -declare => [qw/ZmqEndpoint SocketType SocketAction/];
use true;

subtype ZmqEndpoint, as Str, where {
    # if you have a trailing slash on a tcp address, the entire
    # fucking program dies.  fucking C programmers!

    my $interface = qr/[a-z]+[0-9]*/;
    my $host      = qr/[A-Za-z0-9.-]+/;
    my $ip        = qr/$RE{net}{IPv4}/;
    my $andport   = qr/:[0-9]+/;

    if(my ($proto, $rest) = m{^([a-z]+)://(.+)$}){
        return 1 if $proto eq 'inproc';
        return 1 if $proto eq 'ipc';
        return 1 if $proto eq 'tcp' && $rest =~ /^(?:$host|$ip|$interface)$andport$/;
        return 1
            if ($proto eq 'pgm' || $proto eq 'epgm') &&
                $rest =~ /^(?:$interface|$ip);$ip$andport$/;
        return 0;
    }
    return 0;

}, message { 'An endpoint must be in the form "<transport>://<address>"' };

coerce ZmqEndpoint, from Str, via {
    s{(^[/])/$}{$1}g;
};

my %allowed_sockettype = map { ZeroMQ::Raw::Constants->$_ => $_ } @socket_constants;
subtype SocketType, as Int, where {
    exists $allowed_sockettype{$_};
}, message { 'A socket type must be one of: '. join(', ', @socket_constants) };

subtype SocketAction, as Str, where {
    /^(bind|connect)$/;
}, message { 'The action must be "bind" or "connect"' };

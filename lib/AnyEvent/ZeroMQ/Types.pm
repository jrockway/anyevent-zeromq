package AnyEvent::ZeroMQ::Types;
# ABSTRACT: Type constraints for data passed to the ZMQ library
use strict;
use warnings;
use Regexp::Common qw /net/;

my @socket_constants =
    qw(ZMQ_REQ ZMQ_REP ZMQ_PUSH ZMQ_PULL ZMQ_PUB ZMQ_SUB);

use ZeroMQ::Raw::Constants (@socket_constants);
use MooseX::Types::Moose qw(Str Int ArrayRef);
use MooseX::Types -declare => [
    qw/Endpoint Endpoints SocketType SocketDirection IdentityStr/
];
use true;

subtype Endpoint, as Str, where {
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

subtype Endpoints, as ArrayRef[Endpoint], message {
    'Each endpoint must be in the form "<transport>://<address>"';
};

sub fixup_endpoint() {
    s{(^[/])/$}{$1}g;
}

coerce Endpoint, from Str, via { fixup_endpoint };

coerce Endpoints, from ArrayRef[Str], via {
    my @array = @$_;
    fixup_endpoint for @array;
    $_ = [@array];
};

my %allowed_sockettype = map { ZeroMQ::Raw::Constants->$_ => $_ } @socket_constants;
subtype SocketType, as Int, where {
    exists $allowed_sockettype{$_};
}, message { 'A socket type must be one of: '. join(', ', @socket_constants) };

subtype IdentityStr, as Str, where {
    length $_ < 256 && length $_ >= 0;
    # it must also not start with \0, but that is technically legal
    # and if the user wants to do it, it's between him and the man
    # page authors. *i'm* not getting involved :)
}, message { 'The identity must be non-empty and no more than 255 characters.' };

subtype SocketDirection, as Str, where {
    /^(r|rw|wr|w|)$/;
}, message { "Socket direction must be r, w, rw, or the empty string; not '$_'" };

package AnyEvent::ZeroMQ;
# ABSTRACT: non-blocking interface to ZeroMQ sockets
use strict;
use warnings;

use ZeroMQ::Raw;
use ZeroMQ::Raw::Constants qw(ZMQ_FD ZMQ_POLLIN ZMQ_POLLOUT ZMQ_EVENTS);
use Carp qw(confess);

use namespace::autoclean;
use AnyEvent;

sub io {
    my ($class, %args) = @_;
    my $poll = $args{poll}   || confess 'must supply poll direction';
    my $sock = $args{socket} || confess 'must supply socket';
    my $cb   = $args{cb}     || confess 'must supply cb';

    my $fd = $sock->getsockopt(ZMQ_FD);
    confess 'getsockopt did not return a valid fd!'
        unless defined $fd;

    my $mask = $poll eq 'w' ? ZMQ_POLLOUT :
               $poll eq 'r' ? ZMQ_POLLIN  :
               confess "invalid poll direction '$poll'";

    return AnyEvent->io(
        poll => $poll,
        fh   => $fd,
        cb   => sub {
            $cb->() if (($sock->getsockopt(ZMQ_EVENTS) & $mask) == $mask);
        },
    );
}

sub can {
    my ($class, %args) = @_;
    my $poll = $args{poll}   || confess 'must supply poll direction';
    my $sock = $args{socket} || confess 'must supply socket';

    my $mask = $poll eq 'w' ? ZMQ_POLLOUT :
               $poll eq 'r' ? ZMQ_POLLIN  :
               confess "invalid poll direction '$poll'";

    return (($sock->getsockopt(ZMQ_EVENTS) & $mask) == $mask)
}

1;

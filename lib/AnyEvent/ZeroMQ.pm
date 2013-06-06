package AnyEvent::ZeroMQ;
# ABSTRACT: non-blocking interface to ZeroMQ sockets
use strict;
use warnings;

use ZMQ;
use ZMQ::Constants qw(ZMQ_FD ZMQ_POLLIN ZMQ_POLLOUT ZMQ_EVENTS);
BEGIN {
    no strict 'refs';
    *zmq_strerror = \&{$ZMQ::BACKEND . '::zmq_strerror'};
}
use AnyEvent;
use Carp qw(croak confess);
use namespace::autoclean;

use Exporter::Tidy
      errors => [qw( _zfail )];

sub io {
    my ($class, %args) = @_;
    my $poll = $args{poll}   || confess 'must supply poll direction';
    my $sock = $args{socket} || confess 'must supply socket';
    my $cb   = $args{cb}     || confess 'must supply cb';

    my $fd = $sock->getsockopt(ZMQ_FD);
    defined($fd) or _zfail('getsockopt(ZMQ_FD)');

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

sub probe {
    my ($class, %args) = @_;
    my $poll = $args{poll}   || confess 'must supply poll direction';
    my $sock = $args{socket} || confess 'must supply socket';

    my $mask = $poll eq 'w' ? ZMQ_POLLOUT :
               $poll eq 'r' ? ZMQ_POLLIN  :
               confess "invalid poll direction '$poll'";

    return (($sock->getsockopt(ZMQ_EVENTS) & $mask) == $mask)
}

sub _zfail {
    my $self = shift;
    my $err = $!;
    confess(join('', @_, ': ', zmq_strerror($err)));
}

1;

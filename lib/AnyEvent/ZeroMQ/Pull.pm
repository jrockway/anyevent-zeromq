package AnyEvent::ZeroMQ::Pull;
# ABSTRACT: Non-blocking OO abstraction over ZMQ_PULL push/pull sockets
use Moose;
use true;
use namespace::autoclean;
use ZeroMQ::Raw::Constants qw(ZMQ_PULL);

with 'AnyEvent::ZeroMQ::Role::WithHandle' =>
    { socket_type => ZMQ_PULL, socket_action => 'connect', socket_direction => 'r' };

with 'AnyEvent::ZeroMQ::Handle::Role::Generic',
     'AnyEvent::ZeroMQ::Handle::Role::Readable';

__PACKAGE__->meta->make_immutable;

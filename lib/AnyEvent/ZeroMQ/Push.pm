package AnyEvent::ZeroMQ::Push;
# ABSTRACT: Non-blocking OO abstraction over ZMQ_PUSH push/push sockets
use Moose;
use true;
use namespace::autoclean;
use ZeroMQ::Raw::Constants qw(ZMQ_PUSH);

with 'AnyEvent::ZeroMQ::Role::WithHandle' =>
    { socket_type => ZMQ_PUSH, socket_action => 'bind', socket_direction => 'w' };

with 'AnyEvent::ZeroMQ::Handle::Role::Generic',
     'AnyEvent::ZeroMQ::Handle::Role::Writable';

__PACKAGE__->meta->make_immutable;

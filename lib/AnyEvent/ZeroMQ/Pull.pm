package AnyEvent::ZeroMQ::Pull;
# ABSTRACT: Non-blocking OO abstraction over ZMQ_PULL push/pull sockets
use Moose;
use true;
use namespace::autoclean;
use ZeroMQ::Raw::Constants qw(ZMQ_PULL);

with 'AnyEvent::ZeroMQ::Role::WithHandle' =>
    { socket_type => ZMQ_PULL, socket_action => 'connect' };

sub BUILD {}

has '+handle' => (
    # XXX: deal with inability to set on_read / on_error / etc. in the
    # constructor
    handles => 'AnyEvent::ZeroMQ::Handle::Role::Readable',
);

__PACKAGE__->meta->make_immutable;

package AnyEvent::ZeroMQ::Role::WithHandle;
# ABSTRACT: Role for specialized socket types that need a pre-built handle
use MooseX::Role::Parameterized;
use true;

use AnyEvent::ZeroMQ::Types qw(SocketType SocketAction ZmqEndpoint);
use AnyEvent::ZeroMQ::Handle;
use ZeroMQ::Raw;
use Try::Tiny;
use Carp qw(confess);
use namespace::autoclean;

parameter 'socket_type' => (
    is       => 'ro',
    isa      => SocketType,
    required => 1,
);

parameter 'socket_action' => (
    is       => 'ro',
    isa      => SocketAction,
    required => 1,
);

role {
    my $p = shift;

    my $action = $p->socket_action;
    my $type   = $p->socket_type;

    has 'context' => (
        is       => 'ro',
        isa      => 'ZeroMQ::Raw::Context',
        required => 1,
    );

    has $action => (
        is       => 'ro',
        isa      => ZmqEndpoint,
        coerce   => 1,
        required => 1,
    );

    has 'handle' => (
        reader     => 'handle',
        isa        => 'AnyEvent::ZeroMQ::Handle',
        lazy_build => 1,
    );

    method '_build_handle' => sub {
        my $self = shift;

        my $socket = ZeroMQ::Raw::Socket->new($self->context, $type);
        try {
            $socket->$action($self->$action);
        }
        catch {
            confess "Error allocating socket: ($!) $_"
        };

        return AnyEvent::ZeroMQ::Handle->new( socket => $socket );
    };

    requires 'BUILD';
    before 'BUILD' => sub { $_[0]->handle };
};

package AnyEvent::ZeroMQ::Role::WithHandle;
# ABSTRACT: Role for specialized socket types that need a pre-built handle
use MooseX::Role::Parameterized;
use true;

use AnyEvent::ZeroMQ::Types qw(SocketType SocketAction SocketDirection ZmqEndpoint);
use AnyEvent::ZeroMQ::Handle;
use AnyEvent::ZeroMQ::Handle::Role::Generic;
use AnyEvent::ZeroMQ::Handle::Role::Readable;
use AnyEvent::ZeroMQ::Handle::Role::Writable;
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

parameter 'socket_direction' => (
    is       => 'ro',
    isa      => SocketDirection,
    required => 1,
);

role {
    my $p = shift;

    my $action = $p->socket_action;
    my $type   = $p->socket_type;
    my $dir    = $p->socket_direction;

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
    my @roles = 'AnyEvent::ZeroMQ::Handle::Role::Generic';
    push @roles, 'AnyEvent::ZeroMQ::Handle::Role::Readable' if $dir =~ /r/;
    push @roles, 'AnyEvent::ZeroMQ::Handle::Role::Writable' if $dir =~ /w/;

    # a very simple role metaclass -> method list converter.  only
    # works for these three roles, do not cut-n-paste!
    my @methods = map { "$_" } map { $_->meta->get_required_method_list } @roles;

    has 'handle' => (
        reader     => 'handle',
        isa        => 'AnyEvent::ZeroMQ::Handle',
        lazy_build => 1,
        handles    => [@methods],
    );

    has '_extra_initargs' => (
        is       => 'ro',
        isa      => 'HashRef',
        required => 1,
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

        return AnyEvent::ZeroMQ::Handle->new(
            socket => $socket,
            %{$self->_extra_initargs || {}},
        );
    };

    method 'BUILDARGS' => sub {
        my ($class, %in) = @_;
        my %extra;
        for my $m (@methods) {
            $extra{$m} = delete $in{$m} if exists $in{$m};
        }
        return { %in, _extra_initargs => \%extra };
    };

    method 'BUILD' => sub {
        my $self = shift;
        $self->handle;
    };
};

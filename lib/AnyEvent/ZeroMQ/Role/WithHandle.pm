package AnyEvent::ZeroMQ::Role::WithHandle;
# ABSTRACT: Role for specialized socket types that has_a handle object
use MooseX::Role::Parameterized;
use MooseX::Types::Moose qw(ArrayRef);
use true;

use AnyEvent::ZeroMQ::Types qw(SocketType SocketDirection Endpoints);
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

parameter 'socket_direction' => (
    is       => 'ro',
    isa      => SocketDirection,
    required => 1,
);

role {
    my $p = shift;

    my $type   = $p->socket_type;
    my $dir    = $p->socket_direction;

    has 'context' => (
        is       => 'ro',
        isa      => 'ZeroMQ::Raw::Context',
        required => 1,
    );

    has 'connect' => (
        init_arg => 'connect',
        isa      => Endpoints,
        default  => sub { [] },
        coerce   => 1,
        traits   => ['Array'],
        handles  => {
            connected_to => 'elements',
            _connect     => 'push',
        },
    );

    has 'bind' => (
        init_arg => 'bind',
        isa      => Endpoints,
        default  => sub { [] },
        coerce   => 1,
        traits   => ['Array'],
        handles  => {
            bound_to => 'elements',
            _bind    => 'push',
        },
    );

    my @roles = 'AnyEvent::ZeroMQ::Handle::Role::Generic';
    push @roles, 'AnyEvent::ZeroMQ::Handle::Role::Readable' if $dir =~ /r/;
    push @roles, 'AnyEvent::ZeroMQ::Handle::Role::Writable' if $dir =~ /w/;
    # XXX: we want to apply @roles, but not until after the
    # parameterized role has been applied.  this poses a problem, so
    # each consumer must do it manually.  wtf.

    # a very simple role metaclass -> method list converter.  only
    # works for these three roles, do not cut-n-paste!
    my @methods = map { "$_" } map { $_->meta->get_required_method_list } @roles;

    has 'handle' => (
        reader     => 'handle',
        isa        => 'AnyEvent::ZeroMQ::Handle',
        lazy_build => 1,
        handles    => [@methods],
    );

    after 'bind' => sub {
        my ($self, $bind_to) = @_;
        $self->_bind($bind_to);
    };

    after 'connect' => sub {
        my ($self, $connect_to) = @_;
        $self->_connect($connect_to);
    };

    has '_extra_initargs' => (
        is       => 'ro',
        isa      => 'HashRef',
        required => 1,
    );

    method '_build_handle' => sub {
        my $self = shift;

        my $socket = ZeroMQ::Raw::Socket->new($self->context, $type);

        for my $bind ($self->bound_to){
            $socket->bind($bind);
        }

        for my $connect ($self->connected_to){
            $socket->connect($connect);
        }

        return AnyEvent::ZeroMQ::Handle->new(
            socket => $socket,
            %{$self->_extra_initargs || {}},
        );
    };

    # this does a few things:
    #
    # * allow multiple bind/connect pairs to be passed in
    #
    # * gather initargs delegated from Handle and save those as
    #   _extra_initargs.  in _build_handle, these get passed to the
    #   Handle's constructor, allowing on_read/on_drain/etc. to work
    #   correctly.
    #
    #   BUG: the only issue is that the on_read and on_drain get $h,
    #   the handle, instead of $self.
    method 'BUILDARGS' => sub {
        my ($class, @in) = @_;
        my %in;
        while(@in) {
            my $key = shift @in;
            my $value = shift @in;
            if($key eq 'bind' || $key eq 'connect'){
                $in{$key} ||= [];
                push @{$in{$key}}, ref $value ? @$value : $value;
            }
            else {
                $in{$key} = $value;
            }
        }
        my %extra;
        for my $m (grep { !/bind|connect/ } @methods) {
            $extra{$m} = delete $in{$m} if exists $in{$m};
        }
        return { %in, _extra_initargs => \%extra };
    };

    method 'BUILD' => sub {
        my $self = shift;
        $self->handle; # make sure the handle is ready immediately
    };
};

package AnyEvent::ZeroMQ::Handle;
# ABSTRACT: AnyEvent::Handle-like interface for 0MQ sockets
use Moose;

use AnyEvent::ZeroMQ;
use Scalar::Util qw(weaken);
use Try::Tiny;
use ZeroMQ::Raw::Constants qw(ZMQ_NOBLOCK);

use true;
use namespace::autoclean;

has 'socket' => (
    is       => 'ro',
    isa      => 'ZeroMQ::Raw::Socket',
    required => 1,
);

has 'copy' => (
    is      => 'ro',
    isa     => 'Bool',
    default => 1, # preserve perl semantics by default
);

# has [qw/on_read on_drain on_error/] => (
#     is      => 'ro',
#     isa     => 'CodeRef',
#     default => sub { sub {} },
# );

has [qw/read_watcher write_watcher/] => (
    init_arg   => undef,
    is         => 'ro',
    lazy_build => 1,
);

has [qw/read_buffer write_buffer/] => (
    init_arg => undef,
    is       => 'ro',
    default  => sub { [] },
);

sub _build_read_watcher {
    my $self = shift;
    weaken $self;
    return AnyEvent::ZeroMQ->io(
        poll   => 'r',
        socket => $self->socket,
        cb     => sub { $self->on_read },
    );
}

sub _build_write_watcher {
    my $self = shift;
    weaken $self;
    return AnyEvent::ZeroMQ->io(
        poll   => 'w',
        socket => $self->socket,
        cb     => sub { $self->on_write },
    );
}

sub has_read_todo {
    my $self = shift;
    return exists $self->read_buffer->[0];
}

sub readable {
    my $self = shift;
    return AnyEvent::ZeroMQ->can( poll => 'r', socket => $self->socket );
}

sub on_read {
    my $self = shift;
    $self->clear_read_watcher;

    while($self->readable && $self->has_read_todo){
        try {
            my $cb = shift @{$self->read_buffer};
            my $msg = ZeroMQ::Raw::Message->new;
            $self->socket->recv($msg, ZMQ_NOBLOCK);
            if($self->copy){
                $cb->($self, $msg->data);
            }
            else {
                $cb->($self, $msg);
            }
        }
        catch {
            warn "Error in read handler: $_";
        };
    }

    $self->read_watcher if $self->has_read_todo;
}

sub push_read {
    my ($self, $cb) = @_;
    push @{$self->read_buffer}, $cb;
    $self->on_read;
}

sub has_write_todo {
    my $self = shift;
    return exists $self->write_buffer->[0];
}

sub writable {
    my $self = shift;
    return AnyEvent::ZeroMQ->can( poll => 'w', socket => $self->socket );
}

sub on_write {
    my $self = shift;
    $self->clear_write_watcher;

    while($self->writable && $self->has_write_todo){
        try {
            my $msg = shift @{$self->write_buffer};
            $self->socket->send($msg, ZMQ_NOBLOCK);
        }
        catch {
            warn "Error in write handler: $_";
        }
    }

    $self->write_watcher if $self->has_write_todo;
}

sub push_write {
    my $self = shift;
    my $msg = ZeroMQ::Raw::Message->new_from_scalar($_[0]);
    push @{$self->write_buffer}, $msg;
    $self->on_write;
}

__PACKAGE__->meta->make_immutable;

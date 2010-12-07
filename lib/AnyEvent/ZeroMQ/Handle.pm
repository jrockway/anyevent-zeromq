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

has 'on_read' => (
    is        => 'rw',
    isa       => 'CodeRef',
    predicate => 'has_on_read',
    clearer   => 'clear_on_read',
);

# has [qw/on_drain on_error/] => (
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
        cb     => sub { $self->read },
    );
}

sub _build_write_watcher {
    my $self = shift;
    weaken $self;
    return AnyEvent::ZeroMQ->io(
        poll   => 'w',
        socket => $self->socket,
        cb     => sub { $self->write },
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

sub _read_once {
    my ($self, $cb) = @_;
    try {
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

sub read {
    my $self = shift;
    $self->clear_read_watcher;

    while($self->readable && $self->has_read_todo){
        $self->_read_once(shift @{$self->read_buffer});
    }

    while($self->readable && $self->has_on_read){
        $self->_read_once($self->on_read);
    }

    $self->read_watcher if $self->has_read_todo || $self->has_on_read;
}

sub push_read {
    my ($self, $cb) = @_;
    push @{$self->read_buffer}, $cb;
    $self->read;
}

sub has_write_todo {
    my $self = shift;
    return exists $self->write_buffer->[0];
}

sub writable {
    my $self = shift;
    return AnyEvent::ZeroMQ->can( poll => 'w', socket => $self->socket );
}

sub write {
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
    $self->write;
}

__PACKAGE__->meta->make_immutable;

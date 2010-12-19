package AnyEvent::ZeroMQ::Handle;
# ABSTRACT: AnyEvent::Handle-like interface for 0MQ sockets
use Moose;

use AnyEvent::ZeroMQ;
use AnyEvent::ZeroMQ::Types qw(IdentityStr);
use ZeroMQ::Raw::Constants qw(ZMQ_NOBLOCK ZMQ_IDENTITY);

use Params::Util qw(_CODELIKE);
use Scalar::Util qw(weaken);
use Try::Tiny;

use true;
use namespace::autoclean;

has 'socket' => (
    is       => 'ro',
    isa      => 'ZeroMQ::Raw::Socket',
    handles  => [qw/bind connect/],
    required => 1,
);

after qw/bind connect/ => sub {
    my $self = shift;
    # this can change readability/writability status, so do the checks
    # again
    $self->read;
    $self->write;
};

has 'identity' => (
    is         => 'rw',
    isa        => IdentityStr,
    lazy_build => 1,
    trigger    => sub { shift->_change_identity(@_) },
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
    trigger   => sub { $_[0]->read },
);

has 'on_error' => (
    is        => 'rw',
    isa       => 'CodeRef',
    predicate => 'has_on_error',
    clearer   => 'clear_on_error',
);

sub handle_error {
    my ($self, $str) = @_;
    return $self->on_error->($str)
        if $self->has_on_error;

    warn "AnyEvent::ZeroMQ::Handle: error in callback (ignoring): $str";
}

has 'on_drain' => (
    is        => 'rw',
    isa       => 'CodeRef',
    predicate => 'has_on_drain',
    clearer   => 'clear_on_drain',
    # i don't think we need to trigger this, since if we were
    # writable, we would be drained.
);

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

sub _build_identity {
    my ($self) = @_;
    return $self->socket->getsockopt( ZMQ_IDENTITY );
}

sub _change_identity {
    my ($self, $new, $old) = @_;
    return $self->socket->setsockopt( ZMQ_IDENTITY, $new );
}

sub has_read_todo {
    my $self = shift;
    return exists $self->read_buffer->[0];
}

sub readable {
    my $self = shift;
    return AnyEvent::ZeroMQ->probe( poll => 'r', socket => $self->socket );
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
        $self->handle_error($_);
    };
}

sub read {
    my $self = shift;

    while($self->readable && $self->has_read_todo){
        $self->_read_once(shift @{$self->read_buffer});
    }

    while($self->readable && $self->has_on_read){
        $self->_read_once($self->on_read);
    }

    if($self->has_read_todo || $self->has_on_read){
        # ensure we have a watcher
        $self->read_watcher;
    }
    else {
        $self->clear_read_watcher;
    }
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
    return AnyEvent::ZeroMQ->probe( poll => 'w', socket => $self->socket );
}

sub build_message {
    my ($self, $cb_or_msg) = @_;
    my $msg = $cb_or_msg;

    if(my $cb = _CODELIKE($cb_or_msg)){
        $msg = $cb->($self);
    }

    return $msg
        if ref $msg && blessed $msg &&
            $msg->isa('ZeroMQ::Raw::Message');

    return ZeroMQ::Raw::Message->new_from_scalar($msg)
        if defined $msg;

    return;
}

sub write {
    my $self = shift;
    $self->clear_write_watcher;

    my $wrote_something = 0;
    while($self->writable && $self->has_write_todo){
        $wrote_something++;
        try {
            my $msg = $self->build_message(shift @{$self->write_buffer});
            $self->socket->send($msg, ZMQ_NOBLOCK) if $msg;
        }
        catch {
            $self->handle_error($_);
        }
    }

    # XXX: the user is exposed to complexity here; he needs to clear
    # the on_drain handler if he wants to push_write again.
    $self->on_drain->($self, $self->writable)
        if $wrote_something && $self->has_on_drain;

    $self->write_watcher if $self->has_write_todo;
}

sub push_write {
    my $self = shift;

    # $_[0] instead of a named var to avoid a copy.  zeromq, zero-copy :)
    if(_CODELIKE($_[0]) || blessed $_[0] && $_[0]->isa('ZeroMQ::Raw::Message')){
        push @{$self->write_buffer}, $_[0];
    }
    else {
        push @{$self->write_buffer}, ZeroMQ::Raw::Message->new_from_scalar($_[0]);
    }
    $self->write;
}

with 'AnyEvent::ZeroMQ::Handle::Role::Readable',
     'AnyEvent::ZeroMQ::Handle::Role::Writable',
     'AnyEvent::ZeroMQ::Handle::Role::Generic';

__PACKAGE__->meta->make_immutable;

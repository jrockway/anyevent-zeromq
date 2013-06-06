package AnyEvent::ZeroMQ::Subscribe;
# ABSTRACT: Non-blocking OO abstraction over ZMQ_SUB publish/subscribe sockets
use Moose;
use true;
use namespace::autoclean;
use MooseX::Types::Set::Object;
use Scalar::Util qw(weaken);
use ZMQ::Constants qw(ZMQ_SUB ZMQ_SUBSCRIBE ZMQ_UNSUBSCRIBE);

with 'AnyEvent::ZeroMQ::Role::WithHandle' =>
    { socket_type => ZMQ_SUB, socket_direction => '' },
    'MooseX::Traits';

has '+_trait_namespace' => ( default => 'AnyEvent::ZeroMQ::Subscribe::Trait' );

has 'topics' => (
    is      => 'rw',
    isa     => 'Set::Object',
    coerce  => 1,
    default => sub { [''] },
    trigger => sub {
        my ($self, $new, $old) = @_;
        $self->_topics_changed($new, $old);
    },
);

sub _topics_changed {
    my ($self, $new, $old) = @_;
    return unless $old;
    # sets are excellent, let's go shopping
    my $subscribe = $new - $old;
    my $unsubscribe = $old - $new;
    $self->_unsubscribe($_) for $unsubscribe->members;
    $self->_subscribe($_)   for $subscribe->members;
    return $new;
}

has 'on_read' => (
    is        => 'rw',
    isa       => 'CodeRef',
    predicate => 'has_on_read',
    clearer   => 'clear_on_read',
    trigger   => sub {
        my ($self, $val) = @_;
        weaken $self;
        $self->handle->on_read(sub { $self->_receive_item(@_) });
    },
);

sub _receive_item {
    my ($self, $h, $item, @rest) = @_;
    # if we don't has_on_read, got_item can never be called.
    confess 'BUG: receive_item called but there is no on_read'
        unless $self->has_on_read; # but check anyway.

    $self->_call_callback( $self->on_read, $item, @rest );
}

sub _call_callback { # i wonder what this does
    my ($self, $cb, $item, @rest) = @_;
    return $cb->($self, $item, @rest); # who would have guessed!
}

sub push_read {
    my ($self, $cb) = @_;
    weaken $self;
    $self->handle->push_read(sub {
        my ($h, $item, @rest) = @_;
        $self->_call_callback($cb, $item, @rest);
    });
}

sub _subscribe {
    my ($self, $topic) = @_;
    $self->handle->socket->setsockopt(ZMQ_SUBSCRIBE, $topic);
}

sub _unsubscribe {
    my ($self, $topic) = @_;
    $self->handle->socket->setsockopt(ZMQ_UNSUBSCRIBE, $topic);
}

after 'BUILD' => sub {
    my $self = shift;
    $self->_subscribe($_) for $self->topics->members;
};

with 'AnyEvent::ZeroMQ::Handle::Role::Generic',
     'AnyEvent::ZeroMQ::Handle::Role::Readable';

__PACKAGE__->meta->make_immutable;

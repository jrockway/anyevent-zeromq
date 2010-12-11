package AnyEvent::ZeroMQ::Reply;
# ABSTRACT: Non-blocking OO abstraction over ZMQ_REP request/reply sockets
use Moose;
use true;
use namespace::autoclean;
use Scalar::Util qw(weaken);
use ZeroMQ::Raw::Constants qw(ZMQ_REP);

with 'AnyEvent::ZeroMQ::Role::WithHandle' =>
    { socket_type => ZMQ_REP, socket_action => 'connect' };

has 'on_request' => (
    is       => 'ro',
    isa      => 'CodeRef',
    required => 1,
);

sub BUILD {
    my $self = shift;
    my $h = $self->handle;

    weaken $self;
    $h->on_read(sub {
        my ($h, $msg) = @_;
        my $res = $self->on_request->($self, $msg);
        $h->push_write($res);
    });
}

__PACKAGE__->meta->make_immutable;

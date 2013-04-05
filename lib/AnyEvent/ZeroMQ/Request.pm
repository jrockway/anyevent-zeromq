package AnyEvent::ZeroMQ::Request;
# ABSTRACT: Non-blocking OO abstraction over ZMQ_REQ request/reply sockets
use Moose;
use true;
use namespace::autoclean;
use ZMQ::Constants qw(ZMQ_REQ);

with 'AnyEvent::ZeroMQ::Role::WithHandle' =>
    { socket_type => ZMQ_REQ, socket_direction => '' };

sub push_request {
    my ($self, $req, $handler, $hint) = @_;
    if(defined $hint){
        $self->handle->push_read(sub {
            $handler->(@_, $hint);
        });
    }
    else {
        $self->handle->push_read($handler);
    }
    $self->handle->push_write($req);
}

with 'AnyEvent::ZeroMQ::Handle::Role::Generic';

__PACKAGE__->meta->make_immutable;

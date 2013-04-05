package AnyEvent::ZeroMQ::Publish;
# ABSTRACT: Non-blocking OO abstraction over ZMQ_PUB publish/subscribe sockets
use Moose;
use MooseX::Aliases;

use true;
use namespace::autoclean;
use ZMQ::Constants qw(ZMQ_PUB);
use Params::Util qw(_CODELIKE);

with 'AnyEvent::ZeroMQ::Role::WithHandle' =>
    { socket_type => ZMQ_PUB, socket_direction => 'w' },
    'MooseX::Traits';

has '+_trait_namespace' => ( default => 'AnyEvent::ZeroMQ::Publish::Trait' );

sub mangle_message {
    my ($self, $msg, %args) = @_;
    warn 'ignoring unused mangle arguments '. join(', ', map { "'$_'" } keys %args)
        if %args;
    return $msg;
}

sub publish {
    my ($self, $msg, %args) = @_;

    if(_CODELIKE($msg)){ # not to be confused with 'if _CATLIKE($tobias)'
        $self->handle->push_write(sub {
            my $txt = $msg->(@_);
            return $self->mangle_message($txt, %args);
        });
    }
    else {
        $self->handle->push_write($self->mangle_message($msg, %args));
    }
}

alias 'push_write' => 'publish';

with 'AnyEvent::ZeroMQ::Handle::Role::Generic',
     'AnyEvent::ZeroMQ::Handle::Role::Writable';

__PACKAGE__->meta->make_immutable;

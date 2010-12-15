package AnyEvent::ZeroMQ::Publish::Trait::Topics;
# ABSTRACT: trait to prefix a message with a topic
use Moose::Role;
use true;
use namespace::autoclean;

requires 'mangle_message';
around 'mangle_message' => sub {
    my ($orig, $self, $msg, %args) = @_;
    my $topic = delete $args{topic};
    $msg = "$topic$msg" if defined $topic;
    return $self->$orig($msg, %args);
};

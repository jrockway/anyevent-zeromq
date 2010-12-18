package AnyEvent::ZeroMQ::Handle::Role::Readable;
# ABSTRACT: represent a readable socket
use Moose::Role;
use true;
use namespace::autoclean;

requires 'on_read';
requires 'clear_on_read';
requires 'push_read';

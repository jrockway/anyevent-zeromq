package AnyEvent::ZeroMQ::Handle::Role::Readable;
# ABSTRACT: be a readable handle
use Moose::Role;
use true;
use namespace::autoclean;

requires 'on_read';
requires 'clear_on_read';
requires 'has_on_read';
requires 'push_read';

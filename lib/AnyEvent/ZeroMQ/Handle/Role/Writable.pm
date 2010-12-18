package AnyEvent::ZeroMQ::Handle::Role::Writable;
# ABSTRACT: represent a writable socket
use Moose::Role;
use true;
use namespace::autoclean;

requires 'on_drain';
requires 'push_write';

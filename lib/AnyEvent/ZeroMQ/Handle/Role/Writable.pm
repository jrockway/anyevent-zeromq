package AnyEvent::ZeroMQ::Handle::Role::Writable;
# ABSTRACT: be a writable handle
use Moose::Role;
use true;
use namespace::autoclean;

requires 'on_drain';
requires 'clear_on_drain';
requires 'has_on_drain';
requires 'push_write';

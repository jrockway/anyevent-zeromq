package AnyEvent::ZeroMQ::Handle::Role::Generic;
# ABSTRACT: stuff both readable and wrtiable handles do
use Moose::Role;
use true;
use namespace::autoclean;

requires 'on_error';
requires 'clear_on_error';
requires 'has_on_error';
requires 'identity';
requires 'has_identity';
requires 'socket';

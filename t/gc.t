use Test::More;
use Test::Warnings;
use strict;
use warnings;

use ZMQ::FFI;
use ZMQ::FFI::ZMQ2::Context;
use ZMQ::FFI::ZMQ2::Socket;
use ZMQ::FFI::ZMQ3::Context;
use ZMQ::FFI::ZMQ3::Socket;
use ZMQ::FFI::ZMQ4::Context;
use ZMQ::FFI::ZMQ4::Socket;
use ZMQ::FFI::ZMQ4_1::Context;
use ZMQ::FFI::ZMQ4_1::Socket;

use ZMQ::FFI::Constants qw(ZMQ_REQ);
use ZMQ::FFI::Util qw(zmq_version);

my @gc_stack;

# replace with fake methods for testing

no warnings q/redefine/;

my ($major) = zmq_version;

my $context_redefine = qq(*ZMQ::FFI::ZMQ${major}::Context::destroy);
eval $context_redefine.'='.q(
    sub {
        my ($self) = @_;
        $self->context_ptr(-1);
        push @gc_stack, 'destroy'
    };
);

die $@ if $@;


my $socket_redefine = qq(*ZMQ::FFI::ZMQ${major}::Socket::close);
eval $socket_redefine.'='.q(
    sub {
        my ($self) = @_;
        $self->socket_ptr(-1);
        push @gc_stack, 'close'
    };
);

die $@ if $@;

use warnings;

# now run the tests

sub mkcontext {
    my $context = ZMQ::FFI->new();

    mksockets($context);
    return;
}

sub mksockets {
    my ($context) = @_;

    my $s1 = $context->socket(ZMQ_REQ);
    my $s2 = $context->socket(ZMQ_REQ);
    my $s3 = $context->socket(ZMQ_REQ);

    return;
}

mkcontext();

is_deeply
    \@gc_stack,
    ['close', 'close', 'close', 'destroy'],
    q(socket reaped before context);

done_testing;

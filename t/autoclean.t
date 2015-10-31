use Test::More;
use strict;
use warnings;

use ZMQ::FFI;
use ZMQ::FFI::ZMQ2::Context;
use ZMQ::FFI::ZMQ2::Socket;
use ZMQ::FFI::ZMQ3::Context;
use ZMQ::FFI::ZMQ3::Socket;

use ZMQ::FFI::Constants qw(ZMQ_REQ);
use ZMQ::FFI::Util qw(zmq_version);

my @cleanup;

my $major = (zmq_version())[0] == 2 ? 2 : 3;

eval qq{
    no warnings q/redefine/;

    *ZMQ::FFI::ZMQ${major}::Context::destroy = sub {
        push \@cleanup, 'context'
    };

    *ZMQ::FFI::ZMQ${major}::Socket::close = sub {
        push \@cleanup, 'socket'
    };

    use warnings;

} || die $@;

subtest 'autoclean enabled by default' => sub {
    undef @cleanup;

    my $c = ZMQ::FFI->new();
    my $s = $c->socket(ZMQ_REQ);

    undef $s;
    undef $c;

    is_deeply
        \@cleanup,
        ['socket', 'context'],
        q(cleanup done by default);
};

subtest 'autoclean disabled' => sub {
    undef @cleanup;

    my $c = ZMQ::FFI->new( autoclean => 0 );
    my $s = $c->socket(ZMQ_REQ);

    undef $s;
    undef $c;

    is_deeply
        \@cleanup,
        [],
        q(cleanup not done when autoclean disabled);
};

done_testing;

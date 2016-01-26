use strict;
use warnings;

use Test::More;
use Test::Warnings;

use ZMQ::FFI qw(ZMQ_REQ);

#
# Test that we guard against trying to clean up context/sockets
# created in a parent process in forked children
#

my $parent_c = ZMQ::FFI->new();
my $parent_s = $parent_c->socket(ZMQ_REQ);

my $parent_s_closed;
my $parent_c_destroyed;

my ($major, $minor) = $parent_c->version;

my $version = $minor > 0 ? "${major}_${minor}" : $major;

eval qq(
no warnings qw/redefine once/;

*ZMQ::FFI::ZMQ${version}::Socket::zmq_close = sub {
    \$parent_s_closed = 1;
};

*ZMQ::FFI::ZMQ4::Context::zmq_ctx_term = sub {
    \$parent_c_destroyed = 1;
};

use warnings;
);

die $@ if $@;

# no warnings qw/redefine once/;
#
# my $context_redefine = qq(*ZMQ::FFI::ZMQ${version}::Context::zmq_term);
# eval $context_redefine.'='.q(sub { warn "DESTROY"; $parent_c_destroyed = 1 });
# die $@ if $@;
#
# my $socket_redefine = qq(*ZMQ::FFI::ZMQ${version}::Socket::zmq_close);
# eval $socket_redefine.'='.q(sub { warn "CLOSE"; $parent_s_closed = 1 };);
# die $@ if $@;
#
# use warnings;

pid_test();

sub pid_test {
    my $child_pid = open(FROM_CHILDTEST, '-|') // die "fork failed $!";

    if ($child_pid) {
        # parent process, do test assertions here

        my $result;
        read(FROM_CHILDTEST, $result, 128);

        waitpid $child_pid, 0;

        is $result, 'ok',
            'child process skipped parent ctx/socket cleanup';


        ok $parent_c->_pid == $$, "parent context pid _should_ match parent pid";
        ok $parent_s->_pid == $$, "parent socket pid _should_ match parent pid";

        # explicitly undef ctx/socket created in parent to trigger DEMOLISH/
        # cleanup logic.. then verify that close/destroy _was_ called
        # for ctx/socket created in parent

        undef $parent_s;
        undef $parent_c;

        ok $parent_s_closed, "parent socket closed in parent";
        ok $parent_c_destroyed, "parent context destroyed in parent";
    }
    else {
        # check test expectataions and print 'ok' if successful

        if ( $parent_c->_pid == $$ ) {
            print "parent context pid _should not_ match child pid"; exit;
        }

        if ( $parent_s->_pid == $$ ) {
            print "parent socket pid _should not_ match child pid"; exit;
        }

        # explicitly undef ctx/socket cloned from parent to trigger DEMOLISH/
        # cleanup logic.. then verify that close/destroy _was not_ called
        # for ctx/socket created in parent

        undef $parent_s;
        undef $parent_c;

        if ( $parent_s_closed ) {
            print "parent socket closed in child!"; exit;
        }

        if ( $parent_c_destroyed) {
            print "parent context destroyed in child!"; exit;
        }

        print 'ok';
        exit;
    }
}

done_testing;

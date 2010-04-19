#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::TCP;

test_tcp(
    client => sub {
        my $port = shift;
        my $sock = IO::Socket::INET->new(PeerAddr => '127.0.0.1',
                                         PeerPort => $port);
        binmode($sock, ":unix");
        $sock->syswrite('foo');
        sleep 1;
        # XXX: this one fails
        warn $sock->syswrite('foo' x (1024*1024));
    },
    server => sub {
        my $port = shift;
        my $sock = IO::Socket::INET->new(LocalAddr => '127.0.0.1',
                                         LocalPort => $port,
                                         Listen    => 1);
        $sock->accept; # run the client
        my $client = $sock->accept;
        my $buf;
        $client->sysread($buf, 4096);
        is($buf, 'foo', "got the right data");
        $client->close;
        sleep 5;
    },
);

done_testing;

package App::Termcast;
BEGIN {
  $App::Termcast::VERSION = '0.10';
}
use Moose;
# ABSTRACT: broadcast your terminal sessions for remote viewing

with 'MooseX::Getopt::Dashes';

use IO::Pty::Easy;
use IO::Socket::INET;
use Scope::Guard;
use Term::ReadKey;
use Try::Tiny;
use JSON;



has host => (
    is      => 'rw',
    isa     => 'Str',
    default => 'noway.ratry.ru',
    documentation => 'Hostname of the termcast server to connect to',
);


has port => (
    is      => 'rw',
    isa     => 'Int',
    default => 31337,
    documentation => 'Port to connect to on the termcast server',
);


has user => (
    is      => 'rw',
    isa     => 'Str',
    default => sub { $ENV{USER} },
    documentation => 'Username for the termcast server',
);


has password => (
    is      => 'rw',
    isa     => 'Str',
    default => 'asdf', # really unimportant
    documentation => "Password for the termcast server\n"
                   . "                              (mostly unimportant)",
);


has bell_on_watcher => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
    documentation => "Send a terminal bell when a watcher connects\n"
                   . "                              or disconnects",
);


has timeout => (
    is      => 'rw',
    isa     => 'Int',
    default => 5,
    documentation => "Timeout length for the connection to the termcast server",
);

has _got_winch => (
    traits   => ['NoGetopt'],
    is       => 'rw',
    isa      => 'Bool',
    default  => 0,
    init_arg => undef,
);


has establishment_message => (
    traits     => ['NoGetopt'],
    is         => 'ro',
    isa        => 'Str',
    lazy_build => 1,
);

sub _build_establishment_message {
    my $self = shift;
    return sprintf("hello %s %s\n", $self->user, $self->password);
}

sub _termsize {
    return try { GetTerminalSize() } catch { (undef, undef) };
}


sub termsize_message {
    my $self = shift;

    my ($cols, $lines) = $self->_termsize;

    return '' unless $cols && $lines;

    return $self->_form_metadata_string(
        geometry => [ $cols, $lines ],
    );
}

has socket => (
    traits     => ['NoGetopt'],
    is         => 'rw',
    isa        => 'IO::Socket::INET',
    lazy_build => 1,
    init_arg   => undef,
);

sub _form_metadata_string {
    my $self = shift;
    my %data = @_;

    my $json = JSON::encode_json(\%data);

    return "\e[H\x00$json\xff\e[H\e[2J";
}

sub _build_socket {
    my $self = shift;

    my $socket;
    {
        $socket = IO::Socket::INET->new(PeerAddr => $self->host,
                                        PeerPort => $self->port);
        if (!$socket) {
            Carp::carp "Couldn't connect to " . $self->host . ": $!";
            sleep 5;
            redo;
        }
    }

    $socket->syswrite($self->establishment_message . $self->termsize_message);

    # ensure the server accepted our connection info
    # can't use _build_select_args, since that would cause recursion
    {
        my ($rin, $ein, $rout, $eout) = ('') x 4;
        vec($rin, fileno($socket), 1) = 1;
        vec($ein, fileno($socket), 1) = 1;
        my $res = select($rout = $rin, undef, $eout = $ein, undef);
        redo if ($!{EAGAIN} || $!{EINTR}) && $res == -1;
        if (vec($eout, fileno($socket), 1)) {
            Carp::croak("Invalid password");
        }
        elsif (vec($rout, fileno($socket), 1)) {
            my $buf;
            $socket->recv($buf, 4096);
            if (!defined $buf || length $buf == 0) {
                Carp::croak("Invalid password");
            }
            elsif ($buf ne ('hello, ' . $self->user . "\n")) {
                Carp::carp("Unknown login response from server: $buf");
            }
        }
    }

    ReadMode 5 if $self->_raw_mode;
    return $socket;
}

before clear_socket => sub {
    my $self = shift;
    Carp::carp("Lost connection to server ($!), reconnecting...");
    ReadMode 0 if $self->_raw_mode;
};

sub _new_socket {
    my $self = shift;
    $self->clear_socket;
    $self->socket;
}

has pty => (
    traits     => ['NoGetopt'],
    is         => 'rw',
    isa        => 'IO::Pty::Easy',
    lazy_build => 1,
    init_arg   => undef,
);

sub _build_pty {
    IO::Pty::Easy->new(raw => 0);
}

has _raw_mode => (
    traits  => ['NoGetopt'],
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
    trigger => sub {
        my $self = shift;
        my ($val) = @_;
        if ($val) {
            ReadMode 5;
        }
        else {
            ReadMode 0;
        }
    },
);

has _needs_termsize_update => (
    traits  => ['NoGetopt'],
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

sub _build_select_args {
    my $self = shift;
    my @for = @_ ? @_ : (qw(socket pty input));
    my %for = map { $_ => 1 } @for;

    my ($rin, $win, $ein) = ('', '', '');
    if ($for{socket}) {
        my $sockfd = fileno($self->socket);
        vec($rin, $sockfd, 1) = 1;
        vec($win, $sockfd, 1) = 1;
        vec($ein, $sockfd, 1) = 1;
    }
    if ($for{pty}) {
        my $ptyfd  = fileno($self->pty);
        vec($rin, $ptyfd,  1) = 1;
    }
    if ($for{input}) {
        my $infd   = fileno(STDIN);
        vec($rin, $infd   ,1) = 1;
    }

    return ($rin, $win, $ein);
}

sub _socket_ready {
    my $self = shift;
    my ($vec) = @_;
    vec($vec, fileno($self->socket), 1);
}

sub _pty_ready {
    my $self = shift;
    my ($vec) = @_;
    vec($vec, fileno($self->pty), 1);
}

sub _in_ready {
    my $self = shift;
    my ($vec) = @_;
    vec($vec, fileno(STDIN), 1);
}


sub write_to_termcast {
    my $self = shift;
    my ($buf) = @_;

    my ($rin, $win, $ein) = $self->_build_select_args('socket');
    my ($rout, $wout, $eout);
    my $ready = select(undef, $wout = $win, $eout = $ein, $self->timeout);
    if (!$ready || $self->_socket_ready($eout)) {
        $self->clear_socket;
        return $self->write_to_termcast(@_);
    }

    if ($self->_needs_termsize_update) {
        $buf = $self->termsize_message . $buf;
        $self->_needs_termsize_update(0);
    }

    $self->socket->syswrite($buf);
}


sub run {
    my $self = shift;
    my @cmd = @_;

    $self->socket;

    $self->_raw_mode(1);
    my $guard = Scope::Guard->new(sub { $self->_raw_mode(0) });

    $self->pty->spawn(@cmd) || die "Couldn't spawn @cmd: $!";

    local $SIG{WINCH} = sub {
        $self->_got_winch(1);
        $self->pty->slave->clone_winsize_from(\*STDIN);

        $self->pty->kill('WINCH', 1);

        syswrite STDOUT, "\e[H\e[2J"; # for the sake of sending a
                                      # clear to the client anyway

        $self->_needs_termsize_update(1);
    };

    while (1) {
        my ($rin, $win, $ein) = $self->_build_select_args;
        my ($rout, $wout, $eout);
        my $select_res = select($rout = $rin, undef, $eout = $ein, undef);
        my $again = $!{EAGAIN} || $!{EINTR};

        if (($select_res == -1 && $again) || $self->_got_winch) {
            $self->_got_winch(0);
            redo;
        }

        if ($self->_socket_ready($eout)) {
            $self->_new_socket;
        }

        if ($self->_in_ready($rout)) {
            my $buf;
            sysread STDIN, $buf, 4096;
            if (!defined $buf || length $buf == 0) {
                Carp::croak("Error reading from stdin: $!")
                    unless defined $buf;
                last;
            }

            $self->pty->write($buf);
        }

        if ($self->_pty_ready($rout)) {
            my $buf = $self->pty->read(0);
            if (!defined $buf || length $buf == 0) {
                Carp::croak("Error reading from pty: $!")
                    unless defined $buf;
                last;
            }

            syswrite STDOUT, $buf;

            $self->write_to_termcast($buf);
        }

        if ($self->_socket_ready($rout)) {
            my $buf;
            $self->socket->recv($buf, 4096);
            if (!defined $buf || length $buf == 0) {
                if (defined $buf) {
                    $self->_new_socket;
                }
                else {
                    Carp::croak("Error reading from socket: $!");
                }
            }

            if ($self->bell_on_watcher) {
                # something better to do here?
                syswrite STDOUT, "\a";
            }
        }
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;


1;

__END__
=pod

=head1 NAME

App::Termcast - broadcast your terminal sessions for remote viewing

=head1 VERSION

version 0.10

=head1 SYNOPSIS

  my $tc = App::Termcast->new(user => 'foo');
  $tc->run('bash');

=head1 DESCRIPTION

App::Termcast is a client for the L<http://termcast.org/> service, which allows
broadcasting of a terminal session for remote viewing.

=head1 ATTRIBUTES

=head2 host

Server to connect to (defaults to noway.ratry.ru, the host for the termcast.org
service).

=head2 port

Port to use on the termcast server (defaults to 31337).

=head2 user

Username to use (defaults to the local username).

=head2 password

Password for the given user. The password is set the first time that username
connects, and must be the same every subsequent time. It is sent in plaintext
as part of the connection process, so don't use an important password here.
Defaults to 'asdf' since really, a password isn't all that important unless
you're worried about being impersonated.

=head2 bell_on_watcher

Whether or not to send a bell to the terminal when a watcher connects or
disconnects. Defaults to false.

=head2 timeout

How long in seconds to use for the timeout to the termcast server. Defaults to
5.

=head1 METHODS

=head2 establishment_message

Returns the string sent to the termcast server when connecting (typically
containing the username and password)

=head2 termsize_message

Returns the string sent to the termcast server whenever the terminal size
changes.

=head2 write_to_termcast $BUF

Sends C<$BUF> to the termcast server.

=head2 run @ARGV

Runs the given command in the local terminal as though via C<exec>, but streams
all output from that command to the termcast server. The command may be an
interactive program (in fact, this is the most useful case).

=head1 TODO

Use L<MooseX::SimpleConfig> to make configuration easier.

=head1 BUGS

No known bugs.

Please report any bugs through RT: email
C<bug-app-termcast at rt.cpan.org>, or browse to
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=App-Termcast>.

=head1 SEE ALSO

Please see those modules/websites for more information related to this module.

=over 4

=item *

L<http://termcast.org/>

=back

=head1 SUPPORT

You can find this documentation for this module with the perldoc command.

    perldoc App::Termcast

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/App-Termcast>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/App-Termcast>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-Termcast>

=item * Search CPAN

L<http://search.cpan.org/dist/App-Termcast>

=back

=head1 AUTHOR

Jesse Luehrs <doy at tozt dot net>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Jesse Luehrs.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut


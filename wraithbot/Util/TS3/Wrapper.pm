# Copyright 2010-2011 undeadzy (q3urt.undead@gmail.com). All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#    1. Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
#    2. Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY  ``AS IS'' AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
# EVENT SHALL UNDEADZY OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
# OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

package Util::TS3::Wrapper;

use strict;
use warnings;

use Carp;
use Data::Dumper;

use Readonly;
use Net::Telnet;
use Text::Wrap;

use Util::TS3::Commands;

use version 0.77;  our $VERSION = version->declare('v0.0.1');

Readonly my $SERVER     => 'server';
Readonly my $PORT       => 'port';
Readonly my $TS3        => 'ts3';

# XXX NOTE: TS3 has the newline backwards.  It should be \r\n not \n\r
sub new {
    my ($inp, $server, $port) = @_;
    my $class = ref($inp) || $inp;

    my $self = {
	ts3 => Util::TS3::Commands->new({ server => $server, port => $port }),
    };

    bless($self, $class);
    return $self;
}

sub irc_listing {
    my ($self, $virt_server) = @_;

    my $result = $self->get_listing($virt_server);

    my $msg = $self->_get_irc_message($result);

    local($Text::Wrap::columns) = 400;
    my $split_msg = wrap("", "", $msg);
    my @lines = split(/\n/xms, $split_msg);

    return @lines;
}

sub _get_irc_message {
    my ($self, $results) = @_;

    my $string = "";
    for my $id (sort { lc($results->{$a}->{name}) cmp lc($results->{$b}->{name}) } keys(%{$results})) {
	$string .= "[" . $self->_sanitize($results->{$id}->{name}, 30) . ": ";
	my @names;
	for my $player (sort { lc($a->{name}) cmp lc($b->{name}) } @{$results->{$id}->{players}}) {
	    my $n = $self->_sanitize($player->{name}, 15);
	    push(@names, $n . $self->_mute_status($player));
	}
	$string .= join(", ", @names) . "]\n";
    }

    return $string;
}

sub _mute_status {
    my ($self, $player) = @_;

    my $in = $player->{in_mute};
    my $out = $player->{out_mute};

    if ($in) {
	if ($out) {
	    return "[M/M]";
	} else {
	    return "[M]";
	}

    } elsif ($out) {
	return "[/M]";
    }

    return "";
}

sub _sanitize {
    my ($self, $msg, $max_len) = @_;

    $msg =~ s{[^0-9a-zA-Z_,.\@:'"!/ =-]+}{}gxms;

    # Don't allow IRC like commands
    $msg =~ s{^\s*/+}{}gxms;

    return substr($msg, 0, $max_len);
}

# It's a lot more common to know the port than the session id
# so virt_server is the port.
sub get_listing {
    my ($self, $virt_server) = @_;

    if (!defined($virt_server)) {
	$virt_server = 1;
    }

    my $result = {};
    my $res;

    $res = $self->{$TS3}->use_server(undef, $virt_server);
    if ($res->{result}->{id} != 0) {
	return {};
    }

    $res = $self->{$TS3}->client_list({ 'voice' => 1 });
    if ($res->{result}->{id} != 0) {
	return {};
    }

    my %channels;

    foreach my $user (@{$res->{params}}) {
	# Skip any server query clients
	if ($user->{client_type} != 0) {
	    next;
	}
	my $id = $user->{cid};

	if (! exists($channels{$id})) {
	    $channels{$id}->{players} = [];
	}
	push(@{$channels{$id}->{players}}, { name => $user->{client_nickname}, in_mute => $user->{client_input_muted}, out_mute => $user->{client_output_muted} });
    }

    $res = $self->{$TS3}->channel_list();
    if ($res->{result}->{id} != 0) {
	return {};
    }

    foreach my $chan (@{$res->{params}}) {
	my ($id) = $chan->{cid};

	# Don't worry about channels without players
	if (exists($channels{$id})) {
	    $channels{$id}->{name} = $chan->{channel_name};
	}
    }

    $res = $self->{$TS3}->quit();
    if ($res->{result}->{id} != 0) {
	return {};
    }

    return \%channels;
}

1;

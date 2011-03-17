# Copyright 2011 undeadzy (q3urt.undead@gmail.com). All rights reserved.
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

package Quake3::Rcon::Util;

# alias = section name.
#
# [alias]
# host=192.168.0.1
# port=27960
# password=abc
# timeout=5

use strict;
use warnings;

use Config::IniFiles;

use Data::Dumper;
use Readonly;
use Carp qw(cluck);

use version 0.77; our $VERSION = version->declare('v0.0.1');

# XXX Don't commit this file to git of course.
Readonly our $DEFAULT_CONFIG => "$ENV{HOME}/.irssi/rcon.ini";

sub new {
    my ($class) = @_;

    my $self = {
	cfg => $DEFAULT_CONFIG,
	ini => undef,
	rcon => {},
    };

    bless( $self, $class );

    $self->load();
    return $self;
}

sub config {
    my ($self, $val) = @_;

    if (defined($val)) {
	$self->{cfg} = $val;
    }
    return $self->{cfg};
}

sub load {
    my ($self) = @_;

    if (! -f $self->{cfg}) {
	return;
    }

    $self->{ini} = Config::IniFiles->new(-file   => $self->{cfg},
				         -nocase => 1);

    my @rcons = $self->{ini}->Sections();
    for my $info (@rcons) {
	my $cfg = {};

	my $ok = 1;
	for my $sec ('host', 'port', 'password', 'timeout') {
	    $cfg->{$sec} = $self->{ini}->val(lc($info), $sec);
	    if (! defined($cfg->{$sec})) {
		$ok = 0;
	    }
	}
	if ($ok) {
	    $self->{rcon}->{lc($info)} = $cfg;
	}
    }

    $self->{ini}->Delete();

    return 1;
}

sub aliases {
    my ($self) = @_;

    return map { lc($_) } keys(%{$self->{rcon}});
}

sub has_alias {
    my ($self, $alias) = @_;
    return exists($self->{rcon}->{lc($alias)});
}

sub settings {
    my ($self, $alias) = @_;
    if (! exists($self->{rcon}->{lc($alias)})) {
	return undef;
    }
    return $self->{rcon}->{lc($alias)};
}

sub host {
    my ($self, $alias) = @_;
    return $self->_attr($alias, 'host');
}

sub port {
    my ($self, $alias) = @_;
    return $self->_attr($alias, 'port');
}

sub password {
    my ($self, $alias) = @_;
    return $self->_attr($alias, 'password');
}

sub timeout {
    my ($self, $alias) = @_;
    return $self->_attr($alias, 'timeout');
}

sub _attr {
    my ($self, $alias, $attr) = @_;

    if (! exists ($self->{rcon}->{lc($alias)})) {
	return undef;
    }

    return $self->{rcon}->{lc($alias)}->{$attr};
}

1;

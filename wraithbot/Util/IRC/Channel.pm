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

package Util::IRC::Channel;

use strict;
use warnings;

use Carp;

use version 0.77; our $VERSION = version->declare('v0.0.1');

sub new {
    my ( $obclass, $name, $timer, $ops ) = @_;
    my $class = ref($obclass) || $obclass;

    if ( !defined($name) || $name =~ m{^\s*$}xms ) {
        croak qq{Invalid input name};
    }
    if ( !defined($timer) || $timer !~ m{^\d+$}xms ) {
        croak qq{Invalid input timer};
    }
    if ( !defined($ops) || $ops !~ m{^[01]$}xms ) {
        croak qq{Invalid input ops};
    }

    my $self = {
        name  => $name,
        timer => $timer,
        ops   => $ops,
    };

    bless( $self, $class );
    return $self;
}

sub name {
    my ( $self, $val ) = @_;

    if ( defined($val) && $val !~ /^\s*$/xms ) {
        $self->{name} = $val;
    }

    return $self->{name};
}

sub timer {
    my ( $self, $val ) = @_;

    if ( defined($val) && $val =~ /^\d+$/xms ) {
        $self->{timer} = $val;
    }

    return $self->{timer};
}

sub ops {
    my ( $self, $val ) = @_;

    if ( defined($val) && $val =~ /^[01]$/xms ) {
        $self->{ops} = $val;
    }

    return $self->{ops};
}

1;

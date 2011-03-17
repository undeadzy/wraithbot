# Generate rcon commands for the server and send them

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

package Quake3::Rcon;

use strict;
use warnings;

use Data::Dumper;
use Carp qw(cluck);

use Quake3::Rcon::Commands;
use Quake3::Commands::Util;

use version 0.77; our $VERSION = version->declare('v0.0.1');

sub new {
    my ($class) = @_;

    my $self = {};

    bless( $self, $class );
    return $self;
}

sub send_rcon {
    my ( $self, $settings, @commands ) = @_;

    for my $check ('host', 'port', 'timeout', 'password') {
        if (! exists($settings->{$check}) || ! defined($settings->{$check})) {
            print "Invalid data for $check";
            return 0;
        }
    }

    my $socket = Quake3::Commands::Util->send_udp(
        undef,
        $settings->{host},
        $settings->{port},
        Quake3::Rcon::Commands->generate_rcon(
            $settings->{password}, join( q{ }, @commands )
        )
    );
    if ( !defined($socket) || $socket eq q{} ) {
        cluck "Couldn't send the UDP packet";
        return 0;
    }

    my $rin = q{};
    vec( $rin, fileno($socket), 1 ) = 1;

    my ($rout);
    while ( select( $rout = $rin, undef, undef, $settings->{timeout} ) ) {
        my $result = Quake3::Commands::Util->receive_udp($socket);
        if ( !defined($result) || !exists( $result->{data} ) ) {
            cluck "Invalid result received";
            return 0;
        }

        my $msg =
          Quake3::Rcon::Commands->parse_rcon_response( $result->{data} );
        if ( $msg eq q{} ) {
            return 1;
        }
        else {
            cluck "Rcon failed: $msg\n";
            return 0;
        }
    }

    if ( defined($socket) ) {
        if ( !close($socket) ) {
            cluck "Couldn't close the socket";
            return 0;
        }
    }

    # Must have hit a timeout.
    return 0;
}

sub test_me {
    my ($self) = @_;

    cluck "Do nothing for now\n";

    return 1;
}

1;

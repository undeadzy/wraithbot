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

package Quake3::Rcon::Commands;

use strict;
use warnings;

use Data::Dumper;
use Readonly;
use Carp qw(cluck);

use Quake3::Commands;

use version 0.77; our $VERSION = version->declare('v0.0.1');

# You shouldn't need to change these
Readonly our $COMMAND_RCON  => "rcon";
Readonly our $COMMAND_PRINT => "print";

sub new {
    my ($class) = @_;

    my $self = {};

    bless( $self, $class );
    return $self;
}

sub generate_rcon {
    my ( $self, $password, $command ) = @_;

    if ( !defined($password) || !defined($command) ) {
        print "Invalid input to generate_rcon";
        return "";
    }

    return
        $Quake3::Commands::COMMAND_PREFIX
      . $COMMAND_RCON . q{ "}
      . $password . q{" }
      . $command . "\n";
}

sub parse_rcon {
    my ( $self, $text ) = @_;

    if ( !defined($text) ) {
        return {};
    }

    my $prefix = $Quake3::Commands::COMMAND_PREFIX . $COMMAND_RCON;
    if ( $text =~ m{^${prefix}\s+"?(\S+)"?\s+(\S+)\s*(.*)$}ixms ) {
        return {
            command  => $COMMAND_RCON,
            password => $1,
            type     => $2,
            args     => $3
        };
    }

    return {};
}

sub parse_rcon_response {
    my ( $self, $text ) = @_;

    if ( !defined($text) ) {
        return "No input text";
    }

    # See code/server/sv_main.c in the function SVC_RemoteCommand
    my $prefix = $Quake3::Commands::COMMAND_PREFIX . $COMMAND_PRINT;
    if ( $text eq qq{${prefix}\nNo rconpassword set on the server.\n} ) {
        return "No rconpassword set on the server.";

    }
    elsif ( $text eq qq{${prefix}\nBad rconpassword.\n} ) {
        return "Bad rcon password.";
    }

    return "";
}

sub test_me {
    my ($self) = @_;

    my $orig = qq{\xff\xff\xff\xff${COMMAND_RCON} map ut4_turnpike\n};
    my $val  = $self->parse_rcon($orig);
    print Dumper( $orig, $val );

    my $password = "test";
    print Dumper( $self->generate_rcon( $password, "map_restart" ) );

    return 1;
}

1;

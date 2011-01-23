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

package Util::TS3::Auth;

use strict;
use warnings;

use Readonly;

use version 0.77; our $VERSION = version->declare('v0.0.1');

Readonly my $SERVER     => 'server';
Readonly my $PORT       => 'port';
Readonly my $FLOOD_TIME => 'flood_time';
Readonly my $FLOOD_CMDS => 'flood_cmds';

# Util::TS3::Auth->new({ server => 'name', [ port => 10011, [ flood_time => 3, [ flood_cmds => 10 ]]] });
sub new {
    my ( $inp, @args ) = @_;
    my $class = ref($inp) || $inp;

    if ( scalar(@args) < 1 ) {
        confess qq{Must supply at least the server and optionally port};
    }

    my $self = {
        server => $args->{$SERVER},
        port   => exists( $args->{$PORT} ) ? $args->{$PORT} : 10011,

        # SERVERINSTANCE_SERVERQUERY_FLOOD_COMMANDS
        flood_cmds => exists( $args->{$FLOOD_CMDS} )
        ? $args->{$FLOOD_CMDS}
        : 10,

        # SERVERINSTANCE_SERVERQUERY_FLOOD_TIME
        flood_time => exists( $args->{$FLOOD_TIME} ) ? $args->{$FLOOD_TIME} : 3,
    };

    if ( !defined( $self->{$SERVER} ) ) {
        confess qq{Must supply a server};
    }
    foreach my $check qw($PORT $FLOOD_TIME $FLOOD_CMDS) {
        if ( $self->{$check} !~ /^\d+$/xms ) {
            confess qq{Must supply a numeric $check};
        }
    }

    bless( $self, $class );
    return $self;
}

1;

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

package Util::Fortune;

use strict;
use warnings;

use Util::IRC::Format;

use Carp qw(cluck);
use IPC::System::Simple qw(capturex);

use Readonly;

use version 0.77; our $VERSION = version->declare('v0.0.1');

# You shouldn't need to change these
Readonly our $FORTUNE_COMMAND   => '/usr/games/fortune';
Readonly our $FORTUNE_SHORT     => '-s';
Readonly our $FORTUNE_OFFENSIVE => '-o';

my $FMT = Util::IRC::Format->new();

sub new {
    my ($class) = @_;

    my $self = {};

    bless( $self, $class );
    return $self;
}

sub fortune {
    my ( $class, $off ) = @_;
    if ( !defined($off) ) {
        $off = 0;
    }

    my @output;
    eval {
        if ( !-f $FORTUNE_COMMAND )
        {
            @output = ('fortune: command not found');

        }
        elsif ($off) {
            @output =
              capturex( [0], $FORTUNE_COMMAND, $FORTUNE_SHORT,
                $FORTUNE_OFFENSIVE );

        }
        else {
            @output = capturex( [0], $FORTUNE_COMMAND, $FORTUNE_SHORT );
        }
    } || return ("fortune: command failed");

    # Make sure none of the fortune lines start with / to avoid complications
    # The rest of the filtering is done by whoever prints this
    foreach my $line (@output) {
        $line =~ s{^(\s*)/+}{$1}gxms;
        $line = $FMT->plaintext_filter($line);
    }

    return @output;
}

1;

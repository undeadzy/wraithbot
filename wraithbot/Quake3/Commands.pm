# This is a quake3 status / status response.
#
# It only handles parsing and generating the messages.
# Another class will send it.
#
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

package Quake3::Commands;

use strict;
use warnings;

use Util::IRC::Format;

use Data::Dumper;
use Readonly;
use Carp qw(cluck);

use version 0.77; our $VERSION = version->declare('v0.0.1');

# You shouldn't need to change these
Readonly our $COMMAND_PREFIX          => "\xff\xff\xff\xff";
Readonly our $COMMAND_GET_STATUS      => "getStatus";
Readonly our $COMMAND_STATUS_RESPONSE => "statusResponse";

my $FMT = Util::IRC::Format->new();

sub new {
    my ($class) = @_;

    my $self = {};

    bless( $self, $class );
    return $self;
}

sub parse_status_response {
    my ( $self, $text ) = @_;

    if ( !defined($text) ) {
        cluck "ERROR: Text was not defined";
        return {};
    }

    my @lines = split( /\n/mxs, $text );
    if ( scalar(@lines) < 2 ) {
        cluck "Must find at least two lines: command and settings";
        return {};
    }

    my $command = shift(@lines);
    if ( $command ne $COMMAND_PREFIX . $COMMAND_STATUS_RESPONSE ) {
        cluck "Invalid status response: $command";
        return {};
    }

    my @tmp = split( q{\\\\}, shift(@lines) );
    shift(@tmp);
    if ( scalar(@tmp) % 2 != 0 ) {
        cluck "tmp didn't have an even number of entries";
        return {};
    }
    for my $i (0 .. $#tmp) {
	$tmp[$i] = $FMT->plaintext_filter($tmp[$i]);
    }

    my %settings = @tmp;

    # I use some of these so make sure they are valid.
    my @keys = keys(%settings);
    my ($maxclients)     = grep { /^sv_maxclients$/ixms } @keys;
    my ($privateclients) = grep { /^sv_privateclients$/ixms } @keys;
    my ($mapname)        = grep { /^mapname$/ixms } @keys;

    # Make sure we have the name
    if ( !defined($maxclients) ) {
        $maxclients = "sv_maxclients";
        $settings{$maxclients} = 0;

    }
    elsif ( $settings{$maxclients} !~ /^\d+$/ixms ) {
        $settings{$maxclients} = 0;
    }

    if ( !defined($privateclients) ) {
        $privateclients = "sv_privateclients";
        $settings{$privateclients} = 0;

    }
    elsif ( $settings{$privateclients} !~ /^\d+$/ixms ) {
        $settings{$privateclients} = 0;
    }

    if ( !defined($mapname) ) {
        $mapname = "mapname";
        $settings{$mapname} = "";

    }
    elsif ( $settings{$mapname} !~ /^[a-zA-Z0-9_]+$/ixms ) {
        $settings{$mapname} = "";
    }

    my @players;
    foreach my $line (@lines) {
        if ( $line =~ m{^(-?\d+)\s+(\d+)\s+"([^"]*)"\s*$}ixms ) {
            push( @players, { score => $1, ping => $2, name => $3 } );

        }
        else {
            cluck "Invalid line: $line";
            return {};
        }
    }

    return {
        command  => $command,
        settings => \%settings,
        players  => \@players
    };
}

sub generate_status_response {
    my ( $self, $settings ) = @_;

    if ( !defined($settings) || ref($settings) ne 'HASH' ) {
        cluck "Invalid settings: undef or not a hash";
        return "";
    }

    my $msg = "";
    if ( exists( $settings->{command} )
        && $settings->{command} eq $COMMAND_STATUS_RESPONSE )
    {
        $msg = $COMMAND_PREFIX . $settings->{command} . "\n";

    }
    else {
        cluck "Couldn't find the correct command in the settings";
        return "";
    }

    while ( my ( $k, $v ) = each %{ $settings->{settings} } ) {
        $msg .= "\\$k\\$v";
    }
    $msg .= "\n";

    foreach my $p ( @{ $settings->{players} } ) {
        $msg .= $p->{score} . " " . $p->{ping} . q{ "} . $p->{name} . qq{"\n};
    }

    return $msg;
}

sub generate_get_status {
    my ($self) = @_;

    return $COMMAND_PREFIX . $COMMAND_GET_STATUS . "\n";
}

sub parse_get_status {
    my ( $self, $text ) = @_;

    if ( !defined($text) ) {
        cluck "Text is undefined";
        return {};
    }

    if ( $text eq $COMMAND_PREFIX . $COMMAND_GET_STATUS . "\n" ) {
        return { command => $COMMAND_GET_STATUS };
    }

    cluck "Unexpected text";
    return {};
}

sub test_me {
    my ($self) = @_;

    my $orig =
qq{\xff\xff\xff\xffstatusResponse\n\\cvar\\cval\\g_allowvote\\1\n24 0 "hello"\n42 25 "real"\n24 0 "bot"\n};
    my $val = $self->parse_status_response(
qq{\xff\xff\xff\xffstatusResponse\n\\cvar\\cval\\g_allowvote\\1\n24 0 "hello"\n42 25 "real"\n24 0 "bot"\n}
    );
    print Dumper( $orig, $val );

    my $new_val = {
        command  => "statusResponse",
        settings => { "cvar" => "cval", "g_allowvote" => "1" },
        players  => [
            { score => 24, ping => 0,  name => "hello" },
            { score => 42, ping => 25, name => "real" },
            { score => 24, ping => 0,  name => "bot" }
        ]
    };
    print Dumper( $self->generate_status_response($new_val) );

    return 1;
}

1;

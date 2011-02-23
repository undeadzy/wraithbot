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

package Quake3::Commands::Util::UrbanTerror;

use strict;
use warnings;
use Carp qw(cluck);

use Socket;
use Data::Dumper;
use Readonly;

use Util::IRC::Format;

use version 0.77; our $VERSION = version->declare('v0.0.1');

# Inherit from Quake3::Commands::Util and override get_player_description and get_game_type
use base 'Quake3::Commands::Util';

Readonly our $GAME_TYPE => {
    FFA  => 0,
    TDM  => 3,
    TS   => 4,
    FTL  => 5,
    CAH  => 6,
    CTF  => 7,
    BOMB => 8,
};

Readonly our $TYPE_GAME => {
    0 => 'FFA',
    3 => 'TDM',
    4 => 'TS',
    5 => 'FTL',
    6 => 'CAH',
    7 => 'CTF',
    8 => 'BOMB',
};

Readonly our $CVAR_MIN_SKILL   => 'minskill';
Readonly our $CVAR_SV_HOSTNAME => 'sv_hostname';

my $FMT = Util::IRC::Format->new();

sub new {
    my ( $check, @args ) = @_;
    my $class = ref($check) || $check;

    my $self = {
        clans => {},
        file  => $args[0],
    };

    bless( $self, $class );

    $self->reload_clans();
    return $self;
}

sub reload_clans {
    my ( $self, $file ) = @_;
    my $target;

    if ( defined($file) ) {
        $target = $file;
    }
    else {
        $target = $self->{file};
    }

    if ( !-f $target ) {
        cluck qq{Couldn't load "$target": $!};
        return 0;
    }

    my ( $fh, @lines );
    if ( !open( $fh, '<', $target ) ) {
        cluck qq{Couldn't load "$target": $!};
        return 0;

    }
    else {
        @lines = <$fh>;
        if ( !close($fh) ) {
            cluck qq{Couldn't close "$target": $!};
            return 0;
        }
    }

    $self->{clans} = {};

    for my $line (@lines) {
        chomp($line);

        if ( $line =~ m{^\s*(\#.*)?$}ixms ) {

            # Skip comments

        }
        elsif ( $line =~ m{^\s*(.+)\t+(.+)\s*$}ixms ) {
            my ( $name, $regex ) = ( $1, $2 );

            $name = $FMT->plaintext_filter($name);
            $name =~ s{^\s+}{}xms;
            $name =~ s{\s+$}{}xms;

            $regex = $FMT->plaintext_filter($regex);
            $regex =~ s{\s+$}{}xms;
            $regex =~ s{^\s+}{}xms;

            $self->{clans}->{$name} = qr{$regex}xms;

        }
        else {
            print "Unrecognized line: $line";
        }
    }

    return 1;
}

sub get_game_type {
    my ( $self, $settings ) = @_;

    if ( !exists( $settings->{settings} ) ) {
        cluck "Couldn't find settings";
        return "N/A";
    }

    my @keys = keys( %{ $settings->{settings} } );

    my $name = $Quake3::Commands::Util::CVAR_GAME_TYPE;
    my ($gametype) = grep { /^${name}$/ixms } @keys;
    if ( !defined($gametype) || $gametype eq "" ) {
        cluck "Couldn't find the game type setting";
        return "";
    }

    my $value = $settings->{settings}->{$gametype};
    if ( defined($value) && $value =~ /^\d+$/ixms ) {
        if ( exists( $TYPE_GAME->{$value} ) ) {
            return $TYPE_GAME->{$value};

        }
        else {
            return $value;
        }

    }
    else {
        cluck "Couldn't find the game type";
        return "";
    }
}

sub get_min_skill {
    my ( $self, $settings ) = @_;

    if ( !exists( $settings->{settings} ) ) {
        cluck "Couldn't find settings";
        return "N/A";
    }

    my @keys = keys( %{ $settings->{settings} } );
    my ($min_skill) = grep { /^${CVAR_MIN_SKILL}$/ixms } @keys;

    if ( defined($min_skill) && exists( $settings->{settings}->{$min_skill} ) )
    {
        my $value = $settings->{settings}->{$min_skill};
        if ( defined($value) && $value =~ /^\d{1,10}$/ixms ) {
            return $value;
        }
    }

    return 0;
}

sub get_avg_skill {
    my ( $self, $settings ) = @_;

    if ( !exists( $settings->{settings} ) ) {
        cluck "Couldn't find settings";
        return "N/A";
    }

    my @keys = keys( %{ $settings->{settings} } );
    my ($sv_hostname) = grep { /^${CVAR_SV_HOSTNAME}$/ixms } @keys;

    if ( defined($sv_hostname)
        && exists( $settings->{settings}->{$sv_hostname} ) )
    {
        my $value = $settings->{settings}->{$sv_hostname};

    # It would be nice if these were cvars.  It's only in the title currently...
        if ( defined($value)
            && $value =~
m{^\s*Z\^\d\s+Best\s+\^\dof\s+\^\dZ\^\d\s+(?:\S+)\s+\^\d(\d+)\s*$}ixms
          )
        {
            return $1;

        }
        elsif ( defined($value)
            && $value =~
            m{^\s*\^\dWest\s+\^\dof\s+\^\dZ\^\d\s+(?:\S+)\s+\^\d(\d+)\s*$}ixms )
        {
            return $1;
        }
    }

    return 0;
}

sub get_player_description {
    my ( $self, $settings ) = @_;

    if (  !defined($settings)
        || ref($settings) ne 'HASH'
        || !exists( $settings->{players} ) )
    {
        cluck "Couldn't find players";
        return "N/A";
    }

    my %results;
    foreach my $p ( sort { lc($a) cmp lc($b) } @{ $settings->{players} } ) {
        if ( $p->{ping} <= 3 ) {
            if ( !exists( $results{bots} ) ) {
                $results{bots} = 0;
            }
            $results{bots}++;
            next;
        }

        while ( my ( $k, $v ) = each %{ $self->{clans} } ) {

            # Remove colors like ^4 and ^7
            my $tmp = $p->{name};
            $tmp =~ s{\^(\d|[FfbBnNXx])}{}gxms;
            $tmp = $FMT->plaintext_filter($tmp);

            if ( $tmp =~ m{$v}xms ) {
                if ( !exists( $results{$k} ) ) {
                    $results{$k} = 0;
                }
                $results{$k}++;
            }
        }
    }

    my @msgs;
    my $min_skill = $self->get_min_skill($settings);
    if ( $min_skill > 0 ) {
        push( @msgs, q{[minSkill=} . ${min_skill} . q{]} );
    }

    my $avg_skill = $self->get_avg_skill($settings);
    if ( $avg_skill > 0 ) {
        push( @msgs, q{[avgSkill=} . ${avg_skill} . q{]} );
    }

    foreach my $clan ( sort( keys(%results) ) ) {
        if ( $clan eq 'bots' ) {
            if ( $results{$clan} == 1 ) {
                push( @msgs, "$results{$clan} bot" );

            }
            else {
                push( @msgs, "$results{$clan} bots" );
            }

        }
        else {
            push( @msgs, "$results{$clan} $clan" );
        }
    }

    return join( ", ", @msgs );
}

sub test_me {
    my ($self) = @_;

    my $settings = {
        players => [
            { ping => 0,   score => 24, name => "iamabot" },
            { ping => 0,   score => 24, name => "iamabot2" },
            { ping => 100, score => 22, name => "human" },
        ],
    };

    my $result = $self->get_player_description($settings);
    print Dumper( $settings, $result );

    # Now test inherited methods
    my $servers = {
        "206.217.142.38:27960" => { name => "iCu* private" },
        "74.207.235.61:27961"  => { name => "UrT East" },

        #    "72.26.196.178:27960"  => { name => "Best of the Best" },
        "64.156.192.169:27963" => { name => "wTf San Diego" },
        "8.6.15.92:27960"      => { name => "Spray and Pray" },
    };
    return $self->print_servers($servers);
}

1;

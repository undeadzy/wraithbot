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

package Util::IRC::Auth;

use strict;
use warnings;

use Readonly;

use Util::IRC::Channel;

use version 0.77; our $VERSION = version->declare('v0.0.1');

# Top level keys in the user object
Readonly my $PRIVATE => "private";
Readonly my $PUBLIC  => "public";
Readonly my $USERS   => "users";
Readonly my $PM      => "pm";
Readonly my $DELAY   => "delay";

sub new {
    my ( $obclass, $args ) = @_;
    my $class = ref($obclass) || $obclass;

    my $self = {
        "$PRIVATE" => {},
        "$PUBLIC"  => {},
        "$USERS"   => {},

        # Make sure we can use it immediately
        "$PM" => time(),

        "$DELAY" => defined( $args->{$DELAY} )
          && $args->{$DELAY} ? $args->{$DELAY} : 0,
    };

    bless( $self, $class );
    return $self;
}

sub add_private_channel {
    my ( $self, $name, $ops ) = @_;

    $self->{$PRIVATE}->{$name} = Util::IRC::Channel->new( $name, time(), $ops );
    return 1;
}

sub add_public_channel {
    my ( $self, $name, $ops ) = @_;

    $self->{$PUBLIC}->{$name} = Util::IRC::Channel->new( $name, time(), $ops );
    return 1;
}

sub add_user {
    my ( $self, $name, $mask ) = @_;

    if ( !defined($name) || $name =~ /^\s*$/xms ) {
        print "Name is invalid\n";
        return 0;
    }
    if ( !defined($mask) || $mask !~ /^.*\@.*$/xms ) {
        print "Name is invalid\n";
        return 0;
    }

    $self->{$USERS}->{$name} = $mask;
    return 1;
}

# Whether the bot should listen for commands in this channel.
sub authorized_channel {
    my ( $self, $chan_name ) = @_;

    if ( !defined($chan_name) || $chan_name !~ /^\#/xms ) {
        return 0;
    }

    foreach my $c (
        sort( keys( %{ $self->{$PRIVATE} } ), keys( %{ $self->{$PUBLIC} } ) ) )
    {
        if ( lc($c) eq lc($chan_name) ) {
            return 1;
        }
    }

    if ( lc($chan_name) eq 'pm' ) {
        return 1;
    }

    return 0;
}

sub known_user {
    my ( $self, $server, $nick, $mask ) = @_;

    if ( !defined($server) || !defined($nick) || !defined($mask) ) {
        print "Invalid arguments\n";
        return 0;
    }

    if ( $self->user_in_private( $server, $nick, $mask ) ) {
        return 1;
    }

    if ( $self->user_someop_in_public( $server, $nick, $mask ) ) {
        return 1;
    }

    if ( $self->user_is_privileged( $server, $nick, $mask ) ) {
        return 1;
    }

    return 0;
}

# Either in the private channel or an op in the public channel
#
# Note that the bot must be in any channel to get information about the members.
sub trusted_user {
    my ( $self, $server, $nick, $mask ) = @_;

    if ( !defined($server) || !defined($nick) || !defined($mask) ) {
        print "Invalid arguments\n";
        return 0;
    }

    if ( $self->user_in_private( $server, $nick, $mask ) ) {
        return 1;
    }

    if ( $self->user_op_in_public( $server, $nick, $mask ) ) {
        return 1;
    }

    if ( $self->user_is_privileged( $server, $nick, $mask ) ) {
        return 1;
    }

    return 0;
}

# Find a given user (server, nick, mask) in a list of channels
#
# Note that the bot must be in any channel to get information about the members.
sub find_user_in_channels {
    my ( $self, $server, $nick, $mask, @channels ) = @_;

    if ( !defined($server) || !defined($nick) || !defined($mask) ) {
        print "Invalid arguments\n";
        return 0;
    }

    my @matches;
    foreach my $c (@channels) {

        # Only allow ops in the public channel(s)
        my $chan_ref = $server->channel_find($c);
        if ( !defined($chan_ref) ) {
            next;
        }

        # I can't just use $chan_ref->find_nick() in case of a netsplit?
        # I can't juse use the mask because people can have multiple clients
        my @nicks = $chan_ref->nicks();
        foreach my $n (@nicks) {
            if (   exists( $n->{nick} )
                && exists( $n->{host} )
                && $n->{nick} eq $nick
                && $n->{host} eq $mask )
            {
                push( @matches, [ $c, $n ] );
            }
        }
    }

    return @matches;
}

# Whether the user is in a private channel
sub user_in_private {
    my ( $self, $server, $nick, $mask ) = @_;

    if ( !defined($server) || !defined($nick) || !defined($mask) ) {
        print "Invalid arguments\n";
        return 0;
    }

    my @filtered;
    while ( my ( $k, $v ) = each %{ $self->{$PRIVATE} } ) {
        if ( exists( $v->{ops} ) && $v->{ops} ) {
            push( @filtered, $k );
        }
    }

    my @matches =
      $self->find_user_in_channels( $server, $nick, $mask, @filtered );
    return scalar(@matches) > 0;
}

# Whether the user is always able to use the bot
sub user_is_privileged {
    my ( $self, $server, $nick, $mask ) = @_;

    if ( !defined($server) || !defined($nick) || !defined($mask) ) {
        print "Invalid arguments\n";
        return 0;
    }

    foreach my $entry ( keys( %{ $self->{$USERS} } ) ) {
        if (   lc($entry) eq lc($nick)
            && lc($mask) eq lc( $self->{$USERS}->{$entry} ) )
        {
            return 1;
        }
    }

    return 0;
}

# Whether the user is an op in the public channel
sub user_op_in_public {
    my ( $self, $server, $nick, $mask ) = @_;

    return $self->user_public_status(
        $server, $nick, $mask,
        sub {
            my ($nick_ref) = @_;

            # Since this is a public channel, require ops
            if ( !exists( $nick_ref->{op} ) || !$nick_ref->{op} ) {
                return 0;
            }
            return 1;
        }
    );
}

sub user_halfop_in_public {
    my ( $self, $server, $nick, $mask ) = @_;

    return $self->user_public_status(
        $server, $nick, $mask,
        sub {
            my ($nick_ref) = @_;

            # Since this is a public channel, require ops
            if ( !exists( $nick_ref->{halfop} ) || !$nick_ref->{halfop} ) {
                return 0;
            }
            return 1;
        }
    );
}

sub user_someop_in_public {
    my ( $self, $server, $nick, $mask ) = @_;

    return $self->user_public_status(
        $server, $nick, $mask,
        sub {
            my ($nick_ref) = @_;
            if (   ( !exists( $nick_ref->{op} ) || !$nick_ref->{op} )
                && ( !exists( $nick_ref->{halfop} ) || !$nick_ref->{halfop} ) )
            {
                return 0;
            }
            return 1;
        }
    );
}

sub user_public_status {
    my ( $self, $server, $nick, $mask, $sub_check ) = @_;

    if ( !defined($server) || !defined($nick) || !defined($mask) ) {
        print "Invalid arguments\n";
        return 0;
    }

    my @filtered;
    while ( my ( $k, $v ) = each %{ $self->{$PUBLIC} } ) {
        if ( exists( $v->{ops} ) && $v->{ops} ) {
            push( @filtered, $k );
        }
    }

    my @matches =
      $self->find_user_in_channels( $server, $nick, $mask, @filtered );
    foreach my $m (@matches) {
        my ( $channel_name, $nick_ref ) = @{$m};

        # Since this is a public channel, require ops
        if ( !$sub_check->($nick_ref) ) {
            next;
        }

        return 1;
    }

    return 0;
}

sub user_is_spamming {
    my ( $self, $server, $nick, $mask, $channel ) = @_;

    if (   !defined($server)
        || !defined($nick)
        || !defined($mask)
        || !defined($channel) )
    {
        print "Invalid arguments\n";
        return 1;
    }

    # Allow trusted users to PM as quickly as they want
    if ( exists($self->{$USERS}->{$nick}) && $self->{$USERS}->{$nick} eq $mask ) {
        return 0;
    }

    # Allow people to send PMs quickly
    if ( lc($channel) eq lc($PM) || $channel !~ m{^\#}msx ) {
        if ( $self->{$PM} + $self->{$DELAY} >= time() ) {
            return 1;
        }
        $self->{$PM} = time();
        return 0;
    }

    # This is too much work and it isn't worth it.
    #    if (! $self->known_user($server, $nick, $mask)) {
    #	# Assume unknown users are spamming
    #	return 1;
    #    }

    if ( exists( $self->{$PRIVATE}->{ lc($channel) } ) ) {
        if ( $self->{$PRIVATE}->{ lc($channel) }->timer() + $self->{$DELAY} >=
            time() )
        {
            return 1;
        }
        $self->{$PRIVATE}->{ lc($channel) }->timer( time() );
        return 0;
    }
    if ( exists( $self->{$PUBLIC}->{ lc($channel) } ) ) {
        if ( $self->{$PUBLIC}->{ lc($channel) }->timer() + $self->{$DELAY} >=
            time() )
        {
            return 1;
        }
        $self->{$PUBLIC}->{ lc($channel) }->timer( time() );
        return 0;
    }

    return 1;
}

1;

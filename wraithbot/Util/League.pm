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

package Util::League;

use strict;
use warnings;
use Config::IniFiles;
use DateTime;
use DateTime::Format::Natural;
use Data::Dumper;

use Readonly;

use version 0.77; our $VERSION = version->declare('v0.0.1');

Readonly our $CONFIG => "$ENV{HOME}/.irssi/scripts/wraithbot/conf/leagues.ini";

sub new {
    my $class = shift;
    my ($args) = @_;

    my $self = {
        cfg => (defined($args) && exists($args->{config}) ? $args->{config} : $CONFIG),
    };
    bless( $self, $class );

    $self->load($self->{cfg});
    return $self;
}

sub load {
    my ($self, $cfg) = @_;
    if (! defined($cfg)) {
        $cfg = $CONFIG;
    }
    if (! -f $cfg) {
        print "Couldn't find the config: $cfg";
        return;
    }

    my $ini = Config::IniFiles->new(-file   => $cfg,
                                    -nocase => 1);

    my @leagues = $ini->Sections();
    for my $shortname (@leagues) {
        my $cfg = {};

        my $ok = 1;
        for my $sec qw(full_name url active timezone rules irc) {
            $cfg->{$sec} = $ini->val(lc($shortname), $sec);
            if (! defined($cfg->{$sec})) {
                $ok = 0;
            }
        }

        my @params = $ini->Parameters(lc($shortname));
        $cfg->{matches} = {};
        for my $p (@params) {
            if ($p !~ /^game_/ixms) {
                next;
            }
            my $game_name = $p;
            $game_name =~ s{^game_}{};
            $cfg->{matches}->{lc($game_name)} = $ini->val(lc($shortname), $p);
        }
        if ($ok) {
            $self->{league}->{lc($shortname)} = $cfg;
        }
    }
    $ini->Delete();

    return 1;
}

sub names {
    my ($self) = @_;
    return sort(keys(%{$self->{league}}));
}

sub full_name {
    my ($self, $name) = @_;
    return $self->_get_attribute($name, 'full_name');
}

sub url {
    my ($self, $name) = @_;
    return $self->_get_attribute($name, 'url');
}

sub active {
    my ($self, $name) = @_;
    my $act = $self->_get_attribute($name, 'active');
    if ($act =~ m{^\s*(0|y|yes)\s*$}ixms) {
        return 1;
    } else {
        return 0;
    }
}

sub timezone {
    my ($self, $name) = @_;
    return $self->_get_attribute($name, 'timezone');
}

sub rules {
    my ($self, $name) = @_;
    return $self->_get_attribute($name, 'rules');
}

sub irc {
    my ($self, $name) = @_;
    return $self->_get_attribute($name, 'irc');
}

sub match {
    my ($self, $name, $type) = @_;
    my $m = $self->_get_attribute($name, 'matches');
    $type = lc($type);
    if (ref($m) eq 'HASH' && exists($m->{$type})) {
        return $m->{$type};
    } else {
        return "Invalid match type for given league";
    }
}

sub _get_attribute {
    my ($self, $name, $attr) = @_;

    $name = lc($name);
    $attr = lc($attr); 
    if (! exists($self->{league}->{$name})) {
        return "Invalid league";
    }
    if (! exists($self->{league}->{$name}->{$attr})) {
        return "Invalid $attr for the given league";
    }
    return $self->{league}->{$name}->{$attr};
}

sub current_time {
    my ($self, $name) = @_;

    $name = lc($name);
    if (! exists($self->{league}->{$name})) {
        return "Invalid league";
    }

    my $now = DateTime->now(time_zone => $self->timezone($name));
    return uc($name) . " time (" . $self->timezone($name) . ") is: " . $now;
}

sub next_match {
    my ($self, $name, $type) = @_;

    $name = lc($name);
    if (! exists($self->{league}->{$name})) {
        return "Invalid league";
    }
    if (! $self->active($name)) {
        return uc($name) . " league is not active currently";
    }

    $type = lc($type);
    if (! exists($self->{league}->{$name}->{matches}->{$type})) {
        return "Invalid game type for given league";
    }

    my $now = DateTime->now(time_zone => $self->timezone($name));
    my $fmt = DateTime::Format::Natural->new(time_zone => $self->timezone($name));
    my $game  = $fmt->parse_datetime($self->match($name, $type));
    my $game_diff = $game - $now;

    if ( $game_diff->in_units('days') >= 6
	 && $game_diff->days >= 6 && $game_diff->hours >= 22 ) {
	return "Current " . uc($name) . " " . uc($type) . " matches are in progress!";

    } else {
	return "Next " . uc($name) . " " . uc($type) . " match is in "
               . $game_diff->days    . " " . ($game_diff->days == 1 ? "day" : "days") . ", "
               . $game_diff->hours   . " " . ($game_diff->hours == 1 ? "hour" : "hours") . ", "
               . $game_diff->minutes . " " . ($game_diff->minutes == 1 ? "minute" : "minutes");
    }
}

sub next_matches {
    my ($self, $name) = @_;

    $name = lc($name);
    if (! exists($self->{league}->{$name})) {
        return "Invalid league";
    }
    if (! $self->active($name)) {
        return uc($name) . " league is not active currently";
    }

    my @matches;
    for my $type (sort(keys(%{$self->{league}->{$name}->{matches}}))) {
        push(@matches, $self->next_match($name, $type));
    }

    return @matches;
}

1;

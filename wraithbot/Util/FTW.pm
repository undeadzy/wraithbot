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

package Util::FTW;

use strict;
use warnings;
use DateTime;
use DateTime::Format::Natural;

use Readonly;

use version 0.77; our $VERSION = version->declare('v0.0.1');

# You shouldn't need to change these
Readonly our $TIME_ZONE  => 'America/New_York';
Readonly our $TS_MATCH   => "Next Tuesday at 21:30";
Readonly our $CTF_MATCH  => "Next Sunday at 21:30";

sub new {
    my ($class) = @_;

    my $self = {
	fmt => DateTime::Format::Natural->new(time_zone => $TIME_ZONE),
    };

    bless( $self, $class );
    return $self;
}

sub current_time {
    my ($self) = @_;

    my $now = DateTime->now(time_zone => $TIME_ZONE);
    return "FTWGL time (America/New_York) is: " . $now;
}

sub next_ts {
    my ($self) = @_;

    my $now = DateTime->now(time_zone => $TIME_ZONE);
    my $ts  = $self->{fmt}->parse_datetime($TS_MATCH);
    my $ts_diff = $ts - $now;

    if ( $ts_diff->in_units('days') >= 6
	 && $ts_diff->days >= 6 && $ts_diff->hours >= 22 ) {
	return "Current TS matches have been in progress since 9:30pm!";
    } else {
	return "Next FTWGL TS match is in " . $ts_diff->days . " days, " . $ts_diff->hours . " hours, " . $ts_diff->minutes . " minutes";
    }
}

sub next_ctf {
    my ($self) = @_;

    my $now = DateTime->now(time_zone => $TIME_ZONE);
    my $ctf = $self->{fmt}->parse_datetime($CTF_MATCH);
    my $ctf_diff = $ctf - $now;

    if ( $ctf_diff->in_units('days') >= 6
	 && $ctf_diff->days >= 6 && $ctf_diff->hours >= 22 ) {
	return "Current CTF matches have been in progress since 9:00pm!";
    } else {
	return "Next FTWGL CTF match is in " . $ctf_diff->days . " days, " . $ctf_diff->hours . " hours, " . $ctf_diff->minutes . " minutes";
    }
}

sub next_matches {
    my ($self) = @_;

    return ($self->next_ts(), $self->next_ctf());
}

1;

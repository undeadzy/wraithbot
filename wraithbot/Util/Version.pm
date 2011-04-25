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

package Util::Version;

# Get the current github version

use strict;
use warnings;
use version 0.77; our $VERSION = version->declare('v0.0.1');

use Net::GitHub;
use Date::Parse;

use Readonly;

Readonly our $OWNER => 'undeadzy';
Readonly our $REPO  => 'wraithbot';

sub new {
    my ($class) = @_;

    my $self = {
    };

    bless( $self, $class );
    return $self;
}

sub last_update {
    my ($class) = @_;

    # XXX github limits to 60 calls/sec currently
    my $github = Net::GitHub->new( # Net::GitHub::V2, default
                                  owner => $OWNER, repo  => $REPO
    );
    my $detail = $github->repos->show();
    my $time = str2time($detail->{pushed_at});
    return $detail->{url} . " was last updated: " . localtime($time);
}

1;

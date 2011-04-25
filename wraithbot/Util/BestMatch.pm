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

package Util::BestMatch;

# This tries to find the best match using String::Approx with
# relative edit distance (using substrings).
#
# Like String::Approx, use this on strings, not text.
#
# Min threshold is 0 to 1 inclusive

use strict;
use warnings;
use Data::Dumper;
use String::Approx;

use Carp qw(cluck);

use Readonly;
use version 0.77; our $VERSION = version->declare('v0.0.1');

sub new {
    my ($class) = @_;

    my $self = {};

    bless( $self, $class );
    return $self;
}

sub match {
    my ($class, $pattern, $min_threshold, @choices) = @_;
    return $class->matches($pattern, $min_threshold, 0, @choices);
}

# Lower case everything
sub imatch {
    my ($class, $pattern, $min_threshold, @choices) = @_;
    return $class->matches($pattern, $min_threshold, 1, @choices);
}

sub matches {
    my ($class, $pattern, $min_threshold, $use_lc, @choices) = @_;

    $min_threshold = 1 if !defined($min_threshold);
    my @mod = map { $use_lc ? lc($_) : $_ } @choices;

    my %matches;
    @matches{@mod} = map { abs($_) } String::Approx::adistr($use_lc ? lc($pattern) : $pattern, @mod);

    # Find the minimum matches.  If there is an unique min, return it.
    my @min_match;
    my $min_val = 1;
    while (my ($k,$v) = each %matches) {
        if ($v > $min_threshold) {
            # Not considered good enough to include

        } elsif ($v < $min_val) {
            $min_val = $v;
            @min_match = ($k);

        } elsif ($v == $min_val) {
            push(@min_match, $k);
        }
    }

    return \@min_match;
}

1;

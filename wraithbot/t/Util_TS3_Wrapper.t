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

use strict;
use warnings;
use Carp;
use Data::Dumper;

use Test::More;

BEGIN { use_ok( 'Util::TS3::Wrapper' ); }
require_ok( 'Util::TS3::Wrapper' );

my @hosts = (
    [ '173.45.231.242', 10011, 9160 ],
    [ '66.55.149.29',    9100, 9160 ],
    [ '68.71.61.194',   10011, 9987 ],
    [ '188.138.48.106', 10011, 9987 ],
    [ '207.192.73.103', 10011, 9987 ],
    [ '64.34.169.33',   10011, 9987 ],
    [ '208.93.223.132', 10011, 9987 ],
    [ '74.207.235.61',  10011, 9987 ],
);

foreach my $host (@hosts) {
    print "Trying $host->[0]\n";
    my $ts3 = Util::TS3::Wrapper->new($host->[0], $host->[1]);
    isa_ok($ts3, 'Util::TS3::Wrapper');

    my @lines = $ts3->irc_listing($host->[2]);
    print Dumper(\@lines);
}

# Tell Test::More that we are done testing
done_testing();

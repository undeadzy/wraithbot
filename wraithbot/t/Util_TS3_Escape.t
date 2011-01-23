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

use Test::More;

BEGIN { use_ok( 'Util::TS3::Escape' ); }
require_ok( 'Util::TS3::Escape' );

my $esc = Util::TS3::Escape->new();
isa_ok($esc, 'Util::TS3::Escape');

# Trying with as many \xCC as possible.
my $string = "Team/speak 3|  ]|[ s\x08er\bver test\x0B h\n\be\\re\f \tto\ro\a";
my $esc_string = $esc->escape($string);

my $check = q{Team\/speak\s3\p\s\s]\p[\ss\ber\bver\stest\v\sh\n\be\\\\re\f\s\tto\ro\a};
is($esc_string, $check, "Make sure escape works");
is($esc->unescape($esc_string), $string, "Make sure unescape works");

$string = "Team\x2Fspeak\x203\x7C\x20\x20]\x7C[\x20s\x08er\x08ver\x20test\x0B\x20h\x0A\x08e\x5Cre\x0C\x20\x09to\x0Do\x07";
$esc_string = $esc->escape($string);
is($esc_string, $check, "Make sure escape works with hex");
is($esc->unescape($esc_string), $string, "Make sure unescape works with hex");

# Tell Test::More that we are done testing
done_testing();

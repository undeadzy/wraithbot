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

package Util::TS3::Escape;

# You have to use this escaping for any parameters that you send in the
# parameters section.

use strict;
use warnings;

use Readonly;
use Carp;

use version 0.77; our $VERSION = version->declare('v0.0.1');

# From page 5 of the TS3 server query manual
# This replaces a single ASCII character with two ASCII characters.
Readonly my %TS3_TRANSLATE => (
    "\x5C" => q{\\\\},    # \           => \\
    "\x2F" => q{\/},      # /           => \/
    "\x20" => q{\s},      # ' '         => \s
    "\x7C" => q{\p},      # |           => \p
    "\x07" => q{\a},      # (bell)      => \a
    "\x08" => q{\b},      # (backspace) => \b
    "\x0C" => q{\f},      # (formfeed)  => \f
    "\x0A" => q{\n},      # (newline)   => \n
    "\x0D" => q{\r},      # (carriage)  => \r
    "\x09" => q{\t},      # (horiz tab) => \t
    "\x0B" => q{\v},      # (vert tab)  => \v
);

Readonly my %TS3_REVERSE_TRANSLATE => reverse(%TS3_TRANSLATE);

Readonly my $TS3_ESCAPE =>
  join( "|", map { quotemeta($_) } keys(%TS3_TRANSLATE) );
Readonly my $TS3_UNESCAPE =>
  join( "|", map { quotemeta($_) } values(%TS3_TRANSLATE) );

sub new {
    my ($obj) = @_;
    my $class = ref($obj) || $obj;

    my $self = {
        server => undef,
        port   => undef,
    };

    bless( $self, $class );
    return $self;
}

sub escape {
    my ( $class, $data ) = @_;

    $data =~ s/($TS3_ESCAPE)/$TS3_TRANSLATE{$1}/gxms;
    return $data;
}

sub unescape {
    my ( $class, $data ) = @_;

    $data =~ s/($TS3_UNESCAPE)/$TS3_REVERSE_TRANSLATE{$1}/gxms;
    return $data;
}

# command [parameter...] [option...]
#
# Where parameters are separated by space and may be grouped together with a '|'.
# Parameters are key=value pairing.
#
# Options have leading dashes.  Do not specify them because it will be added in here.
sub generate_command {
    my ( $class, $cmd, $params, $opts ) = @_;

    my $result;
    if ( $cmd !~ /^[a-z0-9_]+$/xms ) {
        confess qq{Invalid command: $cmd};
    }
    $result = $cmd;

    if ( defined($params) ) {
        if ( ref($params) ne 'ARRAY' ) {
            confess
              qq{If present, params must be an array ref of hash refs not: }
              . ref($params);
        }

        foreach my $param_set ( @{$params} ) {
            if ( ref($param_set) ne 'HASH' ) {
                confess qq{If present, param_set must be a hash ref not: }
                  . ref($param_set);
            }
            $result .= " "
              . join( "|",
                map { $class->escape( $_ . "=" . $param_set->{$_} ) }
                  keys( %{$param_set} ) );
        }
    }

    if ( defined($opts) ) {
        if ( ref($opts) ne 'ARRAY' ) {
            confess qq{If present, opts must be an array ref};
        }

        $result .=
          " " . join( " ", map { $class->escape( "-" . $_ ) } @{$opts} );
    }

    return $result;
}

# This will parse the result and return an array ref of hash refs.
sub parse_message {
    my ( $class, $line ) = @_;

    chomp($line);
    my @lines = split( /\|/xms, $line );

    my @results;
    foreach my $l (@lines) {
        my %insert;
        my @params = split( /\s+/xms, $l );

        foreach my $p (@params) {
            if ( $p =~ m{^([^=]+)=(.+)}ixms ) {
                my ( $key, $value ) =
                  ( $class->unescape($1), $class->unescape($2) );

                if ( exists( $insert{$key} ) ) {
                    carp "Adding $1 which already exists";
                }
                $insert{$key} = $value;

            }
            else {
                my $key = $class->unescape($p);

# This usually shouldn't get here but I have seen some commands return without a k=v and just k
                if ( exists( $insert{$key} ) ) {
                    carp "Adding $p which already exists";
                }
                $insert{$key} = undef;
            }
        }

        push( @results, \%insert );
    }

    return \@results;
}

sub parse_result {
    my ( $class, $line ) = @_;

    my %result;
    chomp($line);
    if ( $line =~
        m{^error\s+id=(\d+)\s+msg=(\S+)(?:\s+(failed_permid=\d+))?$}ixms )
    {
        $result{id} = $1;

        if ( defined($3) ) {
            $result{msg} = $class->unescape( $2 . " " . $3 );
        }
        else {
            $result{msg} = $class->unescape($2);
        }
    }
    else {
        confess qq{Invalid message: "$line"};
    }

    return \%result;
}

1;

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

package Util::IRC::Format;

use strict;
use warnings;
use Carp;

use version 0.77; our $VERSION = version->declare('v0.0.1');

sub new {
    my ($obclass) = @_;
    my $class = ref($obclass) || $obclass;

    my $self = {};

    bless( $self, $class );
    return $self;
}

# Expects a 2D array
sub align {
    my ( $class, $lines ) = @_;

    my @save;
    my %max_size;
    for my $i ( 0 .. $#{$lines} ) {

        # Get the max
        for my $j ( 0 .. $#{ $lines->[$i] } ) {
            my $check = length( $lines->[$i][$j] );
            if ( !exists( $max_size{$j} ) || $check > $max_size{$j} ) {
                $max_size{$j} = $check;
            }
        }
    }

    for my $line ( @{$lines} ) {
        my @tmp;

        if ( ref($line) eq 'ARRAY' ) {
            for my $i ( 0 .. $#{$line} ) {
                if ( $i == 0 ) {
                    my $max = $max_size{$i};
                    push( @tmp, sprintf( "%-${max}.${max}s", $line->[$i] ) );

                }
                elsif ( $i < $#{$line} ) {
                    my $max = $max_size{$i};
                    push( @tmp, sprintf( "%${max}.${max}s", $line->[$i] ) );

                }
                else {

                    # Dont' adjust the last entry
                    push( @tmp, $line->[$i] );
                }
            }
            push( @save, join( "", @tmp ) );

        }
        else {
            my $max = $max_size{0};
            push( @save, sprintf( "%${max}.${max}s", $line ) );
        }
    }

    return @save;
}

1;

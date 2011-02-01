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

package Util::Quotes;

use strict;
use warnings;
use Carp qw(cluck);

use Readonly;

use version 0.77; our $VERSION = version->declare('v0.0.1');

Readonly my $QUOTES  => 'quotes';
Readonly my $COUNTER => 'counter';

sub new {
    my ( $arg, @args ) = @_;
    my $class = ref($arg) || $arg;

    my $self = {
        quotes  => undef,
        counter => undef,
        file    => $args[0],
    };

    bless( $self, $class );
    $self->reload_quotes( $self->{file} );
    return $self;
}

sub get_quotes {
    my ( $class, $file ) = @_;

    my $fh;
    if ( !open( $fh, '<', $file ) ) {
        cluck qq{Couldn't open the "} . $file
          . qq{" file.  No servers loaded: $!};
        return {};
    }
    my @lines = <$fh>;
    if ( !close($fh) ) {
        cluck qq{Couldn't close the "} . $file . qq{" file: $!};
        return {};
    }

    my $user    = undef;
    my $current = [];
    my $hash    = {};
    for my $line (@lines) {
        chomp($line);

        if ( $line =~ m{^\s*(\#.*)$}ixms ) {

           # Skip comments but not blank lines as those are used between entries

        }
        elsif ( $line =~ m{^(\S+)\s*$}ixms ) {
            my $new_user = $1;

            # User may have omitted the extra blank line
            if ( @{$current} ) {
                push( @{ $hash->{$user} }, $current );
            }
            $current = [];
            $user    = $new_user;

        }
        elsif ( $line =~ m{^\s*$}ixms ) {

            # After the last line for the quote
            if ( @{$current} ) {
                push( @{ $hash->{$user} }, $current );
            }
            $current = [];

        }
        elsif ( $line =~ m{^\s+(.+)\s*$}ixms ) {
            push( @{$current}, $1 );

        }
        else {
            print "Unrecognized line: $line";
        }
    }

    # Last line may have been an entry
    if ( @{$current} ) {
        push( @{ $hash->{$user} }, $current );
    }

    return $hash;
}

sub reload_quotes {
    my ( $self, $new_file ) = @_;

    if ( defined($new_file) ) {
        $self->{quotes} = $self->get_quotes($new_file);

    }
    else {
        $self->{quotes} = $self->get_quotes( $self->{file} );
    }
    $self->{counter} = {};

    return 1;
}

sub get_quote_status {
    my ($self) = @_;

    my $msg = "Available: ";
    my @names;
    foreach my $key ( sort( keys( %{ $self->{$QUOTES} } ) ) ) {
        push( @names,
            $key . "ism(" . ( $#{ $self->{$QUOTES}->{$key} } + 1 ) . ")" );
    }

    return $msg . join( ", ", @names );
}

sub get_ism {
    my ( $self, $name ) = @_;

    return $self->get_next_quote($name);
}

sub get_next_quote {
    my ( $self, $name ) = @_;

    if ( !exists( $self->{$QUOTES}->{$name} ) ) {
        return "";
    }

    my $num_quotes = $#{ $self->{$QUOTES}->{$name} } + 1;

    if (exists ($self->{$COUNTER}->{$name})) {
        if ($self->{$COUNTER}->{$name} >= $#{ $self->{$QUOTES}->{$name} }) {
            $self->{$COUNTER}->{$name} = 0;
        } else {
            $self->{$COUNTER}->{$name}++;
        }
    } else {
        $self->{$COUNTER}->{$name} = 0;
    }

    return $self->{$QUOTES}->{$name}->[ $self->{$COUNTER}->{$name} ];
}

sub get_random_quote {
    my ( $self, $name ) = @_;

    if ( !exists( $self->{$QUOTES}->{$name} ) ) {
        return "";
    }

    my $num_quotes = $#{ $self->{$QUOTES}->{$name} } + 1;
    my $index      = int( rand($num_quotes) );

    return $self->{$QUOTES}->{$name}->[$index];
}

1;

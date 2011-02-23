# This is where most of the heavy lifting happens.
# You can override some of these settings by using derived
# classes such as Quake3::Commands::Util::UrbanTerror
#
# In general, this should be applicable to most quake3 based games.

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

package Quake3::Commands::Util;

use strict;
use warnings;

use Socket;
use Data::Dumper;
use Readonly;
use Carp qw(cluck);

use Text::Wrap;

use Quake3::Commands;

use Util::IRC::Format;

use version 0.77; our $VERSION = version->declare('v0.0.1');

# Config settings that we use.  Note: We cannot use these directly
# in the hash because it is not case sensitive.  We don't want to
# destroy the case sensitivity.
Readonly our $CVAR_MAP_NAME        => 'mapname';
Readonly our $CVAR_GAME_TYPE       => 'g_gametype';
Readonly our $CVAR_MAX_CLIENTS     => 'sv_maxclients';
Readonly our $CVAR_PRIVATE_CLIENTS => 'sv_privateclients';
Readonly our $CVAR_NEED_PASSWORD   => 'g_needpass';

my $FMT = Util::IRC::Format->new();

sub new {
    my ($class) = @_;

    my $self = {
    };

    bless( $self, $class );
    return $self;
}

sub filter {
    my ($self, $msg) = @_;

    # Quake3 specific
    $msg =~ s{\^(\d|[FfbBnNXx])}{}gmxs;

    # General IRC filtering
    $msg = $FMT->plaintext_filter($msg);

    # Whitespace cleanup
    $msg =~ s{^\s+}{}gxms;
    $msg =~ s{\s+$}{}gxms;

    return $msg;
}

# Get a description of the players given the passed in settings.
#
# This will try to find bots and match clan tags in order to report
# about which clans are represented in the server.
sub get_player_description {
    my ( $self, $settings ) = @_;

    if ( !defined($settings) || ref($settings) ne 'HASH' ) {
        cluck "Error: Settings are undefined or the wrong data type";
        return "N/A";
    }

    if ( !exists( $settings->{players} ) ) {
        cluck "Couldn't find players";
        return "N/A";
    }

    my %results;
    foreach my $p ( @{ $settings->{players} } ) {
        if ( $p->{ping} <= 2 ) {
            if ( !exists( $results{bots} ) ) {
                $results{bots} = 0;
            }
            $results{bots}++;
        }
    }

    my @msgs;
    foreach my $clan ( sort( keys(%results) ) ) {
        if ( $clan eq 'bots' ) {
            push( @msgs, "WARN: $results{$clan} $clan" );
        }
    }

    return join( ", ", @msgs );
}

# Get the type of game this server is using currently.
# I don't store a list of TS/CTF/Bomb servers.  I query each
# one and use that as a filter.
sub get_game_type {
    my ( $self, $settings ) = @_;

    if ( !exists( $settings->{settings} ) ) {
        cluck "Couldn't find settings";
        return "N/A";
    }

    my @keys = keys( %{ $settings->{settings} } );
    my ($gametype) = grep { /^${CVAR_GAME_TYPE}$/ixms } @keys;

    my $value = $settings->{settings}->{$gametype};
    if ( defined($value) && $value =~ /^\d+$/ixms ) {
        return $value;

    }
    else {
        cluck "Game type doesn't exist or is not a number";
        return "N/A";
    }
}

sub get_max_players {
    my ( $self, $settings ) = @_;

    if ( !exists( $settings->{settings} ) ) {
        cluck "Couldn't find settings";
        return 0;
    }

    my @keys = keys( %{ $settings->{settings} } );
    my ($maxclients)     = grep { /^${CVAR_MAX_CLIENTS}$/ixms } @keys;
    my ($privateclients) = grep { /^${CVAR_PRIVATE_CLIENTS}$/ixms } @keys;

    if ( $settings->{settings}->{$maxclients} =~ /^\d+$/ixms ) {
        if ( $settings->{settings}->{$privateclients} =~ /^\d+$/ixms ) {
            return $settings->{settings}->{$maxclients} -
              $settings->{settings}->{$privateclients};

        }
        else {
            return $settings->{settings}->{$maxclients};
        }

    }
    else {
        cluck "Couldn't get the max clients setting so returning 0";
        return 0;
    }
}

sub send_info_request {
    my ( $self, $servers ) = @_;

    my $socket = undef;
    my $count  = 0;
    foreach my $pair ( keys( %{$servers} ) ) {
        if ( $pair =~ m{^([^:]+):([^:]+)$}mxs ) {
            my ( $host, $port ) = ( $1, $2 );

            if ( $port !~ /^\d+$/ixms ) {
                $port = getservbyname( $port, 'udp' );
                if ( !defined($port) || $port eq q{} ) {
                    cluck "Failed to get port";
                    next;
                }
            }
            my $hisiaddr = inet_aton($host);
            if ( !defined($hisiaddr) || !$hisiaddr ) {
                cluck "Failed on $host";
                next;
            }

            my $hispaddr = sockaddr_in( $port, $hisiaddr );
            if ( !defined($hispaddr) || $hispaddr eq q{} ) {
                cluck "Failed to get socket";
                next;
            }

            # XXX Should return a status and use $$socket
            my $ret_socket =
              $self->send_udp( $socket, $host, $port,
                Quake3::Commands->generate_get_status() );
            if ( defined($ret_socket) && $ret_socket ne q{} ) {
                $socket = $ret_socket;

            }
            else {
                cluck "Invalid socket";
                next;
            }

            $count++;

        }
        else {
            cluck "Skipping $pair because it is invalid\n";
        }
    }

    return ( $count, $socket );
}

sub print_servers {
    my ( $self, $servers, $irc_server, $irc_target, $only_gametype ) = @_;

    my %max = (
        name   => 0,
        player => 5,     # 64/64
        host   => 0,
        type   => 4,     # CTF|FTL|TS|BOMB etc
        map    => 10,    # arbitrary but fits most maps
    );

    while ( my ( $k, $v ) = each %{$servers} ) {
        if ( length( $v->{name} ) > $max{name} ) {
            $max{name} = length( $v->{name} );
        }

        if ( length($k) > $max{host} ) {
            $max{host} = length($k);
        }
    }

    return $self->handle_server_requests(
        $servers,
        $irc_server,
        $irc_target,
        sub {
            my ( $self, $game_server, $serv, $targ ) = @_;
            $self->print_server_response( $game_server, \%max, $serv, $targ,
                $only_gametype );
        }
    );
}

sub print_servers_status {
    my ( $self, $servers, $irc_server, $irc_target ) = @_;

    # Move everything to offline and exchange when we get a response.
    my %status = (
        online  => {},
        offline => {},
    );
    while ( my ( $k, $v ) = each %{$servers} ) {
        $status{offline}->{$k} = $v->{name};
    }

    $self->handle_server_requests(
        $servers,
        $irc_server,
        $irc_target,
        sub {
            my ( $self, $game_server, $serv, $targ ) = @_;

            # This actually removes it from offline and puts it in online
            $self->save_server_status( $game_server, $servers, \%status );
        }
    );

    return $self->print_server_status( $irc_server, $irc_target, \%status );
}

sub print_players {
    my ( $self, $servers, $irc_server, $irc_target ) = @_;

    return $self->handle_server_requests(
        $servers,
        $irc_server,
        $irc_target,
        sub {
            my ( $self, $game_server, $serv, $targ ) = @_;
            $self->print_players_response( $game_server, $serv, $targ );
        }
    );
}

sub print_settings {
    my ( $self, $servers, $irc_server, $irc_target ) = @_;

    return $self->handle_server_requests(
        $servers,
        $irc_server,
        $irc_target,
        sub {
            my ( $self, $game_server, $serv, $targ ) = @_;
            $self->print_server_settings( $game_server, $serv, $targ );
        }
    );
}

sub _print_too_many_servers {
    my ( $self, $matches_ref, $irc_server, $irc_target ) = @_;

    if ( $#{$matches_ref} == -1 ) {
	$FMT->send_bold_msg($irc_server, $irc_target, "No matches");

    }
    else {
        my @names;
        for my $m ( @{$matches_ref} ) {
            my @keys = keys( %{$m} );
            push( @names, $m->{ $keys[0] }->{name} );
        }

	$FMT->send_bold_msg($irc_server, $irc_target,
			    "Found too many matches: " . join( ", ", @names ));
    }

    return 1;
}

sub print_filtered_players {
    my ( $self, $potential_servers, $request, $irc_server, $irc_target ) = @_;

    my $matches_ref =
      $self->get_filtered_servers( $potential_servers, $request );
    if ( $#{$matches_ref} == 0 ) {
        foreach my $m ( @{$matches_ref} ) {
            $self->print_players( $m, $irc_server, $irc_target );
        }
    }
    else {
        $self->_print_too_many_servers( $matches_ref, $irc_server,
            $irc_target );
    }

    return 1;
}

sub print_filtered_settings {
    my ( $self, $potential_servers, $request, $irc_server, $irc_target ) = @_;

    my $matches_ref =
      $self->get_filtered_servers( $potential_servers, $request );
    if ( $#{$matches_ref} == 0 ) {
        foreach my $m ( @{$matches_ref} ) {
            $self->print_settings( $m, $irc_server, $irc_target );
        }

    }
    else {
        $self->_print_too_many_servers( $matches_ref, $irc_server,
            $irc_target );
    }

    return 1;
}

sub handle_server_requests {
    my ( $self, $servers, $irc_server, $irc_target, $subr ) = @_;

    my ( $count, $socket ) = $self->send_info_request($servers);

    my $rin = '';
    vec( $rin, fileno($socket), 1 ) = 1;

    my ($rout);
    while ( $count && select( $rout = $rin, undef, undef, 1 ) ) {
        my $result = $self->receive_udp($socket);

        # Error checking for the above call
        if ( exists( $result->{data} ) ) {
            my $val =
              Quake3::Commands->parse_status_response( $result->{data} );
            if ( defined($val) && exists( $val->{settings} ) ) {
                my $server_desc = $result->{ip} . q{:} . $result->{port};

                $servers->{$server_desc}->{data} = $val;
                $servers->{$server_desc}->{ip}   = $result->{ip};
                $servers->{$server_desc}->{host} = $result->{host};
                $servers->{$server_desc}->{port} = $result->{port};

                if ( defined($subr) && ref($subr) eq 'CODE' ) {
                    $subr->(
                        $self, $servers->{$server_desc},
                        $irc_server, $irc_target
                    );
                }

            }
            else {
                cluck "Skipping since the response was invalid";
            }
        }
        else {
            cluck "Invalid response from socket";
        }

    # The servers only send one response so it doesn't matter if it was an error
        $count--;
    }

    return 1;
}

sub get_filtered_servers {
    my ( $self, $potential_servers, $request ) = @_;

    if ( !defined($potential_servers) || !defined($request) ) {
        cluck "Invalid input";
        return [];
    }

    $request =~ s{^\s+}{}xms;
    $request =~ s{\s+$}{}xms;

    my $match = quotemeta($request);
    my @matches;
    while ( my ( $k, $v ) = each( %{$potential_servers} ) ) {
        if ( $k =~ m{^$match}ixms || $v->{name} =~ m{^$match}ixms ) {
            push( @matches, { $k => $v } );
        }
    }

    # We didn't find anything and it is an unique prefix
    if ( scalar(@matches) > 0 ) {
        return \@matches;
    }
    return [];
}

sub save_server_status {
    my ( $self, $v_ref, $server_info, $status ) = @_;

    my $key = $v_ref->{ip} . q{:} . $v_ref->{port};
    delete( $status->{offline}->{$key} );
    $status->{online}->{$key} = $server_info->{$key}->{name};

    return 1;
}

sub print_server_response {
    my ( $self, $v_ref, $max_ref, $irc_server, $irc_target, $only_gametype ) =
      @_;

    if ( !exists( $v_ref->{data} ) || !exists( $v_ref->{data}->{settings} ) ) {
        cluck "Invalid server without any settings";
        return 0;
    }

    if ( scalar( @{ $v_ref->{data}->{players} } ) == 0 ) {

        # Skipping because it doesn't have any players.
        return 0;
    }

    my @keys = keys( %{ $v_ref->{data}->{settings} } );
    my ($mapname)  = grep { /^${CVAR_MAP_NAME}$/ixms } @keys;
    my ($gametype) = grep { /^${CVAR_GAME_TYPE}$/ixms } @keys;
    my ($needpass) = grep { /^${CVAR_NEED_PASSWORD}$/ixms } @keys;

    my $game_value = $self->get_game_type( $v_ref->{data} );
    if ( defined($only_gametype) ) {
        if ( uc($game_value) ne uc($only_gametype) ) {
            return 0;
        }
    }

    my $max_name   = $max_ref->{name};
    my $max_type   = $max_ref->{type};
    my $max_player = $max_ref->{player};
    my $max_host   = $max_ref->{host};
    my $max_map    = $max_ref->{map};

    my $shortname = $v_ref->{data}->{settings}->{$mapname};
    $shortname =~ s/^ut4?_//imxs;

    my $needs_pass = q{};
    if ( defined($needpass) && $v_ref->{data}->{settings}->{$needpass} == 1 ) {
        $needs_pass = "(private) ";
    }

    my $msg = sprintf(
qq{%-${max_name}.${max_name}s %${max_type}.${max_type}s %${max_player}.${max_player}s %-${max_map}.${max_map}s %-${max_host}.${max_host}s %s%s},
        $v_ref->{name},
        $self->get_game_type( $v_ref->{data} ),
        scalar( @{ $v_ref->{data}->{players} } ) . q{/}
          . $self->get_max_players( $v_ref->{data} ),
        $shortname,
        $v_ref->{ip} . q{:} . $v_ref->{port},
        $needs_pass,
        $self->get_player_description( $v_ref->{data} )
    );

    if ( defined($irc_server) && defined($irc_target) ) {
	$FMT->send_bold_msg($irc_server, $irc_target, $msg);
    }
    else {

        # Don't make this a cluck.  It's supposed to go to the console.
        print "$msg\n";
    }

    return 1;
}

sub print_players_response {
    my ( $self, $v_ref, $irc_server, $irc_target ) = @_;

    if ( !exists( $v_ref->{data} ) || !exists( $v_ref->{data}->{settings} ) ) {
        cluck "Invalid server without any settings";
        return 0;
    }

    my @playerlist;
    foreach my $p (
        sort {
            $b->{score} <=> $a->{score}
              || lc( $a->{name} ) cmp lc( $b->{name} )
        } @{ $v_ref->{data}->{players} }
      )
    {

        # score, ping, name
        my $name = $p->{name};

        $name = $self->filter($name);

        push( @playerlist, sprintf( qq{%.20s}, $name ) );
    }

    my $msg =
        $v_ref->{name} . q{ (}
      . $v_ref->{ip} . q{:}
      . $v_ref->{port} . q{) = }
      . join( q{, }, @playerlist );

    if ( defined($irc_server) && defined($irc_target) ) {
	$FMT->send_bold_msg($irc_server, $irc_target, $msg);
    }
    else {

        # Don't make this a cluck.  It's supposed to go to the console.
        print "$msg\n";
    }

    return 1;
}

sub print_server_settings {
    my ( $self, $v_ref, $irc_server, $irc_target ) = @_;

    if ( !exists( $v_ref->{data} ) || !exists( $v_ref->{data}->{settings} ) ) {
        cluck "Invalid server without any settings";
        return 0;
    }

    my @settings;
    foreach my $name ( sort { lc($a) cmp lc($b) }
        ( keys( %{ $v_ref->{data}->{settings} } ) ) )
    {
        my $val = $v_ref->{data}->{settings}->{$name};

        $name = $self->filter($name);
        $val = $self->filter($val);

        push( @settings, sprintf( qq{%.20s=%.20s}, $name, $val ) );
    }

    my $msg =
        $v_ref->{name} . " ("
      . $v_ref->{ip} . ":"
      . $v_ref->{port} . "): "
      . join( ", ", @settings );

    local ($Text::Wrap::columns) = 400;
    my $split_msg = wrap( q{}, "    ", $msg );
    my @lines = split( /\n/xms, $split_msg );

    if ( defined($irc_server) && defined($irc_target) ) {
        my $max_lines = ( $#lines < 4 ? $#lines : 4 );
	for my $i ( 0 .. $max_lines ) {
	    $FMT->send_bold_msg($irc_server, $irc_target, $lines[$i]);
	}
    }
    else {
        # Don't make this a cluck.  It's supposed to go to the console.
        print "$msg\n";
    }

    return 1;
}

sub print_server_status {
    my ( $self, $irc_server, $irc_target, $status ) = @_;

    my $on_msg = "Online: " . join( ", ", values( %{ $status->{online} } ) );
    my $off_msg = "Offline: " . join( ", ", values( %{ $status->{offline} } ) );

    local ($Text::Wrap::columns) = 400;
    my $on_split_msg = wrap( q{}, "    ", $on_msg );
    my @on_lines = split( /\n/xms, $on_split_msg );

    my $off_split_msg = wrap( q{}, "    ", $off_msg );
    my @off_lines = split( /\n/xms, $off_split_msg );

    if ( defined($irc_server) && defined($irc_target) ) {
        my $max_lines = ( $#on_lines < 5 ? $#on_lines : 5 );
        for my $i ( 0 .. $max_lines ) {
	    $FMT->send_bold_msg($irc_server, $irc_target, $on_lines[$i]);
        }

        if ( scalar( keys( %{ $status->{offline} } ) ) > 0 ) {
            $max_lines = ( $#off_lines < 5 ? $#off_lines : 5 );
            for my $i ( 0 .. $max_lines ) {
		$FMT->send_bold_msg($irc_server, $irc_target, $off_lines[$i]);
	    }
        }
    }
    else {

        # Don't make this a cluck.  It's supposed to go to the console.
        print "$on_msg\n";

        if ( scalar( keys( %{ $status->{offline} } ) ) > 0 ) {
            print "$off_msg\n";
        }
    }

    return 1;
}

sub send_udp {
    my ( $self, $socket, $host, $port, $data ) = @_;

    if ( !defined($socket) ) {
        my $iaddr = INADDR_ANY;    # gethostbyname(hostname());

        my $proto = getprotobyname('udp');
        if ( !defined($proto) || $proto eq q{} ) {
            cluck "Couldn't get the protocol";
            return q{};
        }

        my $paddr = sockaddr_in( 0, $iaddr );    # 0 means let kernel pick
        if ( !defined($paddr) || $paddr eq q{} ) {
            cluck "Couldn't get the socket";
            return q{};
        }

        if ( !socket( $socket, PF_INET, SOCK_DGRAM, $proto ) ) {
            cluck "Couldn't create the socket";
            return q{};
        }
        if ( !bind( $socket, $paddr ) ) {
            cluck "Couldn't bind";
            return q{};
        }
    }

    local $| = 1;

    if ( $port !~ /^\d+$/ixms ) {
        $port = getservbyname( $port, 'udp' );
        if ( !defined($port) || $port eq q{} ) {
            cluck "Couldn't get the port";
            return q{};
        }
    }

    # This can be a numeric string or hostname
    my $hisiaddr = inet_aton($host);
    if ( !defined($hisiaddr) || !$hisiaddr ) {
        cluck "Couldn't get the host for $host";
        return q{};
    }
    my $hispaddr = sockaddr_in( $port, $hisiaddr );
    if ( !defined($hispaddr) || $hispaddr eq q{} ) {
        cluck "Couldn't get the socket";
        return q{};
    }

    my $length = length($data);
    while ( $length > 0 ) {
        my $res = send( $socket, $data, 0, $hispaddr );
        if ( !defined($res) ) {
            cluck "Couldn't send data";

        }
        else {
            $length -= $res;
            $data = substr( $data, $res );
        }
    }

    return $socket;
}

sub receive_udp {
    my ( $self, $socket ) = @_;

    if ( !defined($socket) || $socket eq q{} ) {
        cluck "Invalid input";
        return {};
    }

    my ( $data, $hispaddr );
    if ( !( $hispaddr = recv( $socket, $data, 2**16, 0 ) ) ) {
        cluck "Failed: $!";
        return {};
    }

    my ( $port, $hisiaddr ) = sockaddr_in($hispaddr);
    if ( !defined($port) || $port eq q{} ) {
        cluck "Invalid port";
        return {};
    }
    if ( !defined($hisiaddr) || $hisiaddr eq q{} ) {
        cluck "Invalid addr";
        return {};
    }

    my $host = gethostbyaddr( $hisiaddr, AF_INET );
    my $ip = inet_ntoa($hisiaddr);
    if ( !defined($ip) || $ip eq q{} ) {
        cluck "Invalid IP";
        return {};
    }

    if ( !defined($host) || $host eq q{} ) {
        $host = $ip;
    }

    return { host => $host, ip => $ip, port => $port, data => $data };
}

sub test_me {
    my ($self) = @_;

    my $servers = {
        "206.217.142.38:27960" => { name => "iCu* private" },
        "74.207.235.61:27961"  => { name => "UrT East" },

        #    "72.26.196.178:27960"  => { name => "Best of the Best" },
        "64.156.192.169:27963" => { name => "wTf San Diego" },
        "8.6.15.92:27960"      => { name => "Spray and Pray" },
    };
    $self->print_servers($servers);
    $self->print_players($servers);
    $self->print_settings($servers);

    return 1;
}

1;

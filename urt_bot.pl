#!env perl

#
# irssi bot for Urban Terror.  It currently displays info on the top CTF, TS and
# Bomb pubs.
#
# Put this in ~/.irssi/scripts and then load it with:
# /script load urt_bot
#
# To unload it (for instance when you made a change), use this:
# /script reset
# /script load urt_bot
#
# A simple /script unload urt_bot isn't sufficient.  It's likely because I'm
# using classes which don't get unloaded like a simple script does.  I could
# force loading the module every time.
#

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

use Data::Dumper;
use Readonly;
use Carp qw(cluck);

use Irssi;
use Irssi::Irc;
use vars qw(%IRSSI);

# Store everything in a separate directory
use lib $ENV{HOME} . '/.irssi/scripts/wraithbot';

use Quake3::Rcon;
use Quake3::Rcon::Commands;
use Quake3::Commands;
use Quake3::Commands::Util;
use Quake3::Commands::Util::UrbanTerror;

use Util::TS3::Commands;
use Util::TS3::Wrapper;

use Util::Fortune;
use Util::Quotes;

use Util::IRC::Auth;
use Util::IRC::Format;

use version 0.77; our $VERSION = version->declare('v0.0.1'); # Use this instead of what the irssi docs say

# XXX NOTE: If your messages are too long, they run into flood protection.
%IRSSI = (
    authors => q{undeadzy  (q3urt.undead@gmail.com)},
    contact => "#iCu on gamesurge",
    name    => "urt_bot",
    description =>
      "Provides !ctf, !ts, etc to display selected servers as a message",
    license => "FreeBSD license (2 clause BSD)",
    url     => "https://github.com/undeadzy/wraithbot",
);

# Valid prefixes before bot commands.  Anything inside [] will be matched at the beginning of the line.
Readonly my $BOT_PREFIX => '[!\@,.]';

# Yeah all of this screams a plugin system but I'm done with this...
Readonly my $HELP_MESSAGE =>
q{Available commands (restricted to certain servers): !ts, !ctf, !bomb, !servers_status, !players <server name|IP>, !meow, !rawr, !fortune, !fortune_off, !isms, !gtv, !gtv_ip, !gtv_msg, !ts3 list, !ts3 <server alias> [admin: !gtv <ip:port> <msg>, !gtv_ip <ip:port>, !gtv_msg <msg>] [owner: !reload <ts3|clans|servers>]};

Readonly my $MEOW_RESPONSE => q{MEEOOOWW};
Readonly my $RAWR_RESPONSE => q{RRAAWWWRRR};

# Colors for irssi.  Or in this case, styles.
Readonly my $COLOR_BOLD  => "\cB";
Readonly my $COLOR_RESET => "\cO";

# Edit this for the default settings.  These can be modified by trusted users
# (see trusted_user function below).  This gets saved into your config file.
#
# Keys so we don't have to worry about typos
Readonly my $GTV_IP       => "urt_gtv_ip";
Readonly my $GTV_MESSAGE  => "urt_gtv_message";
Readonly my $RCON_HOST    => "urt_rcon_host";
Readonly my $RCON_PORT    => "urt_rcon_port";
Readonly my $RCON_PASS    => "urt_rcon_pass";
Readonly my $RCON_TIMEOUT => "urt_rcon_timeout";
Readonly my $SERVERS_FILE => "urt_servers_file";
Readonly my $TS3_FILE     => "urt_ts3_file";
Readonly my $CLAN_FILE    => "urt_clan_file";
Readonly my $QUOTES_FILE  => "urt_quotes_file";

#
# These get saved/read from your irssi config
Irssi::settings_add_str( "misc", $GTV_IP,      "ftwgl.com:1337" );
Irssi::settings_add_str( "misc", $GTV_MESSAGE, "No scheduled matches" );
Irssi::settings_add_str( "misc", $RCON_HOST,   "206.217.142.38" );
Irssi::settings_add_str( "misc", $RCON_PORT,   27960 );
Irssi::settings_add_str( "misc", $RCON_PASS,   "abcde" )
  ;    # XXX Of course this isn't it
Irssi::settings_add_str( "misc", $RCON_TIMEOUT, 5 );
Irssi::settings_add_str( "misc", $SERVERS_FILE,
    $ENV{HOME} . "/.irssi/scripts/wraithbot/conf/game_servers.txt" );
Irssi::settings_add_str( "misc", $TS3_FILE,
    $ENV{HOME} . "/.irssi/scripts/wraithbot/conf/ts3_servers.txt" );
Irssi::settings_add_str( "misc", $CLAN_FILE,
    $ENV{HOME} . "/.irssi/scripts/wraithbot/conf/clans.txt" );
Irssi::settings_add_str( "misc", $QUOTES_FILE,
    $ENV{HOME} . "/.irssi/scripts/wraithbot/conf/quotes.txt" );

# Edit this for the list of servers you want.  You will want to have an unique prefix
# because commands like !players will match on the prefix.
my $SERVERS = get_server_list();
my $TS3     = get_ts3_list();

Readonly my $URT => Quake3::Commands::Util::UrbanTerror->new(
    Irssi::settings_get_str($CLAN_FILE) );
Readonly my $QUOTES =>
  Util::Quotes->new( Irssi::settings_get_str($QUOTES_FILE) );

# The bot listens in any channel in the private or public area.
# The ops => argument is used to determine whether this channel should be used for authorization.
# For instance, you could have it listen in a channel but treat ops as regular users.
#
# Setup all of the authorization
my $AUTH = Util::IRC::Auth->new();

# TS3 commands need at least 3 seconds between calls.
my $TS3_AUTH = Util::IRC::Auth->new( { delay => 3 } );

for my $type ( $AUTH, $TS3_AUTH ) {
    $type->add_private_channel( "#icuclan",  1 );
    $type->add_private_channel( "#vex-priv", 1 );

    $type->add_public_channel( "#ftwgl",           1 );
    $type->add_public_channel( "#icu",             1 );
    $type->add_public_channel( "#clan-vex",        1 );
    $type->add_public_channel( "#team-veneration", 0 );
    $type->add_public_channel( "#cakeclan",        0 );

  # Testing channel
    $type->add_public_channel( "#urtpub",          0 );

  # These are special users that are always trusted.  Since they are +x
  # modes, it requires that someone logs in with either my account or the bot's.
    $type->add_user( q{undeadzy},  q{~undeadzy@undeadzy.undead.gamesurge} );
    $type->add_user( q{wraithbot}, q{~wraithbot@wraithbot.bot.gamesurge} );
}

sub get_server_list {
    my $fh;
    if ( !open( $fh, '<', Irssi::settings_get_str($SERVERS_FILE) ) ) {
        cluck qq{Couldn't open the "}
          . Irssi::settings_get_str($SERVERS_FILE)
          . qq{" file.  No servers loaded: $!};
        return {};
    }
    my @lines = <$fh>;
    if ( !close($fh) ) {
        cluck qq{Couldn't close the "}
          . Irssi::settings_get_str($SERVERS_FILE)
          . qq{" file: $!};
        return {};
    }

    my $hash = {};
    for my $line (@lines) {
        chomp($line);

        if ( $line =~ m{^\s*(\#.*)?$}ixms ) {

            # Skip comments

        }
        elsif ( $line =~ m{^\s*(.+)\s+((?:\d+\.){3}\d+:\d+)\s*(\#.*)?$}ixms ) {
            my ( $name, $addr ) = ( $1, $2 );

            $name =~ s{^\s+}{}xms;
            $name =~ s{\s+$}{}xms;

            $hash->{$addr} = { name => $name };

        }
        else {
            print "Unrecognized line: $line";
        }
    }

    return $hash;
}

sub get_ts3_list {
    my $fh;
    if ( !open( $fh, '<', Irssi::settings_get_str($TS3_FILE) ) ) {
        cluck qq{Couldn't open the "}
          . Irssi::settings_get_str($TS3_FILE)
          . qq{" file.  No servers loaded: $!};
        return {};
    }
    my @lines = <$fh>;
    if ( !close($fh) ) {
        cluck qq{Couldn't close the "}
          . Irssi::settings_get_str($TS3_FILE)
          . qq{" file: $!};
        return {};
    }

    my $hash = {};
    for my $line (@lines) {
        chomp($line);

        if ( $line =~ m{^\s*(\#.*)?$}ixms ) {

            # Skip comments

        }
        elsif ( $line =~
            m{^\s*(.+)\s+((?:\d+\.){3}\d+)\s+(\d+)\s+(\d+)(\s*\#.*)?$}ixms )
        {
            my ( $name, $addr, $client_port, $query_port ) = ( $1, $2, $3, $4 );

            $name =~ s{^\s+}{}xms;
            $name =~ s{\s+$}{}xms;

            $hash->{$name} = {
                ip          => $addr,
                client_port => $client_port,
                query_port  => $query_port
            };

        }
        else {
            print "Unrecognized line: $line";
        }
    }

    return $hash;
}

# Check to see if this is a valid prefix for a bot command
# You may want to avoid ! because chanserv and many other bots use it.
sub is_valid_prefix {
    my ($data) = @_;

    if ( $data =~ m{^${BOT_PREFIX}}ixms ) {
        return 1;
    }

    return 0;
}

# An user requested that all messages be bold so they stand out.
sub send_bold_msg {
    my ( $server, $target, $is_commandline, $msg ) = @_;

    my $is_nick = 1;
    if ( defined($target) && $target =~ m{^\#}xms ) {
        $is_nick = 0;
    }

    if ($is_commandline) {
        return Irssi::print( $COLOR_BOLD . $msg . $COLOR_RESET );

    }
    else {
        return $server->send_message( $target,
            $COLOR_BOLD . $msg . $COLOR_RESET, $is_nick );
    }
}

# Sanitize the user's input and set GTV_IP to it
sub sanitize_ip_port {
    my ($data) = @_;

    $data =~ s{[^0-9.:]+}{}gxms;

    Irssi::settings_set_str( $GTV_IP, $data );

    return 1;
}

# Sanitize the user's message and set GTV_MESSAGE to it
sub sanitize_msg {
    my ($data) = @_;

    $data =~ s{[^0-9a-zA-Z_.\@:'"! \-]+}{}gxms;

    # Don't allow IRC like commands
    $data =~ s{^\s*/+}{}gxms;

    Irssi::settings_set_str( $GTV_MESSAGE, $data );

    return 1;
}

# This is the main message that gets printed from the !gtv command.
sub GTV_INFO {
    return
        "GTV: +connect "
      . Irssi::settings_get_str($GTV_IP) . "  "
      . Irssi::settings_get_str($GTV_MESSAGE);
}

# This only has a subset of the rcon commands.  For instance, 'set' can have many different variations.
#
# This is currently disabled by server admin request.
#
# Supported commands:
#
# map <name>
# map_restart
# g_password <pass>
# g_gametype <0-8> or <FFA|TDM|TS|FTL|CAH|CTF|BOMB>
# say <text> where text is filtered to only allow certain characters
# g_respawndelay <number>
# help
#
sub handle_rcon {
    my ( $server, $channel, $data ) = @_;

    if ( $data !~ m{^${BOT_PREFIX}rcon\s+\S+}ixms ) {
        return 0;
    }

    if ( !defined($server) || !defined($channel) || !defined($data) ) {
        Irssi::print("Undefined inputs");
        return 0;
    }

    my $setting = {
        host     => Irssi::settings_get_str($RCON_HOST),
        port     => Irssi::settings_get_str($RCON_PORT),
        password => Irssi::settings_get_str($RCON_PASS),
        timeout  => Irssi::settings_get_str($RCON_TIMEOUT),
    };

    if ( $data =~ m{^${BOT_PREFIX}rcon\s+map\s+([a-zA-Z0-9_]+)\s*$}ixms ) {
        return Quake3::Rcon->send_rcon( $setting, 'map', $1 );

    }
    elsif ( $data =~ m{^${BOT_PREFIX}rcon\s+map_restart\s*$}ixms ) {
        return Quake3::Rcon->send_rcon( $setting, 'map_restart' );

    }
    elsif ( $data =~
        m{^${BOT_PREFIX}rcon\s+g_password\s+([a-zA-Z0-9:._-]+)\s*$}ixms )
    {
        return Quake3::Rcon->send_rcon( $setting, 'set', 'g_password', $1 );

    }
    elsif ( $data =~ m{^${BOT_PREFIX}rcon\s+g_gametype\s+([0-7])\s*$}ixms ) {
        return Quake3::Rcon->send_rcon( $setting, 'set', 'g_gametype', $1 );

    }
    elsif ( $data =~
m{^${BOT_PREFIX}rcon\s+g_gametype\s+(ffa|tdm|ts|ftl|cah|ctf|bomb)\s*$}ixms
      )
    {
        my $gamename = uc($1);

        if (
            exists(
                $Quake3::Commands::Util::UrbanTerror::GAME_TYPE->{$gamename}
            )
          )
        {
            return Quake3::Rcon->send_rcon( $setting, 'set', 'g_gametype',
                $Quake3::Commands::Util::UrbanTerror::GAME_TYPE->{$gamename} );

        }
        elsif (
            exists(
                $Quake3::Commands::Util::UrbanTerror::TYPE_GAME->{$gamename}
            )
          )
        {
            return Quake3::Rcon->send_rcon( $setting, 'set', 'g_gametype',
                $gamename );

        }
        else {
            Irssi::print("Invalid game type: $gamename");
            return 0;
        }

    }
    elsif ( $data =~
        m{^${BOT_PREFIX}rcon\s+say\s+([a-zA-Z0-9!:./\#?_-]+|\s+)+\s*$}ixms )
    {
        return Quake3::Rcon->send_rcon( $setting, 'say', $1 );

    }
    elsif ( $data =~ m{^${BOT_PREFIX}rcon\s+g_respawndelay\s+(\d+)\s*$}ixms ) {
        return Quake3::Rcon->send_rcon( $setting, 'set', 'g_respawndelay', $1 );

    }
    elsif ( $data =~ m{^${BOT_PREFIX}rcon(\s+.*)?$}ixms ) {
        my $msg =
q{Invalid command.  Allowed rcon commands: map <name>, map_restart, g_password <pass>, g_gametype <0-8> or <FFA|TDM|TS|FTL|CAH|CTF|BOMB>, say <text>, g_respawndelay <number>};

        if ( defined($server) && defined($channel) ) {
            $server->send_message( $channel->{name},
                $COLOR_BOLD . $msg . $COLOR_RESET, 0 );

        }
        else {
            Irssi::print("Help: $msg");
        }
        return 1;

    }
    else {
        Irssi::print("Invalid data '$data'");
        return 0;
    }

    return 0;
}

# The main routine which handles all of the bots actions.
# The only exceptions are the local commands that you can use directly with
# the bot (see cmd_* below).
sub handle_actions {
    my ( $server, $data, $nick, $mask, $target, $is_commandline ) = @_;

    if ( !is_valid_prefix($data) ) {
        return 0;
    }

    if ( !$is_commandline ) {
        if ( $target =~ m{^\#}xms && !$AUTH->authorized_channel($target) ) {
            return 0;
        }

        if ( $AUTH->user_is_spamming( $server, $nick, $mask, $target ) ) {
            return 0;
        }
    }

    if ( $data =~ /^${BOT_PREFIX}reload\s+servers?$/ixms ) {
        if ( !$AUTH->user_is_privileged( $server, $nick, $mask ) ) {
            send_bold_msg( $server, $target, $is_commandline,
                "Insufficient access to run this command" );
            return 0;

        }
        else {
            $SERVERS = get_server_list();
            send_bold_msg( $server, $target, $is_commandline,
                "Reloaded UrT server information" );
        }

    }
    elsif ( $data =~ /^${BOT_PREFIX}reload\s+clans?\s*$/ixms ) {
        if ( !$AUTH->user_is_privileged( $server, $nick, $mask ) ) {
            send_bold_msg( $server, $target, $is_commandline,
                "Insufficient access to run this command" );
            return 0;

        }
        else {
            $URT->reload_clans();
            send_bold_msg( $server, $target, $is_commandline,
                "Reloaded UrT clan information" );
        }

    }
    elsif ( $data =~ /^${BOT_PREFIX}reload\s+quotes?\s*$/ixms ) {
        if ( !$AUTH->user_is_privileged( $server, $nick, $mask ) ) {
            send_bold_msg( $server, $target, $is_commandline,
                "Insufficient access to run this command" );
            return 0;

        }
        else {
            $QUOTES->reload_quotes();
            send_bold_msg( $server, $target, $is_commandline,
                "Reloaded UrT quotes" );
        }

    }
    elsif ( $data =~ /^${BOT_PREFIX}reload\s+all\s*$/ixms ) {
        if ( !$AUTH->user_is_privileged( $server, $nick, $mask ) ) {
            send_bold_msg( $server, $target, $is_commandline,
                "Insufficient access to run this command" );
            return 0;

        }
        else {
            $SERVERS = get_server_list();
            $TS3     = get_ts3_list();
            $URT->reload_clans();
            $QUOTES->reload_quotes();
            send_bold_msg( $server, $target, $is_commandline,
                "Reloaded TS3, UrT server and UrT clan information" );
        }

    }
    elsif ( $data =~ /^${BOT_PREFIX}servers?\s*$/ixms ) {
        return $URT->print_servers( $SERVERS, $server, $target );

    }
    elsif ( $data =~ /^${BOT_PREFIX}ts\s*$/ixms ) {
        return $URT->print_servers( $SERVERS, $server, $target, 'TS' );

    }
    elsif ( $data =~ /^${BOT_PREFIX}ctf\s*$/ixms ) {
        return $URT->print_servers( $SERVERS, $server, $target, 'CTF' );

    }
    elsif ( $data =~ /^${BOT_PREFIX}bomb\s*$/ixms ) {
        return $URT->print_servers( $SERVERS, $server, $target, 'BOMB' );

    }
    elsif ( $data =~ /^${BOT_PREFIX}players?\s+(.+)\s*$/ixms ) {
        my $request = $1;
        return $URT->print_filtered_players( $SERVERS, $request, $server,
            $target );

    }
    elsif ( $data =~ /^${BOT_PREFIX}settings?\s+(.+)\s*$/ixms ) {
        my $request = $1;
        return $URT->print_filtered_settings( $SERVERS, $request, $server,
            $target );

# XXX The server admin didn't want to have rcon exposed even with authorization
#    } elsif ($data =~ /^${BOT_PREFIX}rcon\s+.*$/ixms) {
#        if (! $AUTH->user_in_private($server, $target, $mask)) {
#            return 0;
#        }
#        Irssi::print("Not handling rcon as it was requested by the server admin");
#        return handle_rcon($server, $target, $data);

    }
    elsif ( $data =~ /^${BOT_PREFIX}meow\s*$/ixms ) {
        send_bold_msg( $server, $target, $is_commandline, $MEOW_RESPONSE );

    }
    elsif ( $data =~ /^${BOT_PREFIX}rawr\s*$/ixms ) {
        send_bold_msg( $server, $target, $is_commandline, $RAWR_RESPONSE );

    }
    elsif ( $data =~ /^${BOT_PREFIX}fortune\s*$/ixms ) {
        my @output = Util::Fortune->fortune(0);
        foreach my $line (@output) {
            send_bold_msg( $server, $target, $is_commandline, $line );
        }

    }
    elsif ( $data =~ /^${BOT_PREFIX}fortune(?:_|\s+)off\s*$/ixms ) {
        my @output = Util::Fortune->fortune(1);
        foreach my $line (@output) {
            send_bold_msg( $server, $target, $is_commandline, $line );
        }

    }
    elsif ( $data =~ /^${BOT_PREFIX}servers?(?:_|\s+)status\s*$/ixms ) {
        return $URT->print_servers_status( $SERVERS, $server, $target );

    }
    elsif ( $data =~ /^${BOT_PREFIX}isms?\s*$/ixms ) {
        my $resp = $QUOTES->get_quote_status();
        send_bold_msg( $server, $target, $is_commandline, $resp );

    }
    elsif ( $data =~ /^${BOT_PREFIX}(\S+)isms?\s*$/ixms ) {
        my $msg = $QUOTES->get_ism($1);
        if ( defined($msg) && $msg !~ /^\s*$/xms ) {
            foreach my $line ( @{$msg} ) {
                send_bold_msg( $server, $target, $is_commandline, $line );
            }
        }

## All related to GTV

    }
    elsif ( $data =~ /^${BOT_PREFIX}gtv\s*$/ixms ) {
        send_bold_msg( $server, $target, $is_commandline, GTV_INFO() );

    }
    elsif ( $data =~ /^${BOT_PREFIX}gtv\s+(\S+:\d+)\s+(.+)\s*$/ixms ) {
        my ( $ip, $desc ) = ( $1, $2 );
        if ( $AUTH->trusted_user( $server, $nick, $mask ) ) {
            sanitize_ip_port($ip);
            sanitize_msg($desc);
            send_bold_msg( $server, $target, $is_commandline,
                "Set gtv = " . GTV_INFO() );

        }
        else {
            Irssi::print("Unknown user: $nick ($mask) so not setting GTV info");
            return 0;
        }

    }
    elsif ( $data =~ /^${BOT_PREFIX}gtv(?:_|\s+)ip\s*$/ixms ) {
        send_bold_msg( $server, $target, $is_commandline,
            "gtv_ip = " . Irssi::settings_get_str($GTV_IP) );

    }
    elsif ( $data =~ /^${BOT_PREFIX}gtv(?:_|\s+)ip\s+(\S+:\d+)\s*$/ixms ) {
        my $ip = $1;
        if ( $AUTH->trusted_user( $server, $nick, $mask ) ) {
            sanitize_ip_port($ip);
            send_bold_msg( $server, $target, $is_commandline,
                "Set gtv_ip = " . Irssi::settings_get_str($GTV_IP) );

        }
        else {
            Irssi::print("Unknown user: $nick ($mask) so not setting GTV IP");
            return 0;
        }

    }
    elsif ( $data =~ /^${BOT_PREFIX}gtv(?:_|\s+)msg\s*$/ixms ) {
        send_bold_msg( $server, $target, $is_commandline,
            "gtv_msg = " . Irssi::settings_get_str($GTV_MESSAGE) );

    }
    elsif ( $data =~ /^${BOT_PREFIX}gtv(?:_|\s+)msg\s+(.+)\s*$/ixms ) {
        my $msg = $1;
        if ( $AUTH->trusted_user( $server, $nick, $mask ) ) {
            sanitize_msg($msg);
            send_bold_msg( $server, $target, $is_commandline,
                "Set gtv_msg = " . Irssi::settings_get_str($GTV_MESSAGE) );

        }
        else {
            Irssi::print(
                "Unknown user: $nick ($mask) so not setting GTV message");
            return 0;
        }

## All related to TS3.

    }
    elsif ( $data =~ /^${BOT_PREFIX}reload\s+ts3\s*$/ixms ) {

        # Only allow named users reload the server list
        if ( !$AUTH->user_is_privileged( $server, $nick, $mask ) ) {
            send_bold_msg( $server, $target, $is_commandline,
                "Insufficient access to run this command" );
            return 0;

        }
        else {
            $TS3 = get_ts3_list();
            send_bold_msg( $server, $target, $is_commandline,
                "Reloaded TS3 server information" );
        }

    }
    elsif ( $data =~ /^${BOT_PREFIX}ts3\s+list\s*$/ixms ) {
        send_bold_msg( $server, $target, $is_commandline,
            "Server aliases: "
              . join( ", ", sort { lc($a) cmp lc($b) } ( keys( %{$TS3} ) ) ) );

    }
    elsif ( $data =~ /^${BOT_PREFIX}ts3\s+setup\s*$/ixms ) {
        my @lines;
        foreach my $key ( sort { lc($a) cmp lc($b) } ( keys( %{$TS3} ) ) ) {
            push(
                @lines,
                [
                    "Alias: $key, ",
                    "IP: ",
                    $TS3->{$key}->{ip},
                    ", GUI port: ",
                    $TS3->{$key}->{client_port},
                    ", ServerQuery port: ",
                    $TS3->{$key}->{query_port}
                ]
            );
        }

        my @newlines = Util::IRC::Format->align( \@lines );
        for my $line (@newlines) {
            send_bold_msg( $server, $target, $is_commandline, $line );
        }

    }
    elsif ( $data =~ /^${BOT_PREFIX}ts3\s+(\S+)\s*/ixms ) {

    # handle the ts3 server.  It will return lines on success or undef on error?
        my $name = $1;

        # Extra spam checking with a 3 second delay between commands
        if ( $TS3_AUTH->user_is_spamming( $server, $nick, $mask, $target ) ) {
            Irssi::print("User is spamming ts3 commands");
            return 0;
        }

        my $found = undef;
        my $match = 0;
        while ( my ( $k, $v ) = each %{$TS3} ) {
            if ( index( lc($k), lc($name) ) == 0 ) {
                $found = $k;
                $match++;
            }
        }

        if ( $match <= 0 ) {
            send_bold_msg( $server, $target, $is_commandline,
                "Invalid server prefix.  No matches found" );

        }
        elsif ( $match > 1 ) {
            send_bold_msg( $server, $target, $is_commandline,
                "Too many matches found.  Must be an unique prefix" );

        }
        elsif ( $match == 1 ) {
            my @lines;

            my $ts3 = Util::TS3::Wrapper->new( $TS3->{$found}->{ip},
                      $TS3->{$found}->{query_port} );
            @lines = $ts3->irc_listing( $TS3->{$found}->{client_port} );

            if ( $#lines >= 0 ) {
                my $max_line = $#lines > 15 ? 15 : $#lines;
                for ( my $i = 0 ; $i <= $max_line ; $i++ ) {
                    send_bold_msg( $server, $target, $is_commandline,
                        $lines[$i] );
                }
            }

        }
        else {
            Irssi::print(qq{Should not be here});
        }

    }
    elsif ( $data =~ m{^${BOT_PREFIX}wraithbot\s*$}ixms ) {
        send_bold_msg( $server, $target, $is_commandline,
"wraithbot is maintained by undeadzy https://github.com/undeadzy/wraithbot"
        );

    }
    elsif ( $data =~ m{^${BOT_PREFIX}(gtv|ts3)}ixms ) {
        send_bold_msg( $server, $target, $is_commandline,
            "Error: " . $HELP_MESSAGE );
        return 0;

    }
    elsif ( $data =~ /^${BOT_PREFIX}help\s*$/ixms ) {
        send_bold_msg( $server, $target, $is_commandline, $HELP_MESSAGE );

    }
    else {

        # Irssi::print("Unknown command: $data");
        return 0;
    }

    return 1;
}

# IRSSI callback: message private
#
# We don't allow for rcon commands in a /query.  It must be done in a channel for easier
# verification.  People won't abuse it if others need to see it.  Plus it makes it easier
# to track changes like passwords.
sub msg_private_servers {
    my ( $server, $data, $nick, $mask ) = @_;

    # Only allow trusted users to private message the bot
    if ( !$AUTH->trusted_user( $server, $nick, $mask ) ) {
        Irssi::print("Unknown user: $nick ($mask)");
        return 0;
    }

    return handle_actions( $server, $data, $nick, $mask, $nick, 0 );
}

# IRSSI callback: message public
sub msg_public_servers {
    my ( $server, $data, $nick, $mask, $target ) = @_;

    return handle_actions( $server, $data, $nick, $mask, $target, 0 );
}

# IRSSI callback: message own_public
sub msg_public_own_servers {
    my ( $server, $data, $target ) = @_;

    return handle_actions( $server, $data, q{wraithbot},
        q{~wraithbot@wraithbot.bot.gamesurge},
        $target, 0 );
}

# cmd_* is a convention for irssi commands that can be run interactively in the bot.
# These use command_binds to create new commands in the session.
sub bot_cmd {
    my ( $cmd, $args, $server, $target ) = @_;

    return handle_actions(
        $server, $cmd . q{ } . $args,
        q{wraithbot}, q{~wraithbot@wraithbot.bot.gamesurge},
        $target, 1
    );
}

# IRSSI command
sub cmd_rcon {
    my ( $args, $server, $target ) = @_;

    if ( !$server || !$server->{connected} ) {
        Irssi::print("Not connected to server");
        return;
    }

    # They don't want rcon so don't even mention it in the channel.
    # return handle_rcon($server, $target->{name}, '@rcon ' . $args);

    return handle_rcon( undef, undef, '@rcon ' . $args );
}

# Debugging command to print a lot of useful info.
sub cmd_print_users {
    my ( $args, $server, $target ) = @_;

    my @channels = Irssi::channels();

    Irssi::print("Printing users");
    print Dumper(
        {
            args     => $args,
            server   => $server,
            target   => $target,
            channels => \@channels
        }
    );

    foreach my $c (@channels) {
        my @users = $c->nicks();
        print Dumper( { c => $c, users => \@users } );
    }

    return 1;
}

# Creates irssi commands.  For instance, inside of the bot's session, you can use
# /urt_rawr and it will run cmd_urt_rawr.  You have to look at the definition of
# the function to see what arguments, if any, it accepts.
#
# Since handle_actions accepts a is_commandline flag, we don't need special
# functions just for these local actions.
my @commands =
  qw(servers help ts ctf bomb players settings meow rawr fortune fortune_off isms name_ism servers_status print_users gtv gtv_ip gtv_msg);
for my $c (@commands) {
    Irssi::command_bind( "urt_" . $c => sub { bot_cmd( q{!} . $c, @_ ); } );
}

# Don't enable rcon
# Irssi::command_bind("urt_rcon",    "cmd_rcon");

# Callbacks which are fired on events.
# You must enable this so the bot will react to messages in channels.
Irssi::signal_add_last( "message public",     "msg_public_servers" );
Irssi::signal_add_last( "message private",    "msg_private_servers" );
Irssi::signal_add_last( "message own_public", "msg_public_own_servers" );

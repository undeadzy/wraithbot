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

package Util::TS3::Commands;

# Based on the 2010/05/31 edition of the server query manual.

use strict;
use warnings;

use Readonly;
use Carp;

use Util::TS3::Escape;

use version 0.77; our $VERSION = version->declare('v0.0.1');

Readonly my $SERVER     => 'server';
Readonly my $PORT       => 'port';
Readonly my $FLOOD_CMDS => 'flood_cmds';
Readonly my $FLOOD_TIME => 'flood_time';
Readonly my $ESCAPE     => 'escape';
Readonly my $IN_USE     => 'in_use';
Readonly my $TS3        => 'ts3';

# Util::TS3::Commands->new();
sub new {
    my ( $inp, $args ) = @_;
    my $class = ref($inp) || $inp;

    my $self = {
        server => $args->{$SERVER},

        port => exists( $args->{$PORT} ) ? $args->{$PORT} : 10011,

        # SERVERINSTANCE_SERVERQUERY_FLOOD_COMMANDS
        flood_cmds => exists( $args->{$FLOOD_CMDS} )
        ? $args->{$FLOOD_CMDS}
        : 10,

        # SERVERINSTANCE_SERVERQUERY_FLOOD_TIME
        flood_time => exists( $args->{$FLOOD_TIME} ) ? $args->{$FLOOD_TIME} : 3,

        escape => Util::TS3::Escape->new(),

        in_use => 0,
    };

    $self->{$ESCAPE} = Util::TS3::Escape->new();

    if ( !defined( $self->{$SERVER} ) ) {
        confess qq{Must supply a server};
    }
    foreach my $check ( $PORT, $FLOOD_TIME, $FLOOD_CMDS ) {
        if ( $self->{$check} !~ /^\d+$/xms ) {
            confess qq{Must supply a numeric $check};
        }
    }

    bless( $self, $class );
    return $self;
}

sub _open {
    my ($self) = @_;

    if ( $self->{$IN_USE} ) {
        return;
    }

    $self->{$TS3} = Net::Telnet->new(
        Host       => $self->{$SERVER},
        Port       => $self->{$PORT},
        Errmode    => "return",
        Timeout    => 10,
        Telnetmode => 0,
        Prompt     => '/error\s+id=\d+\s+msg=\S+(?:\s+failed_permid=\d+)?\n\r/',
        Binmode    => 1,
        Output_record_separator => "\r\n",
        Input_record_separator  => "\n\r"
    );

    # Default is 'die' so instead make it return undef or an empty list
    # depending on the context.
    $self->{$TS3}->errmode("return");

    # Debugging
    # $self->{$TS3}->dump_log(\*STDOUT);
    # $self->{$TS3}->input_log(\*STDOUT);

    # All should display this
    $self->{$TS3}->waitfor('/TS3.*\n\r/');

    # Some TS3 servers don't display this.  Might be something new?
    eval {
        $self->{$TS3}->waitfor(
            Match => '/Welcome to the TeamSpeak 3 ServerQuery interface.*\n\r/',
            Timeout => 1
        );
    };
    $self->{$IN_USE} = 1;

    return 1;
}

sub mark_closed {
    my ($self) = @_;

    $self->{$IN_USE} = 0;

    return 1;
}

sub _send {
    my ( $self, $msg ) = @_;

    my ( $prompt, @output ) = $self->_raw_send($msg);

    if ( $#output != 0 ) {
        confess qq{Expected one line of input for \"$msg\"};
    }

    my $out = $self->{$ESCAPE}->parse_message( $output[0] );
    my $res = $self->{$ESCAPE}->parse_result($prompt);

    return { params => $out, result => $res };
}

sub _raw_send {
    my ( $self, $msg ) = @_;

    if ( !$self->{$IN_USE} ) {
        $self->_open();
    }

    # XXX This should do rate limiting to make sure we don't get blocked.
    my @output = $self->{$TS3}->cmd($msg);
    my $prompt = $self->{$TS3}->last_prompt();

    return ( $prompt, @output );
}

sub _escape {
    my ( $self, $msg ) = @_;

    return $self->{$ESCAPE}->escape($msg);
}

sub help {
    my ( $self, $opt_cmd ) = @_;

    my ( $prompt, @output );
    if ( defined($opt_cmd) ) {
        $self->_check_command_name($opt_cmd);
        ( $prompt, @output ) = $self->_send("help $opt_cmd");

    }
    else {
        ( $prompt, @output ) = $self->_send("help");
    }

    return {
        message => \@output,
        result  => $self->{$ESCAPE}->parse_result($prompt)
    };
}

sub quit {
    my ($self) = @_;
    return $self->_send("quit");
}

sub login {
    my ( $self, $username, $password ) = @_;
    return $self->_send( "login "
          . $self->_escape($username) . " "
          . $self->_escape($password) );
}

sub logout {
    my ($self) = @_;
    return $self->_send("logout");
}

sub version {
    my ($self) = @_;
    return $self->_send("version");
}

sub host_info {
    my ($self) = @_;
    return $self->_send("hostinfo");
}

sub instance_info {
    my ($self) = @_;
    return $self->_send("instanceinfo");
}

sub instance_edit {
    my ( $self, $params ) = @_;

    # XXX The documentation shows all parameters as optional.
    # XXX Is it really optional to not specify anything?
    if ( ref($params) ne 'ARRAY' ) {
        confess qq{Must pass in an array ref of hash refs for options};
    }
    return $self->_send( "instanceedit" . $self->_get_params($params) );
}

sub binding_list {
    my ($self) = @_;
    return $self->_send("bindinglist");
}

# XXX This should be 'use' but that's already in use by Perl
sub use_server {
    my ( $self, $sid, $port ) = @_;

    if ( defined($port) ) {
        $self->_check_port($port);
    }
    if ( defined($sid) ) {
        $self->_check_server_id($sid);
    }

    if ( defined($sid) ) {
        if ( defined($port) ) {
            return $self->_send(
                "use " . $self->_pair( { "sid" => $sid, "port" => $port } ) );
        }
        else {
            return $self->_send( "use " . $self->_pair( { "sid" => $sid } ) );
        }

    }
    else {
        if ( defined($port) ) {
            return $self->_send( "use " . $self->_pair( { "port" => $port } ) );

        }
        else {
            confess qq{Must provide sid and/or port};
        }
    }
}

sub server_list {
    my ( $self, $opts ) = @_;

    if ( !defined($opts) ) {
        return $self->_send("serverlist");
    }
    return $self->_send(
        "serverlist" . $self->_get_opts( $opts, [ 'uid', 'short', 'all' ] ) );
}

sub server_id_get_by_port {
    my ( $self, $port ) = @_;

    $self->_check_port($port);
    return $self->_send( "serveridgetbyport "
          . $self->_pair( { "virtualserver_port" => $port } ) );
}

sub server_delete {
    my ( $self, $id ) = @_;

    $self->_check_server_id($id);
    return $self->_send( "serverdelete " . $self->_pair( { "sid" => $id } ) );
}

sub server_create {
    my ( $self, $name, $props ) = @_;
    return $self->_send( "servercreate "
          . $self->_pair( { "virtualserver_name" => $name } )
          . $self->_get_params($props) );
}

sub server_start {
    my ( $self, $server_id ) = @_;

    $self->_check_server_id($server_id);
    return $self->_send(
        "serverstart " . $self->_pair( { "sid" => $server_id } ) );
}

sub server_stop {
    my ( $self, $server_id ) = @_;

    $self->_check_server_id($server_id);
    return $self->_send(
        "serverstop " . $self->_pair( { "sid" => $server_id } ) );
}

sub server_process_stop {
    my ($self) = @_;
    return $self->_send("serverprocessstop");
}

sub server_info {
    my ($self) = @_;
    return $self->_send("serverinfo");
}

sub server_request_connection_info {
    my ($self) = @_;
    return $self->_send("serverrequestconnectioninfo");
}

sub server_edit {
    my ( $self, $opts ) = @_;
    return $self->_send( "serveredit" . $self->_get_params($opts) );
}

sub server_group_list {
    my ($self) = @_;
    return $self->_send("servergrouplist");
}

sub server_group_add {
    my ( $self, $name, $type ) = @_;

    $self->_check_group_name($name);

    my $result = "servergroupadd " . $self->_pair( { "name" => $name } );
    if ( defined($type) ) {
        $self->_check_non_negative($type);
        $result .= " " . $type;
    }
    return $self->_send($result);
}

sub server_group_del {
    my ( $self, $group_id, $force ) = @_;

    $self->_check_group_id($group_id);
    $self->_check_boolean($force);

    return $self->_send( "servergroupdel "
          . $self->_pair( { 'sgid' => $group_id, 'force' => $force } ) );
}

sub server_group_rename {
    my ( $self, $group_id, $new_name ) = @_;

    $self->_check_group_id($group_id);
    $self->_check_group_name($new_name);
    return $self->_send( "servergrouprename "
          . $self->_pair( { 'sgid' => $group_id, 'name' => $new_name } ) );
}

sub server_group_perm_list {
    my ( $self, $group_id ) = @_;

    $self->_check_group_id($group_id);
    return $self->_send(
        "servergrouppermlist " . $self->_pair( { 'sgid' => $group_id } ) );
}

# XXX The syntax given is not consistent with the usage.
# Therefore, this is based on the usage.
sub server_group_add_perm {
    my ( $self, $group_id, $perms ) = @_;

    $self->_check_group_id($group_id);

    if ( ref($perms) ne 'ARRAY' || scalar( @{$perms} ) < 1 ) {
        confess qq{Must provide an array ref that's non-empty};
    }

    my @permissions =
      $self->_get_permissions( $perms, [ 'value', 'negate', 'skip' ], undef );
    if ( scalar(@permissions) < 1 ) {
        confess qq{Must have at least one permission};
    }

    return $self->_send( "servergroupaddperm "
          . $self->_pair( { 'sgid' => $group_id } ) . " "
          . join( "|", @permissions ) );
}

sub server_group_del_perm {
    my ( $self, $group_id, $perms ) = @_;

    $self->_check_group_id($group_id);

    if ( ref($perms) ne 'ARRAY' || scalar( @{$perms} ) < 1 ) {
        confess qq{Must provide an array ref that's non-empty};
    }

    my @permissions = $self->_get_permissions($perms);
    if ( scalar(@permissions) < 1 ) {
        confess qq{Must have at least one permission};
    }

    return $self->_send( "servergroupaddperm "
          . $self->_pair( { 'sgid' => $group_id } ) . " "
          . join( "|", @permissions ) );
}

sub server_group_add_client {
    my ( $self, $group_id, $client_id ) = @_;

    $self->_check_group_id($group_id);
    $self->_check_client_id($client_id);

    return $self->_send( "servergroupaddclient "
          . $self->_pair( { 'sgid' => $group_id, 'cldbid' => $client_id } ) );
}

sub server_group_del_client {
    my ( $self, $group_id, $client_id ) = @_;

    $self->_check_group_id($group_id);
    $self->_check_client_id($client_id);

    return $self->_send( "servergroupdelclient "
          . $self->_pair( { 'sgid' => $group_id, 'cldbid' => $client_id } ) );
}

sub server_group_client_list {
    my ( $self, $group_id, $use_names ) = @_;

    $self->_check_group_id($group_id);

    my $result =
      "servergroupclientlist " . $self->_pair( { 'sgid' => $group_id } );
    if ( defined($use_names) && $use_names ) {
        $result .= " -names";
    }
    return $self->_send($result);
}

sub server_groups_by_client_id {
    my ( $self, $client_id ) = @_;

    $self->_check_client_id($client_id);

    return $self->_send( "servergroupsbyclientid "
          . $self->_pair( { 'cldbid' => $client_id } ) );
}

sub server_snapshot_create {
    my ($self) = @_;

    return $self->_send("serversnapshotcreate");
}

sub server_snapshot_deploy {
    my ($self) = @_;

    # XXX virtualserver_snapshot appears to mean a certain string?
    return $self->_send("serversnapshotdeploy virtualserver_snapshot");
}

sub server_notify_register {
    my ( $self, $event, $id ) = @_;

    if ( $event !~
        m{^(?:server|channel|textserver|textchannel|textprivate)$}xms )
    {
        confess qq{Invalid server event: "$event"};
    }

    my $result =
      "servernotifyregister " . $self->_pair( { 'event' => $event } );
    if ( defined($id) ) {
        $self->_check_channel_id($id);
        $result .= " " . $self->_pair( { 'id' => $id } );
    }

    return $self->_send($result);
}

sub server_notify_unregister {
    my ($self) = @_;

    return $self->_send("servernotifyunregister");
}

sub gm {
    my ( $self, $msg ) = @_;

    return $self->_send( "gm " . $self->_pair( { "msg" => $msg } ) );
}

sub send_text_message {
    my ( $self, $mode, $target, $msg ) = @_;

    if ( $mode eq '1' ) {
        $self->_check_server_id($target);

    }
    elsif ( $mode eq '2' ) {
        $self->_check_channel_id($target);

    }
    elsif ( $mode eq '3' ) {
        $self->_check_client_id($target);

    }
    else {
        confess qq{Invalid mode: "$mode"};
    }

    return $self->_send( "sendtextmessage "
          . $self->_pair( { "targetmode" => $mode } ) . " "
          . $self->_pair( { "target" => $target, "msg" => $msg } ) );
}

sub log_view {
    my ( $self, $limit, $comparator, $tstamp ) = @_;

    if ( $limit !~ m{^\d+$}xms || $limit < 1 || $limit > 500 ) {
        confess qq{Invalid limit: "$limit"};
    }

    my $result = "logview " . $self->_pair( { 'limitcount' => $limit } );
    if ( defined($comparator) ) {
        if ( $comparator !~ m{^[\<\>=]$}xms ) {
            confess
qq{If comparator is specified, it must be '<', '>' or '=' not: "$comparator"};
        }
        $result .= " " . $self->_pair( { 'comparator' => $comparator } );
    }

    if ( defined($tstamp) ) {
        if ( $tstamp !~ m{^\d{4}-\d{2}-d{2}\\s\d{2}:\d{2}:\d{2}$}xms ) {
            confess qq{Invalid timestamp: "$tstamp"};
        }
        $result .= " " . $self->_pair( { 'timestamp' => $tstamp } );
    }

    return $self->_send($result);
}

sub log_add {
    my ( $self, $level, $msg ) = @_;

    if ( $level !~ m{^\d+$}xms || $level < 1 || $level > 4 ) {
        confess qq{Invalid log level: "$level"};
    }

    return $self->_send( "logadd "
          . $self->_pair( { "loglevel" => $level, "logmsg" => $msg } ) );
}

sub channel_list {
    my ( $self, $opts ) = @_;

    my $result = "channellist";
    if ( defined($opts) ) {
        if ( ref($opts) ne 'HASH' ) {
            confess qq{If present, opts must be a hash ref};
        }

        while ( my ( $k, $v ) = each %{$opts} ) {
            if ( $k !~ m{^-?(?:topic|flags|voice|limits)$}xms ) {
                confess qq{Invalid option: $k};
            }

 # User tried to negate it.  Since there is nothing equivalent to that, skip it.
            if ( !defined($v) || !$v ) {
                next;
            }

            $result .= " -" . $k;
        }
    }

    return $self->_send($result);
}

sub channel_info {
    my ( $self, $id ) = @_;

    $self->_check_channel_id($id);
    return $self->_send( "channelinfo " . $self->_pair( { 'cid' => $id } ) );
}

sub channel_find {
    my ( $self, $pattern ) = @_;

    my $result = "channelfind";
    if ( defined($pattern) ) {
        $result .= " " . $self->_pair( { "pattern" => $pattern } );
    }
    return $self->_send($result);
}

sub channel_move {
    my ( $self, $id, $parent_id, $order ) = @_;

    $self->_check_channel_id($id);
    $self->_check_channel_id($parent_id);

    my $result =
      "channelmove " . $self->_pair( { 'cid' => $id, 'cpid' => $parent_id } );
    if ( defined($order) ) {
        if ($order) {
            $result .= " " . $self->_pair( { 'order' => 1 } );
        }
        else {
            $result .= " " . $self->_pair( { 'order' => 0 } );
        }
    }
    else {
        $result .= " " . $self->_pair( { 'order' => 0 } );
    }

    return $self->_send($result);
}

sub channel_create {
    my ( $self, $name, $props ) = @_;

    $self->_check_channel_name($name);

    return $self->_send( "channelcreate "
          . $self->_pair( { 'channel_name' => $name } )
          . $self->_get_props($props) );
}

sub channel_edit {
    my ( $self, $id, $props ) = @_;

    $self->_check_channel_id($id);

    return $self->_send( "channeledit "
          . $self->_pair( { 'cid' => $id } )
          . $self->_get_props($props) );
}

sub channel_delete {
    my ( $self, $id, $force ) = @_;

    $self->_check_channel_id($id);
    $self->_check_boolean($force);
    return $self->_send( "channeldelete "
          . $self->_pair( { 'cid' => $id, 'force' => $force } ) );
}

sub channel_perm_list {
    my ( $self, $id ) = @_;

    return $self->_send(
        "channelpermlist " . $self->_pair( { 'cid' => $id } ) );
}

sub channel_add_perm {
    my ( $self, $id, $perms ) = @_;

    $self->_check_channel_id($id);

    my @permissions = $self->_get_permissions( $perms, ['value'] );
    if ( scalar(@permissions) < 1 ) {
        confess qq{Must have at least one permission};
    }

    return $self->_send( "channeladdperm "
          . $self->_pair( { ' cid' => $id } ) . " "
          . join( "|", @permissions ) );
}

sub channel_del_perm {
    my ( $self, $id, $perms ) = @_;

    $self->_check_channel_id($id);

    my @permissions = $self->_get_permissions($perms);
    if ( scalar(@permissions) < 1 ) {
        confess qq{Must have at least one permission};
    }

    return $self->_send( "channeldelperm "
          . $self->_pair( { 'cid' => $id } ) . " "
          . join( "|", @permissions ) );
}

sub channel_group_list {
    my ($self) = @_;

    return $self->_send("channelgrouplist");
}

sub channel_group_add {
    my ( $self, $name, $type ) = @_;

    my $result = "channelgroupadd " . $self->_pair( { "name" => $name } );
    if ( defined($type) ) {

        # XXX assumption
        $self->_check_non_negative($type);
        $result .= " " . $self->_pair( { "type" => $type } );
    }

    return $self->_send($result);
}

sub channel_group_del {
    my ( $self, $id, $force ) = @_;

    $self->_check_group_id($id);
    $self->_check_boolean($force);
    return $self->_send( "channelgroupdel "
          . $self->_pair( { 'cgid' => $id, 'force' => $force } ) );
}

sub channel_group_rename {
    my ( $self, $id, $name ) = @_;

    $self->_check_group_id($id);

    return $self->_send( "channelgrouprename "
          . $self->_pair( { "cgid" => $id, "name" => $name } ) );
}

sub channel_group_add_perm {
    my ( $self, $id, $perms ) = @_;

    $self->_check_group_id($id);

    my @permissions = $self->_get_permissions( $perms, ['value'] );
    if ( scalar(@permissions) < 1 ) {
        confess qq{Must have at least one permission};
    }

    return $self->_send( "channelgroupaddperm "
          . $self->_pair( { "cgid" => $id } ) . " "
          . join( "|", @permissions ) );
}

sub channel_group_del_perm {
    my ( $self, $id, $perms ) = @_;

    $self->_check_group_id($id);

    my @permissions = $self->_get_permissions($perms);
    if ( scalar(@permissions) < 1 ) {
        confess qq{Must have at least one permission};
    }

    return $self->_send( "channelgroupdelperm "
          . $self->_pair( { "cgid" => $id } ) . " "
          . join( "|", @permissions ) );
}

sub channel_group_perm_list {
    my ( $self, $id ) = @_;

    $self->_check_group_id($id);

    return $self->_send(
        "channelgrouppermlist " . $self->_pair( { "cgid" => $id } ) );
}

sub channel_group_client_list {
    my ( $self, $channel_id, $client_id, $group_id ) = @_;

    my $result = "channelgroupclientlist";
    if ( defined($channel_id) ) {
        $self->_check_channel_id($channel_id);
        $result .= " " . $self->_pair( { "cid" => $channel_id } );
    }
    if ( defined($client_id) ) {
        $self->_check_client_id($client_id);
        $result .= " " . $self->_pair( { "cldbid" => $client_id } );
    }
    if ( defined($group_id) ) {
        $self->_check_group_id($group_id);
        $result .= " " . $self->_pair( { "cgid" => $group_id } );
    }

    return $self->_send($result);
}

sub set_client_channel_group {
    my ( $self, $group_id, $channel_id, $client_id ) = @_;

    $self->_check_group_id($group_id);
    $self->_check_channel_id($channel_id);
    $self->_check_client_id($client_id);

    return $self->_send(
        "setclientchannelgroup "
          . $self->_pair(
            {
                "cgid"   => $group_id,
                "cid"    => $channel_id,
                "cldbid" => $client_id
            }
          )
    );
}

sub client_list {
    my ( $self, $opts ) = @_;

    my $result = "clientlist";
    while ( my ( $k, $v ) = each( %{$opts} ) ) {
        if ( $k =~ m{^-?(uid|away|voice|times|groups|info)$}ixms ) {
            $result .= " -" . $1;

        }
        else {
            confess qq{Invalid opt: $k};
        }
    }

    return $self->_send($result);
}

sub client_info {
    my ( $self, $id ) = @_;

    $self->_check_client_id($id);

    return $self->_send( "clientinfo " . $self->_pair( { 'clid' => $id } ) );
}

sub client_find {
    my ( $self, $pattern ) = @_;

    return $self->_send(
        "clientfind " . $self->_pair( { 'pattern' => $pattern } ) );
}

sub client_edit {
    my ( $self, $id, $props ) = @_;

    $self->_check_client_id($id);
    return $self->_send( "clientedit "
          . $self->_pair( { 'clid' => $id } )
          . $self->_get_params($props) );
}

sub client_db_list {
    my ( $self, $offset, $duration ) = @_;

    my $result = "clientdblist";
    if ( defined($offset) ) {
        $self->_check_non_negative($offset);
        $result .= " " . $self->_pair( { "start" => $offset } );
    }

    if ( defined($duration) ) {
        $self->_check_non_negative($duration);
        $result .= " " . $self->_pair( { "duration" => $duration } );
    }

    return $self->_send($result);
}

sub client_db_find {
    my ( $self, $pattern, $use_uid ) = @_;

    my $result = "clientdbfind " . $self->_pair( { 'pattern' => $pattern } );
    if ( defined($use_uid) && $use_uid ) {
        $result .= " -uid";
    }

    return $self->_send($result);
}

sub client_db_edit {
    my ( $self, $id, $props ) = @_;

    $self->_check_client_id($id);

    return $self->_send( "clientdbedit "
          . $self->_pair( { "cldbid" => $id } )
          . $self->_get_params($props) );
}

sub client_db_delete {
    my ( $self, $id ) = @_;

    $self->_check_client_id($id);
    return $self->_send(
        "clientdbdelete " . $self->_pair( { 'cldbid' => $id } ) );
}

sub client_get_ids {
    my ( $self, $uid ) = @_;

    $self->_check_client_uid($uid);
    return $self->_send(
        "clientgetids " . $self->_pair( { 'cluid' => $uid } ) );
}

sub client_get_dbid_from_uid {
    my ( $self, $uid ) = @_;

    $self->_check_client_uid($uid);

    return $self->_send(
        "clientgetdbidfromuid " . $self->_pair( { "cluid" => $uid } ) );
}

# XXX dbid is an integer, uid = hexstring?
# Need to check for consistency.  Any others like this?

sub client_get_name_from_uid {
    my ( $self, $uid ) = @_;

    $self->_check_client_uid($uid);

    return $self->_send(
        "clientgetnamefromuid " . $self->_pair( { "cluid" => $uid } ) );
}

sub client_get_name_from_dbid {
    my ( $self, $dbid ) = @_;

    $self->_check_client_id($dbid);

    return $self->_send(
        "clientgetnamefromdbid " . $self->_pair( { "cldbid" => $dbid } ) );
}

sub client_set_server_query_login {
    my ( $self, $username ) = @_;

    return $self->_send( "clientsetserverquerylogin "
          . $self->_pair( { "client_login_name" => $username } ) );
}

sub client_update {
    my ( $self, $props ) = @_;

    return $self->_send( "clientupdate" . $self->_get_props($props) );
}

sub client_move {
    my ( $self, $clients, $channel_id, $password ) = @_;

    if ( ref($clients) ne 'ARRAY' ) {
        confess qq{Clients must be an array of integers};
    }
    $self->_check_channel_id($channel_id);

    my $result = "clientmove";
    foreach my $c ( @{$clients} ) {
        $self->_check_client_id($c);
        $result .= " " . $self->_pair( { "clid" => $c } );
    }

    $result .= " " . $self->_pair( { "cid" => $channel_id } );

    if ( defined($password) ) {
        $result .= " " . $self->_pair( { "cpw" => $password } );
    }

    return $self->_send($result);
}

sub client_kick {
    my ( $self, $clients, $reason_id, $msg ) = @_;

    if ( ref($clients) ne 'ARRAY' ) {
        confess qq{Clients must be an array of integers};
    }
    if ( $reason_id !~ m{^[45]$}xms ) {
        confess qq{Invalid reason ID: "$reason_id"};
    }

    my $result = "clientkick";
    foreach my $c ( @{$clients} ) {
        $self->_check_client_id($c);
        $result .= " " . $self->_pair( { "clid" => $c } );
    }

    $result .= " " . $self->_pair( { "reasonid" => $reason_id } );

    if ( defined($msg) ) {
        if ( length($msg) > 40 ) {
            confess qq{Message may only have 40 characters};
        }
        $result .= " " . $self->_pair( { "reasonmsg" => $msg } );
    }

    return $self->_send($result);
}

sub client_poke {
    my ( $self, $clients, $msg ) = @_;

    if ( ref($clients) ne 'ARRAY' ) {
        confess qq{Clients must be an array of integers};
    }

    my $result = "clienpoke";
    foreach my $c ( @{$clients} ) {
        $self->_check_client_id($c);
        $result .= " " . $self->_pair( { "clid" => $c } );
    }

    # XXX Max limit on size?
    return $self->_send( $result . " " . $self->_pair( { "msg" => $msg } ) );
}

sub client_perm_list {
    my ( $self, $dbid ) = @_;

    $self->_check_client_id($dbid);
    return $self->_send(
        "clientpermlist " . $self->_pair( { "cldbid" => $dbid } ) );
}

sub client_add_perm {
    my ( $self, $dbid, $perms ) = @_;

    $self->_check_dbid($dbid);

    my @permissions = $self->_get_permissions( $perms, [ 'value', 'skip' ] );
    if ( scalar(@permissions) < 1 ) {
        confess qq{Need at least one permission};
    }

    return $self->_send( "clientaddperm "
          . $self->_pair( { "cldbid" => $dbid } ) . " "
          . join( "|", @permissions ) );
}

sub client_del_perm {
    my ( $self, $dbid, $perms ) = @_;

    $self->_check_dbid($dbid);

    my @permissions = $self->_get_permissions($perms);
    if ( scalar(@permissions) < 1 ) {
        confess qq{Need at least one permission};
    }

    return $self->_send( "clientdelperm "
          . $self->_pair( { "cldbid" => $dbid } ) . " "
          . join( "|", @permissions ) );
}

sub channel_client_perm_list {
    my ( $self, $channel_id, $client_id ) = @_;

    $self->_check_channel_id($channel_id);
    $self->_check_client_id($client_id);

    return $self->_send( "channelclientpermlist "
          . $self->_pair( { "cid" => $channel_id, "cldbid" => $client_id } ) );
}

sub channel_client_add_perm {
    my ( $self, $channel_id, $client_id, $perms ) = @_;

    $self->_check_channel_id($channel_id);
    $self->_check_client_id($client_id);

    my @permissions = $self->_get_permissions( $perms, ['value'] );
    if ( scalar(@permissions) < 1 ) {
        confess qq{Need at least one permission};
    }

    return $self->_send( "channelclientaddperm "
          . $self->_pair( { "cid" => $channel_id, "cldbid" => $client_id } )
          . " "
          . join( "|", @permissions ) );
}

sub channel_client_del_perm {
    my ( $self, $channel_id, $client_id, $perms ) = @_;

    $self->_check_channel_id($channel_id);
    $self->_check_client_id($client_id);

    my @permissions = $self->_get_permissions( $perms, ['value'] );
    if ( scalar(@permissions) < 1 ) {
        confess qq{Need at least one permission};
    }

    return $self->_send( "channelclientdelperm "
          . $self->_pair( { "cid" => $channel_id, "cldbid" => $client_id } )
          . " "
          . join( "|", @permissions ) );
}

sub permission_list {
    my ($self) = @_;

    return $self->_send("permissionlist");
}

sub perm_id_get_by_name {
    my ( $self, $perms ) = @_;

    return $self->_send( "permidgetbyname "
          . join( "|", map { $self->_pair( "permsid", $_ ) } @{$perms} ) );
}

sub perm_overview {
    my ( $self, $channel_id, $client_id, $perms ) = @_;

    $self->_check_channel_id($channel_id);
    $self->_check_client_id($client_id);

    my @permissions = $self->_get_permissions( $perms, ['value'] );
    if ( scalar(@permissions) < 1 ) {
        confess qq{Need at least one permission};
    }

    return $self->_send( "permoverview "
          . $self->_pair( { "cid" => $channel_id, "cldbid" => $client_id } )
          . " "
          . join( "|", @permissions ) );
}

sub perm_find {
    my ( $self, $perms ) = @_;

    my @permissions = $self->_get_permissions($perms);
    if ( scalar(@permissions) < 1 ) {
        confess qq{Need at least one permission to search for};
    }

    return $self->_send( "permfind " . join( "|", @permissions ) );
}

sub perm_reset {
    my ($self) = @_;
    return $self->_send("permreset");
}

sub token_list {
    my ($self) = @_;
    return $self->_send("tokenlist");
}

sub token_add {
    my ( $self, $type, $group_id, $channel_id, $opt_desc, $opt_cust ) = @_;

    $self->_check_group_id($group_id);
    $self->_check_channel_id($channel_id);

    my $result = "tokenadd "
      . $self->_pair(
        {
            'tokentype' => $type,
            'tokenid1'  => $group_id,
            'tokenid2'  => $channel_id
        }
      );
    if ( defined($opt_desc) ) {
        $result .= " " . $self->_pair( { 'tokendescription' => $opt_desc } );
    }
    if ( defined($opt_cust) ) {
        $result .= " " . $self->_pair( { 'tokencustomset' => $opt_cust } );
    }

    return $self->_send($result);
}

sub token_delete {
    my ( $self, $token ) = @_;

    $self->_check_token($token);
    return $self->_send(
        "tokendelete " . $self->_pair( { 'token' => $token } ) );
}

sub token_use {
    my ( $self, $token ) = @_;

    $self->_check_token($token);
    return $self->_send( "tokenuse " . $self->_pair( { 'token' => $token } ) );
}

sub message_list {
    my ($self) = @_;
    return $self->_send("messagelist");
}

sub message_add {
    my ( $self, $client_id, $subject, $msg ) = @_;

    $self->_check_client_id($client_id);

    return $self->_send(
        "messageadd "
          . $self->_pair(
            { 'cluid' => $client_id, 'subject' => $subject, 'message' => $msg }
          )
    );
}

sub message_get {
    my ( $self, $msg_id ) = @_;

    $self->_check_message_id($msg_id);
    return $self->_send(
        "messageget " . $self->_pair( { 'msgid' => $msg_id } ) );
}

sub message_update_flag {
    my ( $self, $msg_id, $flag ) = @_;

    $self->_check_message_id($msg_id);
    $self->_check_boolean($flag);
    return $self->_send( "messageupdateflag "
          . $self->_pair( { 'msgid' => $msg_id, 'flag' => $flag } ) );
}

sub message_del {
    my ( $self, $msg_id ) = @_;

    $self->_check_message_id($msg_id);
    return $self->_send(
        "messagedel " . $self->_pair( { 'msgid' => $msg_id } ) );
}

sub complain_list {
    my ( $self, $target_id ) = @_;

    my $results = "complainlist";

    if ( defined($target_id) ) {
        $self->_check_db_id($target_id);
        $results .= " " . $self->_pair( { 'tcldbid' => $target_id } );
    }
    return $self->_send($results);
}

sub complain_add {
    my ( $self, $target_id, $msg ) = @_;

    $self->_check_db_id($target_id);
    return $self->_send( "complainadd "
          . $self->_pair( { 'tcldbid' => $target_id, 'message' => $msg } ) );
}

sub complain_del {
    my ( $self, $target_id, $from_id ) = @_;

    $self->_check_db_id($target_id);
    $self->_check_db_id($from_id);
    return $self->_send( "complaindel "
          . $self->_pair( { 'tcldbid' => $target_id, 'fcldbid' => $from_id } )
    );
}

sub complain_del_all {
    my ( $self, $target_id ) = @_;

    $self->_check_db_id($target_id);
    return $self->_send(
        "complaindelall " . $self->_pair( { 'tcldbid' => $target_id } ) );
}

sub ban_client {
    my ( $self, $client_id, $opt_time, $opt_reason ) = @_;

    $self->_check_client_id($client_id);

    my $results = "banclient " . $self->_pair( { 'clid' => $client_id } );
    if ( defined($opt_time) ) {
        $self->_check_non_negative($opt_time);
        $results .= " " . $self->_pair( { 'time' => $opt_time } );
    }
    if ( defined($opt_reason) ) {
        $results .= " " . $self->_pair( { 'banreason' => $opt_reason } );
    }

    return $self->_send($results);
}

sub ban_list {
    my ($self) = @_;
    return $self->_send("banlist");
}

sub ban_add {
    my ( $self, $ip, $name, $uid, $time, $reason ) = @_;

    if ( !defined($ip) && !defined($name) && !defined($uid) ) {
        confess qq{At least one of ip, name or uid must be specified};
    }

    my $results = "banadd";

    if ( defined($ip) ) {
        $results .= " " . $self->_pair( { 'ip' => $ip } );
    }
    if ( defined($name) ) {
        $results .= " " . $self->_pair( { 'name' => $name } );
    }
    if ( defined($uid) ) {
        $results .= " " . $self->_pair( { 'uid' => $uid } );
    }
    if ( defined($time) ) {
        $self->_check_non_negative($time);
        $results .= " " . $self->_pair( { 'time' => $time } );
    }
    if ( defined($reason) ) {
        $results .= " " . $self->_pair( { 'banreason' => $reason } );
    }

    return $self->_send($results);
}

sub ban_del {
    my ( $self, $id ) = @_;

    $self->_check_ban_id($id);
    return $self->_send( "bandel " . $self->_pair( { 'banid' => $id } ) );
}

sub ban_del_all {
    my ($self) = @_;
    return $self->_send("bandelall");
}

sub ft_init_upload {
    my ( $self, $transfer_id, $path, $channel_id, $channel_pass, $size,
        $overwrite, $resume )
      = @_;

    $self->_check_non_negative($transfer_id);
    $self->_check_channel_id($channel_id);
    $self->_check_non_negative($size);
    $self->_check_boolean($overwrite);
    $self->_check_boolean($resume);

    return $self->_send(
        "ftinitupload "
          . $self->_pair(
            {
                'clientftfid' => $transfer_id,
                'name'        => $path,
                'cid'         => $channel_id,
                'cpw'         => $channel_pass,
                'size'        => $size,
                'overwrite'   => $overwrite,
                'resume'      => $resume
            }
          )
    );
}

sub ft_init_download {
    my ( $self, $transfer_id, $path, $channel_id, $channel_pass, $pos ) = @_;

    $self->_check_non_negative($transfer_id);
    $self->_check_channel_id($channel_id);
    $self->_check_non_negative($pos);

    return $self->_send(
        "ftinitdownload "
          . $self->_pair(
            {
                'clientftfid' => $transfer_id,
                'name'        => $path,
                'cid'         => $channel_id,
                'cpw'         => $channel_pass,
                'pos'         => $pos
            }
          )
    );
}

sub ft_list {
    my ($self) = @_;
    return $self->_send("ftlist");
}

sub ft_get_file_list {
    my ( $self, $channel_id, $channel_pass, $path ) = @_;

    $self->_check_channel_id($channel_id);
    return $self->_send(
        "ftgetfilelist "
          . $self->_pair(
            {
                'cid'  => $channel_id,
                'cpw'  => $channel_pass,
                'path' => $path
            }
          )
    );
}

sub ft_get_file_info {
    my ( $self, $channel_id, $channel_pass, $names ) = @_;

    $self->_check_channel_id($channel_id);
    return $self->_send( "ftgetfileinfo "
          . $self->_pair( { 'cid' => $channel_id, 'cpw' => $channel_pass } )
          . " "
          . join( "|", map { $self->_pair( { 'name' => $_ } ) } @{$names} ) );
}

sub ft_stop {
    my ( $self, $transfer_id, $delete ) = @_;

    $self->_check_non_negative($transfer_id);
    $self->_check_boolean($delete);
    return $self->_send(
        "ftstop "
          . $self->_pair(
            { 'serverftfid' => $transfer_id, 'delete' => $delete }
          )
    );
}

sub ft_delete_file {
    my ( $self, $channel_id, $channel_pass, $names ) = @_;

    $self->_check_channel_id($channel_id);
    return $self->_send( "ftdeletefile "
          . $self->_pair( { 'cid' => $channel_id, 'cpw' => $channel_pass } )
          . " "
          . join( "|", map { $self->_pair( { 'name' => $_ } ) } @{$names} ) );
}

sub ft_create_dir {
    my ( $self, $channel_id, $channel_pass, $path ) = @_;

    $self->_check_channel_id($channel_id);
    return $self->_send(
        "ftcreatedir "
          . $self->_pair(
            {
                'cid'     => $channel_id,
                'cpw'     => $channel_pass,
                'dirname' => $path
            }
          )
    );
}

sub ft_rename_file {
    my ( $self, $channel_id, $channel_pass, $target_channel, $target_pass,
        $old_name, $new_name )
      = @_;

    $self->_check_channel_id($channel_id);

    my $result = "ftrenamefile "
      . $self->_pair( { 'cid' => $channel_id, 'cpw' => $channel_pass } );

    if ( defined($target_channel) ) {
        $result .= " " . $self->_pair( { 'tcid' => $target_channel } );
    }
    if ( defined($target_pass) ) {
        $result .= " " . $self->_pair( { 'tcpw' => $target_pass } );
    }
    $result .=
      " " . $self->_pair( { 'oldname' => $old_name, 'newname' => $new_name } );

    return $self->_send($result);
}

sub custom_search {
    my ( $self, $ident, $pattern ) = @_;
    return $self->_send( "customsearch "
          . $self->_pair( { 'ident' => $ident, 'pattern' => $pattern } ) );
}

sub custom_info {
    my ( $self, $db_id ) = @_;

    $self->_check_db_id($db_id);
    return $self->_send(
        "custominfo " . $self->_pair( { 'cldbid' => $db_id } ) );
}

sub who_am_i {
    my ($self) = @_;
    return $self->_send("whoami");
}

##
## Start of the utility functions
##

sub _check_boolean {
    my ( $self, $value ) = @_;

    if ( $value !~ m{^[01]$}xms ) {
        confess qq{Invalid flag: $value};
    }
}

sub _check_group_id {
    my ( $self, $id ) = @_;

    if ( $id !~ m{^\d+$}xms ) {
        confess qq{Invalid group id: "$id"};
    }
}

sub _check_group_name {
    my ( $self, $name ) = @_;

    if ( $name !~ m{^\S+$}xms ) {
        confess qq{Invalid group name: "$name"};
    }
}

sub _check_server_id {
    my ( $self, $id ) = @_;

    if ( $id !~ m{^\d+$}xms ) {
        confess qq{Invalid server id: "$id"};
    }
}

sub _check_port {
    my ( $self, $port ) = @_;

    if ( $port !~ m{^\d+$}xms || $port >= 2**16 ) {
        confess qq{Invalid port: "$port"};
    }
}

sub _check_command_name {
    my ( $self, $name ) = @_;

    if ( $name !~ m{^[a-z0-9_]+$}xms ) {
        confess qq{Invalid command name: "$name"};
    }
}

sub _check_non_negative {
    my ( $self, $value ) = @_;

    if ( $value !~ m{^\d+$}xms ) {
        confess qq{Must be a non-negatve integer: $value};
    }
}

sub _pair {
    my ( $self, $value_ref ) = @_;

    my $result;
    while ( my ( $k, $v ) = each( %{$value_ref} ) ) {
        if ( defined($result) ) {
            $result .= " ";
        }
        if ( !defined($k) || !defined($v) ) {
            confess qq{Key and value must be defined};
        }

        $result .= $self->_escape($k) . "=" . $self->_escape($v);
    }

    return $result;
}

sub _get_opts {
    my ( $self, $opts, $avail ) = @_;

    my $re = q{^-?(} . join( "|", map { "\Q" . $_ . "\E" } @{$avail} ) . q{)$};

    my $result = "";
    while ( my ( $k, $v ) = each( %{$opts} ) ) {
        if ( $k =~ m{$re}ixms ) {
            $result .= " -" . $self->_escape($1);

        }
        else {
            confess qq{Invalid opt: $k};
        }
    }

    return $result;
}

sub _get_params {
    my ( $self, $props ) = @_;

    my $result = "";
    if ( defined($props) ) {
        if ( ref($props) ne 'ARRAY' ) {
            confess qq{If provided, props must be an array ref of hash ref};
        }

        foreach my $p ( @{$props} ) {
            if ( ref($p) ne 'HASH' || keys( %{$p} ) != 1 ) {
                confess qq{Invalid prop: $p};
            }
            if ( $p->[0] !~ m{^\S+$}xms ) {
                confess qq{Invalid key: "} . $p->[0] . q{"};
            }
            if ( $p->[1] !~ m{^\S+$}xms ) {
                confess qq{Invalid value: "} . $p->[1] . q{"};
            }

            $result .= " " . $self->_pair( $p->[0], $p->[1] );
        }
    }

    return $result;
}

sub _get_permissions {
    my ( $self, $perms, $required, $optional ) = @_;

    if ( ref($perms) ne 'ARRAY' ) {
        confess qq{Must pass in an array ref of permissions};
    }
    if ( defined($required) && ref($required) ne 'HASH' ) {
        confess
qq{If present, must pass in a hash ref of required attributes besides id/sid};
    }
    if ( defined($optional) && ref($optional) ne 'HASH' ) {
        confess
qq{If present, must pass in a hash ref of optional attributes besides id/sid};
    }

    my @permissions;
    foreach my $p ( @{$perms} ) {
        my $result = "";
        if (   exists( $p->{id} )
            && !exists( $p->{sid} )
            && $p->{id} =~ m{^\d+$}xms )
        {
            $result .= $self->_pair( { "permid" => $p->{id} } );

        }
        elsif ( !exists( $p->{id} ) && exists( $p->{sid} ) ) {
            $result .= $self->_pair( { "permsid" => $p->{sid} } );

        }
        else {
            confess qq{Must have exactly one of id or sid with a valid value};
        }

        if ( defined($required) ) {
            while ( my ( $k, $v ) = each( %{$required} ) ) {
                if ( exists( $p->{$k} ) ) {
                    $result .= " " . $self->_pair( { "perm${k}" => $p->{$k} } );
                }
                else {
                    confess qq{Must have a valid $k};
                }
            }
        }

        if ( defined($optional) ) {
            while ( my ( $k, $v ) = each( %{$optional} ) ) {
                if ( exists( $p->{$k} ) ) {
                    $result .= " " . $self->_pair( { "perm${k}" => $p->{$k} } );
                }
            }
        }

        push( @permissions, $result );
    }

    return @permissions;
}

1;

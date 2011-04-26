wraithbot 0.0.1
===============

This is the Team Veneration / Clan iCu* IRC bot running on gamesurge in
*#team-veneration*, *#icu* and *#ftwgl*.  I started this because I was tired
of xqf and qstat and wanted a way to query servers with filters for certain
clans.  Since everyone can see the output, it's more social and we get more
people to join that way.  It also has filters to report when pubs have bots
(yuck) or when mid to top tier clans are playing.

The setup isn't the greatest.  I started off with a small script to query
game servers and it grew from there.  These should probably be plugins like
other IRC bots use.

Screenshot
----------

    20:21 <@undeadzy> !ctf
    20:21 <@wraithbot> UrT East            CTF 21/24 abbey      74.207.235.61:27961   
    20:21 <@wraithbot> wTf SD              CTF  8/20 abbey      64.156.193.115:27963  4 bots
    20:21 <@wraithbot> Spray and Pray      CTF 19/22 turnpike   8.6.15.92:27960       1 iCu*
    20:21 <@wraithbot> fidelitas           CTF  6/16 elgin      85.25.120.160:30100

    20:25 <undeadzy> !help
    20:25 <wraithbot> Available commands (restricted to certain servers): !ts, !ctf, !bomb, !servers_status, !players <server name|IP>, !meow, !rawr, !fortune, !fortune_off, !isms

    20:26 <undeadzy> !server_status
    20:26 <wraithbot> Online: wTf SD, VeX, UrT East, LA (GS) iCu*, Dallas (PP) iCu*, Call of Nooby, Dallas (Seph) iCu*, THC, eVo, Pro UrT East, Casatown, Spray and Pray, Reserve Casatown, NRG, fidelitas, =jF=, FTW pub

    20:26 <undeadzy> !players urt
    20:26 <wraithbot> UrT East (74.207.235.61:27961) = <list of users here>

Note that recent versions have smarter filtering so it doesn't restrict
the input unnecessarily.


Configuration
-------------

Most of the configuration that can rapidly change (TS3 servers, UrT servers, or
clans) are in the **conf/** directory.

The rcon configuration is INI style and never committed to here.


Background
----------

This is an IRC bot using [irssi](http://www.irssi.org/).  It uses
[Perl](http://www.perl.org/) because that's all irssi supports.
I opted for writing an IRC bot in Perl for irssi versus standalone clients like
*gozerbot*, *phenny*, *supybot*, etc because this is a full fledged client with
all the nice features of irssi.

If you're looking for an IRC client to use without a bot, irssi is the best one
that I have found.

This bot requires a number of packages in order to run.  It's designed for an
Unix-like operating system.  I use it with [Debian](http://www.debian.org/).


Requirements
------------

You'll need the following programs:

* irssi
* perl
* fortune   # optional

And these Perl modules

* Config::IniFiles
* Net::Telnet
* Text::Wrap
* Readonly
* IPC::System::Simple
* DateTime::Format::Natural
* String::Approx
* Net::GitHub
* Date::Parse
* version 0.77 or above

These are needed for some tests but not the execution

* Perl::Critic
* Perl::Critic::Utils
* Test::Perl::Critic


Usage
-----

To load this bot, place everything in ~/.irssi/scripts and then run:

    /script load urt_bot

If you want to unload the bot, use:

    /script reset

as this will unload everything.  If you only do:

    /script unload urt_bot

then it doesn't unload everything because we're loading modules.


TS3 SETUP
---------

If you know the client port and server query port, you can add TS3 servers
to the list.

Here's how you can check.  This is an example of a server with a functioning
server query but insufficient permissions for guests.

    me@wraithbot:~/github/wraithbot/wraithbot$ telnet W.X.Y.Z 10011
    Trying W.X.Y.Z...
    Connected to W.X.Y.Z.
    Escape character is '^]'.
    TS3
    Welcome to the TeamSpeak 3 ServerQuery interface, type "help" for a list of commands and "help <command>" for information on a specific command.
    use port=9987
    error id=0 msg=ok
    clientlist
    error id=2568 msg=insufficient\sclient\spermissions failed_permid=8474
    quit
    Connection closed by foreign host.

You may also see this situation depending on the permissions:

    me@wraithbot:~/github/wraithbot/wraithbot$ telnet W.X.Y.Z 10011
    Trying W.X.Y.Z...
    Connected to W.X.Y.Z.
    Escape character is '^]'.

and then it hangs there.  In either case, change these permissions and it should work.


To enable permissions for guests, use these in the GUI:

    Permissions -> Server Groups -> Guest

On the right side, select Permissions (Detailed) -> Virtual Server -> Information
and enable these:

* View virtual server info
* View virtual server connection info
* View list of existing channels
* View list of clients online


LIMITATIONS
-----------

I deliberately use IPs rather than hostnames in all areas.  This is because I
didn't want someone to change their DNS entry to point to another IP and have
the bot try to connect to it.

It only supports TS3 currently because that's what 90% of the UrT clans use.


NOTES
-----

I get 3 of these on the first call to @servers.  I have found lots of people with the same problem
but no one has an answer.  It doesn't appear to affect anything.

    Can't locate package Irssi::Nick for @Irssi::Irc::Nick::ISA at <PATH> line <XYZ>.

It's an open bug since 2005: http://bugs.irssi.org/index.php?do=details&task_id=242&project=5&pagenum=12

If you modify this, try to make the output as condensed as possible to avoid client/server
buffering.

Be careful with regex that reference channels.  I'm using /x which makes '#' a comment.  You need to either
use quotemeta or escape the '#' so it doesn't effectively end the regex.


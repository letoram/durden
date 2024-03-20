About
=====
Durden is a free (3-clause BSD) desktop environment for Arcan, thus it requires
a working arcan installation, optionally set-up with compatible launch targets
etc. See the [Arcan](http://github.com/letoram/arcan) repository and wiki for
those details.

For detailed feature and use descriptions, please see the
[Durden-Web](http://durden.arcan-fe.com). The individual markdown pages are
also accessible in the gh-pages branch of the durden repository.

Authors and Contact
=====
Development is discussed on the IRC channel #arcan on the Freenode network
(chat.freenode.org)

2015-2019, Björn Ståhl

Licensing
=====
Durden is Licensed in the 3-clause BSD format that can be found in the
licensing file.

The included terminal font, Hack-Bold is (c) Chris Simpkins
and licensed under the Apache-2.0 license.

The included UI font, IBM/Plex, is provided free via the SIL OpenFont License 1.1.

The included fallback font, Emoji-One, is provided free (cc-by 4.0 attribution)
by http://emojione.com

Hacking
=====
See the HACKING.md file for information on where/how to extend and modify.

Installation
============
Durden requires a working installation of [arcan](https://github.com/letoram/arcan)
so please refer to that project for low level details, which also may cover
system keymap (the facilities provided in durden are higher level overrides).

The arcan documentation also covers specifics on how to get X, wayland and
other clients to work.

Other than that, you need to link or copy the durden subdirectory of this
repository to were arcan looks for applications, or use an absolute path,
like:

    arcan $HOME/durden/durden

See also the starting section below, as well as the configuration sections
further below.

Starting
=====
distr/durden is a support script that can be run to try and automatically
set everything up and start. It also takes care of relaunch/recover if the
program terminated abnormally.

If you have a system that uses the "XDG" set of directories, the script will
build the directory tree in XDG\_DATA\_HOME/arcan, otherwise it will use
$HOME/.arcan. To help debug issues, you can create a 'logs' folder in that
directory and both engine output, Lua crash dumps and frameserver execution
will be stored there.

Configuration (runtime)
=======================
Most changes, from visuals to window management behavior and input device
actions, can be done from within durden and the UI itself using the menu HUD.
By default, this is accessed from META1+G for (global) and META1+T for
current window (target).

All actions in durden are mapped into a huge virtual filesystem tree.
Keybindings, UI buttons etc. are all simply paths within this filesystem.

These are covered in much more detail on the webpage, but the ones you might
want to take extra note of is:

    /global/input/bind/custom
		/global/system/shutdown/yes
		/global/open/terminal
		/global/input/keyboard/maps/bind_sym
		/global/input/keyboard/maps/bind_utf8

Another thing to note is that at startup, after a crash or keyboard plug event,
a fallback helper is activated. This triggers after a number of keypresses
that does not activate a valid keybinding. It will then query for re-binding
key functions, (meta keys, global menu, menu navigation) as a means for
recovering from a broken or unknown keyboard.

You can also reach most paths with a mouse by right- clicking on the active
workspace indicator on the statusbar.

Configuration (manual)
=======================
There are four ways of configuring durden without using the UI:

1. The arcan\_db tool

(See the manpage for more uses of this tool.)

This works offline (without durden running) and only after first successful run.
All current settings are stored in a database. This can be viewed, and changed,
like this:

     arcan_db show_appl durden
		 arcan_db add_appl_kv durden my_key

Or clear all settings and revert to defaults on the next run:

     arcan_db drop_appl durden

This is also used to control which programs (targets) and sets of arguments
(configuration) durden is allowed to run. This restriction is a safety/security
measure. Something like:

    arcan_db add_target test BINARY /usr/bin/test arg1
		arcan_db add_config test default arg2 arg3

Would be added to /global/open/target/test

2. Files

The default settings used on an empty database is found in:

    durden/config.lua

You can also control what is being run at startup in:

    durden/autorun.lua

The first time durden is run, the following script will be run:

    durden/firstrun.lua

Advanced input device configuration is in durden/devmaps for the various
categories of devices.

3. Controls

Everything can be accessed and controlled (while running) using a domain socket.
This is enabled through the (global/settings/system/control=name) path.

If enabled, it will appear in durden/ipc/name. You can use the socat tool to
interact with it and control everything as if using input in the UI directly.

The commands accepted by this socket is any of (ls, readdir, eval, read, write, exec)
to navigate the menu tree, as well as a 'monitor' command which lets you monitor
subsystem activity.

There is also a 'MONITOR' command that lets you monitor one or several subsystems.

There is also a tool in arcan that can be built and run, arcan\_cfgfs, which
allows the control socket to be mounted and treated like a filesystem.

Troubleshooting
====
There are many moving parts that can go wrong, the display server aspects when
it comes to managing GPUs, displays, clients and input devices - as well as
client behaviors, the window management policies and the features themselves.

On top of this, there are a number of special cases, like VT switching, crash-
recovery, display hot-plug, soft-reset and 'suspend-exec until program return'
scenarios that all massage these different subsystems in ways that are hard to
test automatically and for every configuration.

If durden itself crashes, the recovery can be so fast that you won't notice,
but the notification widget (if enabled) on the HUD will likely provide you
with a crash log.

If you suspect a client of behaving badly, you can start it with the environment
ARCAN\_SHMIF\_DEBUG=1 to get a trace of what goes on, and there are multiple
tools in the arcan source repository for live-inspecting the state of clients.

You can also ask a client to provide a debug view for you, if it supports that
feature, by going to /target/video/advanced/debug\_window - calling it multiple
times may provide multiple levels of debug output.

Then there are logging facilities for all the frameservers, durden itself (if
run through the launcher script) and .lua snapshots on soft-crashes. These are
all enabled by creating a 'logs' directory inside your .arcan folder (on non-xdg
systems, that would be $HOME/.arcan) and restart durden.

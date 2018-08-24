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

2015-2018, Björn Ståhl

Licensing
=====
Durden is Licensed in the 3-clause BSD format that can be found in the
licensing file.

The included terminal font, Hack-Bold is (c) Chris Simpkins
and licensed under the Apache-2.0 license.

The included UI font, designosaur, is provided free (cc-by 3.0 attribution)
by Archy Studio, http://www.archystudio.com

The included fallback font, Emoji-One, is provided free (cc-by 4.0 attribution)
by http://emojione.com

Hacking
=====
See the HACKING.md file for information on where/how to extend and modify.

Starting / Configuring
=====
Make sure that arcan is built with support for builtin frameservers for
terminal, decode, encode, remoting etc. else those features will be missing.
Durden probes for available engine features and enables/disables access to
these accordingly. You can simply check for binaries prefixed with afsrv_

distr/durden is a support script that can be run to try and automatically
set everything up and start. It also takes care of relaunch/recover if the
program terminated abnormally.

If you have a system that uses the XDG_ set of directories, the script will
build the directory tree in XDG\_DATA\_HOME/arcan, otherwise it will use
$HOME/.arcan. To help debug issues, you can create a 'logs' folder in that
directory and both engine output, Lua crash dumps and frameserver execution
will be stored there.

Most configuration should be able to be performed interactively from within
the UI itself. Should this fail or you set things up in an unrecoverably
broken way, you can shutdown arcan and then use the 'arcan_db' tool to
access all configuration options:

     arcan_db show_appl durden
		 arcan_db add_appl_kv durden my_key

Or clear all settings and revert to defaults:

     arcan_db drop_appl durden

## Manually

Install by adding or symlinking the durden subdirectory of the git repository
to your home appl folder (/home/myuser/.arcan/appl/durden) or start arcan
with an explicit path reference, e.g.

     arcan /home/myuser/path/to/durden/durden

Start arcan with the resource path set to whatever directory subtree you
want to be able to access for assets when browsing for images, video etc.

e.g. arcan -p /home/myuser/stuff durden

There are numerous other ways for setting this up, see the Arcan wiki and
manpages for configuration options. If you're "lucky" (linux, normal "no-X"
VT, build dependencies fullfilled and KMS/GBM on) the entire process should
land in something like:

     git clone https://github.com/letoram/arcan.git
     git clone https://github.com/letoram/durden.git
     cd arcan/external/git; bash ./clone.sh
     cd ../../ ; mkdir build ; cd build
     cmake -DVIDEO_PLATFORM=egl-dri -DSTATIC_SQLITE3=ON -DSTATIC_OPENAL=ON
        -DSTATIC_FREETYPE=ON ../src
     make -j 8
     ./arcan ../../durden/durden

Note that this will need to be run suid (preferred) or as root due to rules
the kernel imposes on 'drmMaster'. If suid, the engine will fork out a child
and only direct device access will run privileged.

If you are on a more limited platform, like raspberry pi, you can try the
the -DVIDEO\_PLATFORM=egl-gles -DAGP\_PLATFORM=gles2 build, which should work
with the proprietary drivers. You will also need to activate 'simple' display
mode which deactivates some features:

     arcan_db add_appl_kv durden display_simple true

Note: the egl-dri video platforms are for running this as a dedicated desktop,
if you just want to try things out, use -DVIDEO\_PLATFORM=sdl instead. Some
features when it comes to display management and input will behave differently,
and you likely want to bind a key for enabling/disabling cursor locking.

Another option, if your drivers give you accelerated GL in X but not working
KMS/DRI is to merely run arcan/durden with SDL as the video platform in
fullscreen- mode and only application, essentially making X your "driver".

Default meta keys are META1: MENU and META2:RSHIFT, look into keybindings.lua
for the currently mapped defaults. If you don't press any of the valid META +
key bindings during the first n (20 or so) keypresses, it is assumed that your
meta bindings are broken and you will be queried for new ones.

Quick! meta1+enter - now you should get a terminal window.

You should also make sure that meta1+g (unless rebound) gives you access to
the global menu, and meta1+h gives you access to the target menu. You can view
or modify the default keybindings in 'durden/keybindings.lua' or you can bind
your own menu paths in global/input/bind/custom. This menu path will also show
the currently custom bound keys.

Also try double-tapping meta-2 and you should see the statusbar change color.
This indicates that all normal bindings are ignored and input is forwarded
raw to the selected window. This is important for clients that need access to
keys you have bound to various key combinations, like Xarcan-, QEmu, and so on.

Troubleshooting
====
There are many moving parts that can go wrong, the display server aspects when
it comes to managing GPUs, displays, clients and input devices - as well as
client behaviors, the window management policies and the features themselves.

On top of this, there are a number of special cases, like VT switching, crash-
recovery, display hot-plug, soft-reset and 'suspend-exec until program return'
scenarios that all massage these different subsystems in ways that are hard to
test.

If durden itself crashes, the recovery can be so fast that you won't notice,
but the notification widget (if enabled) on the HUD will likely provide you
with a crash log.

If you suspect a client of behaving badly, you can start it with the environment
ARCAN\_SHMIF\_DEBUG=1 to get a trace of what goes on, and there are multiple
tools in the arcan source repository for live-inspecting the state of clients.

You can also ask a client to provide a debug view for you, if it supports that
feature, by going to /target/video/advanced/debug\_window - calling it multiple
times may provide multiple levels of debug output.

Durden also provides some special mechanisms, by going to
global/settings/system/debug you can change the debuglevel which enables
widgets that give more information, and special debug commands
(global/system/debug).

Then there are logging facilities for all the frameservers, durden itself (if
run through the launcher script) and .lua snapshots on soft-crashes. These are
all enabled by creating a 'logs' directory inside your .arcan folder (on non-xdg
systems, that would be $HOME/.arcan) and restart durden.

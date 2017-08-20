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

2015-2017, Björn Ståhl

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
these accordingly.

Install by adding or symlinking the durden subdirectory of the git repository
to your home appl folder (/home/myuser/.arcan/appl/durden)

Start arcan with the resource path set to whatever directory subtree you want
to be able to access for assets when browsing for images, video etc.

e.g. arcan -p /home/myuser/stuff durden

There are numerous other ways for setting this up, see the Arcan wiki and
manpages for configuration options. If you're "lucky" (linux, normal "no-X" VT,
build dependencies fullfilled and KMS/GBM on) this should land in something like:

     git clone https://github.com/letoram/arcan.git
     git clone https://github.com/letoram/durden.git
     cd arcan/external/git; bash ./clone.sh
     cd ../../ ; mkdir build ; cd build
     cmake -DVIDEO_PLATFORM=egl-dri -DSTATIC_SQLITE3=ON -DSTATIC_OPENAL=ON
        -DSTATIC_FREETYPE=ON ../src
     make -j 8
     ./arcan ../../durden/durden

If you are on a more limited platform, like raspberry pi, you can try the
the -DVIDEO\_PLATFORM=egl-gles -DAGP\_PLATFORM=gles2 build, which should work
with the proprietary drivers. You will also need to activate 'simple' display
mode which deactivates some features:

     arcan_db add_appl_kv durden display_simple true

Note: the egl-dri video platforms are for running this as a dedicated desktop,
if you just want to try things out, use the _sdl_ platform instead. Some
features when it comes to display management and input will behave differently,
and you likely want to bind a toggle for enabling/disabling cursor locking.

Another option, if your drivers give you accelerated GL in X but not working
KMS/DRI is to merely run arcan/durden with SDL as the video platform in
fullscreen- mode and only application, essentially making X your "driver".

Default meta keys are META1: MENU and META2:RSHIFT, look into keybindings.lua
for the currently mapped defaults. If you don't press any of the META keys
during the first n (20 or so) keypresses, it is assumed that your meta bindings
are broken and you will be queried for new ones.

Quick! meta1+enter - now you should get a terminal window.

You should also make sure that meta1+g (unless rebound) gives you access to
the global menu, and meta1+h gives you access to the target menu (see Bindings
below).

Also try double-tapping meta-2 and you should see the titlebar change color.
This indicates that all normal bindings are ignored and input is forwarded
raw to the selected window. This is important for clients that need access to
keys you have bound to various key combinations, like Xarcan-, QEmu, and so on.

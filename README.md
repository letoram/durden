About
=====

Durden is a simple tiling window manager for Arcan, thus it requires a working
arcan installation, optionally set-up with compatible launch targets etc. It
currently serves like a testing and development ground, much like
[AWB](http://github.com/letoram/awb) and
[Gridle](http://github.com/letoram/gridle) but will become a supported 'real'
desktop environment.

Long-term plans (Q3-Q4 2015) is to make it similar in style and behavior to the
great i3 window manager, but also use and showcase some of the more hardcore and
unique features that arcan provides.

Configuring / Starting
=====

Start arcan with resource path set to durden/res and active appl to durden/durden,
like:

    arcan -p path/to/durden\_root/res path/to/durden\_root/durden

Default meta keys are META1: MENU and META2:RSHIFT, look into keybindings.lua for the
currently mapped functions. If you don't press any of the META keys during the first
n (20 or so) keypresses, it is assumed that your meta bindings are broken and you
will be queried for new ones.

Make sure that arcan is built with support for builtin
frameservers for terminal, decode, encode, remoting etc. else those features will be
missing.

Configuration can be done both statically and dynamically. Statically by editing
gconf/fglobal/keybindings.lua and dynamically through submenus in the input/bind
category. By holding m1 (and m2 if it is a target specific option that should
apply only for the specific configuration) when entering a configuration option
(you can see it on the label color in the menu, green for selections, yellow for
querying values).

Durden listens on the connection key 'durden' (export ARCAN\_CONNPATH=durden) and
this is also set by default in internally spawned terminals.

You should be able to set most (non-visual) settings dynamically without modifying any
files, but if you strongly feel the need to tweak things, look into keybindings.lua and
gconf.lua.

Database Configuration
====
The launch menu (default META1+d) uses preconfigured execution profiles that
are managed with a separate external tool as part of Arcan, check the
[Arcan Wiki](http://github.com/letoram/arcan/wiki) for more details.

Menu Structure
====
In addition to the launch menu and the quick terminal (default META1+enter),
the global actions (META1+g), target actions (META1+t) and target
settings (META1+META2+t) are rather useful.

A flat view of the global menu:

 * Open - Specify URI as a quick- launch
 * Workspace - (Rename, Reassign, Mode, Stash, (dynamic list of stashed), Save, Load)
 * Display - (Rescan) + (dynamic list of displays, options to resize / toggle)
 * System - (Shutdown, Reload, Switch Appl)
 * Debug - (Save state)
 * Input - (Rescan, Bind, Dynamic list of Devices, options to calibrate / set default map)
 * Audio - (Mute, Gain)

Target actions will vary with the kind of target that is running, some options
are always available (like setting gain).

Statusbar
====
Durden looks for a named pipe (FIFO) in APPLTEMP (usually the same as the appl dir
specified as last argument to arcan) with the name *durden\_cmd*. This pipe can be
used to send external commands similar to navigating the menus, and to update the
statusbar. For instance, using i3status:

    mkfifo c ~/durden/durden_cmd
    i3status | sed -e 's/^/status:/' > ~/durden/durden_cmd

Repository
=====

_files that might be of interest)_

    durden/
        gconf.lua        - configuration management (default visuals and sizes)
        keybindings.lua  - active keybindings
        fglobal.lua      - global WM functions
        durden.lua       - main script, input routing and process management
        tiler.lua        - main tiling layout, workspace management etc.
        lbar.lua         - support script for textedit control
        bbar.lua         - binding bar, used for querying keybindings
        browser.lua      - lbar based resource browser
        suppl.lua        - text and menu convinience functions

    durden/atypes/* - menus and settings for specific client subtypes
    durden/builtin/ - global menus and settings, target base menus and settings

    res/
        (mostly cherry-picked from the arcan codebase)
        shared resources, fonts, support scripts for UI features and window
        management (for workspaces that are configured to have "normal" window
        management for compatiblity reasons with multi-window programs).

Flow
====

After initial setup, the default code-paths are as follows:

1. _input event:keyboard_ lookup matching key -> lookup against dispatch
   defined in keybindings.

2. _keybindings dispatch:found_ -> lookup matching function in
   GLOBAL\_FUNCTIONS (fglobal).

3. _keybindings dispatch:not found_ -> grab currently selected window,
   match against window specific dispatch and run (if found).

4. _window dispatch_: not found -> match against window specific translation,
   attach semantic label (if defined) and forward to target.

5. _input event:mouse_ forward to mouse.lua support script, registered
   handlers point into durden for active display.

Other than that, there is the def\_handler (durden.lua) that handles initial
event handling for external connections, that - based on type - can be promoted
to a specialized implementation (as per durden/atypes/*).

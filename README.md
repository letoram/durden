About
=====

Durden is a simple tiling window manager for Arcan, thus it requires a working
arcan installation, optionally set-up with compatible launch targets etc. It
currently serves like a testing and development ground, much like
[AWB](http://github.com/letoram/awb) and
[Gridle](http://github.com/letoram/gridle) but will eventually move over to
be a supported 'real' window manager.

Long-term plans (Q2-Q3 2015) is to make it similar in style and behavior to the
great i3 window manager, but also use and showcase some of the more hardcore and
unique features that arcan provides. Readme and documentation is kept short
as most parts are currently in flux.

Configuring / Starting
=====

Start arcan with resource path set to durden/res and active appl to durden/durden,
like:

    arcan -p path/to/durden\_root/res path/to/durden\_root/durden

Default meta keys are MENU(1) and RSHIFT(2), look into keybindings.lua for the
currently mapped functions. Make sure that arcan is built with support for builtin
frameservers for terminal, decode, encode, etc.

Durden looks for a named pipe (FIFO) in APPLTEMP (usually the same as the appl dir
specified as last argument to arcan) with the name durden\_cmd. This pipe can be
used so send external commands (request rescanning displays and other costly
operations) and to update the statusbar. For instance, using i3status:

    mkfifo c ~/durden/durden_cmd
    i3status | sed -e 's/^/status:/' > ~/durden/durden_cmd

Repository
=====

_files that might be of interest)_

    durden\
        gconf.lua        - configuration management (default visuals and sizes)
        keybindings.lua  - active keybindings
        fglobal.lua      - global WM functions
        durden.lua       - main script, input routing and process management
        tiler.lua        - main tiling layout, workspace management etc.
        lbar.lua         - support script for textedit control
        suppl.lua        - text and menu convinience functions

    durden/atypes/* - menus and settings for specific client subtypes
    durden/builtin/ - global menus and settings, target base menus and settings

    res\
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

About
=====

Durden is a simple tiling window manager for Arcan, thus it requires a working
arcan installation, optionally set-up with compatible launch targets etc. It is
designed to serve as a testing and development ground much like
[AWB](http://github.com/letoram/awb) and [Gridle](http://github.com/letoram/gridle).

Long-term plans (Q2-Q3 2015) is to make it similar in style and behavior to the
great i3 window manager, but also use and showcase some of the more hardcore and
unique features that arcan provides. Readme and documentation is kept short
as most parts are currently in flux.

Configuring / Starting
=====

Start arcan with resource path set to durden/res and active appl to durden/durden,
like:

    arcan -p path/to/durden\_root/res path/to/durden\_root/durden

Default meta keys are MENU (1) and RSHIFT(2), look into keybindings.lua for the
currently mapped functions. Make sure that arcan is built with support for builtin
frameservers for terminal, decode, encode, etc.

Repository
=====

_files that might be of interest)_

    durden\
        durden.lua       - main script
        gconf.lua        - configuration management
        tiler.lua        - main tiling layout, workspace management etc.
        keybindings.lua  - default keybindings

    res\
        (mostly cherry-picked from the arcan codebase)
        shared resources, fonts, support scripts for UI features and window
        management (for workspaces that are configured to have "normal" window
        management for compatiblity reasons with multi-window programs).

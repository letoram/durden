About
=====

Durden is a simple tiling window manager for Arcan, thus it requires a working
arcan installation, optionally set-up with compatible launch targets etc. See the
[Arcan](http://github.com/letoram/arcan) repository and wiki for those details.

Durden serves like a testing and development ground for refining the Arcan Lua
API, much like [AWB](http://github.com/letoram/awb) and
[Gridle](http://github.com/letoram/gridle) but will remain as a supported 'real'
desktop environment, rather than proof of concepts.

For a complete list of features and estimated state, see the _Features and Status_
section below.

Starting / Configuring
=====

Make sure that arcan is built with support for builtin frameservers for
terminal, decode, encode, remoting etc. else those features will be missing.
Durden probes for available engine features and enables/disables access to
these accordingly.

Start arcan with the resource path set to durden/res and active appl to
durden/durden, like this (there are tons of better 'installation' setups, this
is merely to get you going):

		arcan -p path/to/durden\_root/res &path/to/durden\_root/durden

Default meta keys are META1: MENU and META2:RSHIFT, look into keybindings.lua
for the currently mapped functions. If you don't press any of the META keys
during the first n (20 or so) keypresses, it is assumed that your meta bindings
are broken and you will be queried for new ones.

A big point with durden as a window manager is that absolutely no configuration
file editing etc. should be needed, everything is accessible and remappable
from the UI.  Most configuration changes are done through the global menu (by
default, meta1+meta2+g) and through the window menu (by default, meta1+meta2+t
but requires a selected window).

The menus are navigated by default using the arrow keys and enter to select and
you can filter the list of shown items by typing.

Any path or menu item in the global or window menu can be bound to a
keycombination, and this is done by going to global/input/bind custom. You will
be prompted to press the binding you like and then navigate to the menu item
you want to bind it to. To bind a sub-menu, hold meta1 while selecting.

It is however also possible to tweak/modify the startup defaults (see
keybindings.lua and gconf.lua).

Database Configuration
====
The launch bar (default meta1+d) uses preconfigured execution profiles that are
managed with a separate external tool as part of Arcan, called *arcan_db*,
check the [Arcan Wiki](http://github.com/letoram/arcan/wiki) for more details.

Statusbar
====
Durden looks for a named pipe (FIFO) in the APPLTEMP namespace (usually the
same as the appl dir specified as last argument to arcan) with the name
*durden\_cmd*. This pipe can be used to send external commands similar to
navigating the menus, and to update the statusbar. For instance, using
i3status:

    mkfifo c ~/durden/durden_cmd
    i3status | sed -e 's/^/status:/' > ~/durden/durden_cmd

Features and Status
=====
To get an overview of the features that have been implemented and features that
are being implemented, we have the following list:

- [x] Basic Window Management Modes: float, tab, vertical-tab, tiled, fullscreen
- [ ] Workspace Management
  - [x] Naming/Renaming
  - [x] Searching Based On Name
  - [ ] Saving/Restoring Layout
  - [ ] Hide Named Workspaces
- [ ] Basic Window Management
  - [x] Reassign
  - [ ] Named Reassign
  - [x] Merge/Split
  - [ ] Swap Left/Right/Up/Down
- [x] Visual Enhancements
  - [x] Animated Transitions (fade, move)
  - [x] Dim-Layer on Menus
  - [x] Configurable Bar Positioning
  - [x] Workspace Event Notification
  - [ ] Mouse Cursor Event Flash
  - [ ] Font Customization
  - [ ] Color Customization
  - [ ] Window Translucency
- [x] Configurable Border Width/Gaps
- [x] Global and Window- specific audio controls
- [x] Background Images
- [ ] Screen-Rotate Trigger
- [x] Resource Browser
- [ ] IPC
  -  [x] Basic Notification Bar Control
- [ ] Input
  - [ ] Gaming Devices
    - [ ] Analog Calibration
  - [x] Focus-Follows-Mouse
  - [x] Configurable/Per Window Keyboard Repeat
  - [x] Drag Reposition/Resize in Float
  - [ ] Mouse Scale Factors
  - [ ] Mouse Emulation
  - [ ] Mouse-Hover Focus
  - [ ] Mouse Follows Selection
  - [ ] Autohiding Mouse
  - [ ] Macro Record / Replay
  - [ ] Per/Window Keyremapping
  - [ ] Keyboard layout hotswapping
  - [ ] Lock-input-to-Window
  - [ ] LED keybinding highlights
- [ ] Internationalization
  - [ ] Menu Translations
  - [ ] Foreign IME
  - [ ] Unicode Binding
- [ ] Advanced Window Integration
  - [ ] Cloning Windows
  - [ ] State Transfers
  - [ ] Debugging Subwindows
  - [ ] Overlay Surfaces
  - [ ] Customized Titlebar
  - [ ] Customized Cursors, Cursorhints
  - [ ] Customized Border
  - [ ] Content/Scroll Integration
  - [ ] Popup Windows
  - [ ] Font Hinting
  - [ ] LL Origo Invert
  - [ ] Screenreader Support
- [ ] Display Sharing
  - [ ] Recording/Streaming
  - [ ] VNC Server
- [ ] Cut and Paste
  - [ ] Simple Text
  - [ ] Streaming Text
  - [ ] Images
  - [ ] Videos
- [x] Basic Crash Recovery/Reset/Reload
- [ ] Advanced Displays Support
  - [ ] Resolution Switching
  - [x] Synchronization Strategy Switching
  - [ ] Offscreen Workspace Rendering
  - [ ] Home Workspace to Preferred Display
- [ ] ICC / Color Calibration Profiles
- [ ] Redshift Color Temperature
- [ ] Advanced scaling effects

Bear in mind that a lot of these features are primarily mapping to what arcan
already supports an the remaining job is the user interface mapping rather than
time-consuming hardcore development.

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

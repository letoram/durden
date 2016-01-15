About
=====

Durden is a free (3-clause BSD) desktop environment for Arcan, thus it requires
a working arcan installation, optionally set-up with compatible launch targets
etc.  See the [Arcan](http://github.com/letoram/arcan) repository and wiki for
those details.

For a complete list of features and estimated state, see the _Features and
Status_ section below.

Authors and Contact
=====
Development is discussed on the IRC channel #arcan on the Freenode network
(chat.freenode.org)

2015+, Björn Ståhl

Licensing
=====
Durden is Licensed in the 3-clause BSD format that can be found in the
licensing file. The included terminal font, Hack-Bold is (c) Chris Simpkins
and licensed under the Apache-2.0 license.

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

Statusbar / Command Channel
====

By default, durden creates two named pipes (FIFO) in the APPLTEMP namespace
(e.g. export ARCAN\_APPLTEMPPATH=/some/where but defaults to the specified
appldir) with the name (durden\_status) and (durden\_control). These can be
used to run remote controls and to update the statusbar. For instance, using
i3status:

    i3status | sed -e 's/^/status:/' > ~/durden/durden\_

The current commands exposed over the control channel:

    rescan_displays - used for hooking up with output display hotplug monitors
    input_lock_on - disable input processing (except for input_lock bindings)
    input_lock_off - these can be used for cooperatively handle multiple arcan
                     instances with a low-level input platform fighting both
                     interpreting input.

Features and Status
=====
To get an overview of the features that have been implemented and features that
are being implemented, we have the following list:

- [x] Basic Window Management Modes: float, tab, vertical-tab, tiled, fullscreen
- [ ] Workspace Management
  - [x] Naming/Renaming
  - [x] Searching Based On Name
	- [x] Saving/Restoring Properties (background, mode, name)
  - [ ] Saving/Restoring Layout (positions, weights)
- [x] Basic Window Management
  - [x] Reassign
  - [x] Named Reassign
  - [x] Merge/Split
  - [x] Custom tags in Titlebar
  - [x] Find window based on tag
  - [x] Swap Left/Right/Up/Down
- [x] Visual Enhancements
  - [x] Animated Transitions (fade, move)
  - [x] Dim-Layer on Menus
  - [x] Configurable Bar Positioning
  - [ ] Tray/Statusbar movable to target/global menu
  - [ ] Ws- switch time based on diff. in content brightness
  - [ ] Workspace color sample points mapped to external LEDs
  - [x] Workspace Event Notification
  - [ ] Mouse Cursor Event Flash
  - [x] Font Customization
  - [ ] Color Customization
  - [x] Per Window canvas shader control
  - [x] Window Translucency
  - [x] Window Alpha Channel Behavior Control (using shader)
  - [x] Off-Screen Window Alert
  - [ ] Centered canvas in overdimensioned windows (tiled, fullscreen)
  - [ ] Mappable statusbar buttons in float mode
  - [x] Configurable Border Width/Gaps
  - [x] Per Workspace Background Image
- [ ] Screen-Rotate Trigger to re-layout
- [x] Global and Window- specific audio controls
- [x] Resource Browser
- [x] IPC
  -  [x] Basic Notification Bar Control (i3status, ...)
  -  [x] External Command Interface (limited at the moment)
- [ ] Input
  - [ ] Gaming Devices
    - [ ] Analog Calibration
    - [ ] Autofire
  - [ ] Touchpads/screens
    - [ ] Calibration
  - [ ] Keyboard/Game Device Mouse Emulation
  - [x] Configurable/Per Window Keyboard Repeat
  - [ ] Keyboard repeat rampup over time (reset on release)
  - [x] Drag Reposition/Resize in Float
  - [x] Double-Click Titlebar Maximize-Restore in Float
  - [x] Mouse-Hover Focus
  - [x] Mouse Scale Factors
  - [x] Mouse Follows Selection
  - [x] Mouse Lock to Window
  - [ ] Mouse Button Reordering
  - [ ] Meta + Mouse Button Binding
  - [x] Focus-Follows-Mouse
  - [x] Autohiding Mouse
  - [x] Per/Window Keyremapping
  - [ ] Macro Record / Replay
  - [ ] Global forwards (specify binding to send to window regardless of focus)
  - [ ] LED key-state highlights (k70 etc. kbds)
- [ ] Internationalization
  - [ ] Menu Translations
  - [ ] Foreign IME
  - [x] Keyboard layout hotswapping
  - [ ] Per-Window keyboard layout override
  - [ ] Per-Keyboard Layout
  - [x] Custom Unicode Binding (global and per window)
- [ ] State Management
  - [ ] Dynamic state change support
  - [ ] State transfer between windows
- [ ] Advanced Window Integration
  - [ ] Omnipresent Windows
  - [x] Window Canvas to Workspace Background Image
  - [ ] Cloning Windows
  - [x] Migrate Window Between Displays
  - [x] Debugging Subwindows
  - [ ] Overlay Surfaces
  - [x] Customized Titlebar
  - [x] Customized Cursors, Cursorhints
  - [x] Customized Border
  - [ ] Content position indicator (scrollbar)
  - [ ] Icon to "Tray"
  - [ ] Content/Scroll Integration
  - [ ] Popup Windows
  - [ ] Auto Suspend/Resume
    - [ ] Follow Focus
    - [ ] Follow Workspace
  - [x] Font Hinting
  - [ ] Block Alerts
  - [x] LL Origo Invert
  - [ ] Screenreader Support
  - [ ] Window Configuration Save
- [ ] Display Sharing
  - [ ] Recording/Streaming/Sharing
    - [ ] Audio Control
    - [ ] Secondary Audio Sources (microphone)
  - [x] Display screenshot (through command channel)
- [ ] Cut and Paste
  - [x] Clipboard Management (local/global + history)
  - [x] Simple Text
  - [ ] URL Catcher
  - [ ] Paste text Reencoded
    - [ ] Base64 enc/dec
    - [ ] Shell escaped
    - [ ] Drop (pre+post or all) linefeeds
  - [ ] Persistant pasteboard
  - [ ] Streaming Text
  - [ ] Text Hash to Color on Copy (show in paste menu)
  - [ ] Special clipboard tracking for detected URLs
  - [ ] Images
  - [ ] Videos
  - [ ] Audio
  - [ ] Drag N' Drop
- [ ] Security and Stability Measures
  - [ ] Visual Privilege Indicator
  - [x] Configure/Disable external connections
  - [ ] Limit subsurfaces per window
  - [ ] Notification on reaching VID limit threshold
        and suspend external/ subsegs temporarily
- [x] Basic Crash Recovery/Reset/Reload
- [ ] Advanced Displays Support
  - [x] Display Resolution Switching
  - [x] Synchronization Strategy Switching
  - [x] Offscreen Workspace Rendering
  - [x] Migrate Workspaces Between Displays
  - [x] Home Workspace to Preferred Display
  - [ ] Respect display DPI and use cm as size measurements
  - [ ] Power Management Controls (+ auto-DPMS)
  - [ ] ICC / Color Calibration Profiles
  - [ ] Daltonization
  - [ ] Redshift Color Temperature
  - [ ] Advanced scaling effects (xBR, ...)

Bear in mind that a lot of these features are primarily mapping to what arcan
already supports and the remaining job is the user interface mapping rather than
time-consuming hardcore development.

Performance
=====
For lower power devices where multi-screen setups isn't needed,
modify gconf.lua (or the corresponding database- fields if it has already
been created and updated with all the keys) to disable 'display\_simple'.

While somewhat buggy, one might also want to try out mouse\_mode = "native".

Extensions
=====
The above featureset mostly covers what would be useful from a tiling DE
perspective, but given the relative minimal effort in adding features that
would allow mimicking other DEs -- some extension scripts and support is
planned but not currently implemented (likely to be drop:able into a
plugins folder that globbed / scanned on load with some minimal hook api).

### start button, popup, control panel
traverse the window / target menus and convert to a popup- / settings
style layout

### widgets
widgets, allow arcan lwa connections with a custom GUID to be attached to
fixed- size dock slots and have them auto-launch on startup and a config-
key for finding in the normal target database. Work like the little dockapps
in WindowMaker.

### content preview in browser
extending lbar to support dynamic asynch- content loading for associating
preview content with bar navigation. This could be simple things like unicode-
helper for utf-8 bind or more advanced like thumbnails of images and silent
prelaunch for videos.

### desktop icons / shortcuts
for float layouts, allow local icons and shortcuts to be added, similarly
to how it already works in AWB.

Repository
=====

_files that might be of interest)_

    durden/
        gconf.lua        - configuration management (default visuals and sizes)
        clipboard.lua    - clipboard management
				keybindings.lua  - active keybindings
        fglobal.lua      - global WM functions
				mouse.lua        - mouse gesture support
				shdrmgmt.lua     - shader loading and setup
				symtable.lua     - keyboard layout and input translation
        iostatem.lua     - per window input state machine tracking
				extevh.lua       - default frameserver event handlers
        durden.lua       - main script, input routing and process management
        display.lua      - display and multiple-workspace manager
        tiler.lua        - main tiling layout, workspace management etc.
        lbar.lua         - support script for textedit control
        bbar.lua         - binding bar, used for querying keybindings
        browser.lua      - lbar based resource browser
        suppl.lua        - text and menu convinience functions

    durden/atypes/* - menus and settings for specific client subtypes
    durden/builtin/ - global menus and settings, target base menus and settings

We don't keep any necessary assets in the resource path as that should be
accessible to the browser (one could essentially set it to / or whatever
filesystem mount-point one wants).

Notes on DPI
====

Currently, we ignore display DPI property and dimensions are not specified
on anything other than pixels. For proper handling we need to modify
workspace/window migration to check for a change in pixel density and
add that information in the normal target\_displayhint calls.

In addition, there should be a conversion in text rendering that takes
the size argument to fonts (which is freetype points and 1/72 of an inch)
and converts to / from mm.

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

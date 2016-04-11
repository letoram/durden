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

2015-2016, Björn Ståhl

Licensing
=====
Durden is Licensed in the 3-clause BSD format that can be found in the
licensing file. The included terminal font, Hack-Bold is (c) Chris Simpkins
and licensed under the Apache-2.0 license.

The includede fallback font, Emoji-One is provided free (cc-by 4.0 attribution)
by http://emojione.com

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
manpages for other namespacing and configuration options.

Default meta keys are META1: MENU and META2:RSHIFT, look into keybindings.lua
for the currently mapped defaults. If you don't press any of the META keys
during the first n (20 or so) keypresses, it is assumed that your meta bindings
are broken and you will be queried for new ones.

Quick! meta1+enter - now you should get a terminal window.

A big point with durden as a desktop environment is to make minimal distinction
between static configuration and UI directed reconfiguration. The means for
changing settings should look and feel 'the same' no matter if it means
exposing configuration changes to external programs using a pipe- command
channel, mapping it to an input device, UI element like a button or even a
timer.

UI directed configuration is made through global and target menus, accessible
using meta1+g for global and meta1+t for target (if a window is selected).

The menus are navigated by default using the arrow keys and enter to select and
you can filter the list of shown items by typing. meta1+escape to go back one
level, meta1+select to activate but remain in menu, escape to close down.

Any path or menu item in the global or target menu can be bound to a
keycombination, and this is done by going to global/input/bind custom. You will
be prompted to press the binding you like and then navigate to the menu item
you want to bind it to. To bind a sub-menu, hold meta1 while selecting.

It is however also possible to tweak/modify the startup defaults (see
autorun.lua, keybindings.lua and gconf.lua).

Timers
====
Durden does not have explicit settings for suspend/resume, shutdown,
lockscreen or similar features. Instead, most commands can be bound to
a timer, of which there are three types:

1. Fire Once(a): about (n) seconds from now, run command (a)
2. Fire Periodically(a): every (n) seconds from now, run command (a)
3. Fire Idle(a,b): after (n) seconds of idle (no input activity and active space
is not in fullscreen state), run command (a) going into idle, (b) going out.

3 is of particular interest as you can set multiple idle timers. For example>
After (30 seconds, run lockscreen with key '1password1'). Then after (60 seconds
, disable/enable displays) and finally after 120 seconds, suspend.

The file autorun.lua can also be used to add timers that are set when launched,
Make sure the syntax is correct because the entire file will be ignored in the
event of parser errors.

Database Configuration
====
The launch bar (default meta1+d) uses preconfigured execution profiles that are
managed with a separate external tool as part of Arcan, called *arcan_db*,
check the [Arcan Wiki](http://github.com/letoram/arcan/wiki) for more
information.

Recall that for now, we don't implement display server protocols like
X11, Wayland or MIR so the set of programs that can be launched and expected to
run are fairly limited. See the development progress and timeline for Arcan
itself for an idea as to when that will be possible.

There is support for running [libretro](http://www.libretro.com) 'cores'
(dynamically linked libraries that wrap input/output/state management for
common games and emulators) however.

The specifics for downloading/compiling cores and other data that might be
needed is outside the scope here, but an example on how to add a target:

    arcan_db add_target mycore RETRO [ARCAN_RESOURCEPATH]/.cores/core.so

will add a target with the name 'mycore' to the default database
(homedir/.arcan/arcan.sqlite), using the libretro- binary 'format' and
the actual file located relative to the current set resourcepath
/.cores/core.so

Then we need a launch configuration, one with empty arguments are usually
created with the name 'default' (when launching a target that has only one
configuration, you won't be queried about what configuration that will be
used).

    arcan_db add_config mycore myconfig [ARCAN_RESOURCEPATH]/.assets/somefile

will add a config 'myconfig' to 'mycore' with somefile as first argument.

Menu Widgets
====
in the widget folder, there are a few short example scripts on hooks
that are enabled when menu navigation reaches a certain state or the
lbar/bbar are used for some things. This feature is intended to help
developing quick features like notes and a calculator, but also when
using features that becomes easier with 'cheat sheets' like an ASCII
table.

Statusbar / Command Channel
====

By default, durden creates two named pipes (FIFO) in the APPLTEMP namespace
(e.g. export ARCAN\_APPLTEMPPATH=/some/where but defaults to the specified
appldir) with the name (durden\_status) and (durden\_control). These can be
used to run remote controls and to update the statusbar. For instance, using
i3status:

    i3status | sed -e 's/^/status:/' > ~/durden/durden\_

The command channel uses the format "namespace:command" where namespace
is one of (command, global, target). In addition, the command name or path
 must be enabled in the built-in table in gconf.lua or manually added
through the global/config/command\_channel path. The feature works much
like normal custom target or global bindings, but with some additional
(gfunc.lua) functions available to be exposed.

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
  - [ ] Tray/Statusbar movable to target/global menu screen
  - [ ] Ws- switch time based on diff. in content brightness
  - [ ] Workspace color sample points mapped to external LEDs
  - [x] Workspace Event Notification
  - [x] Mouse Cursor Event Flash
  - [x] Font Customization
  - [ ] Color (UI Shader Uniform settings) Customization
  - [x] Per Window canvas shader control
  - [x] Window Translucency
  - [x] Window Alpha Channel Behavior Control (using shader)
  - [x] Off-Screen Window Alert
  - [x] Centered canvas in overdimensioned windows (fullscreen)
  - [ ] Bind target/global action to titlebar icon
  - [ ] Bind target/global action to statusbar icon
  - [x] Configurable Border Width/Gaps
  - [x] Per Workspace Background Image
- [x] Global and Window- specific audio controls
- [x] Resource Browser
- [x] IPC
  -  [x] Basic Notification Bar Control (i3status, ...)
  -  [x] External Command Interface
- [ ] Input
  - [ ] Gaming Devices
    - [x] Basic Support (maps, scan, plug/unplug)
    - [ ] Axis Remapping
    - [ ] Axis Filtering
    - [ ] Analog Calibration
    - [ ] Autofire
  - [ ] Touchpads/screens
    - [ ] Calibration Tool
  - [ ] Keyboard/Game Device Mouse Emulation
  - [x] Configurable/Per Window Keyboard Repeat
  - [ ] Keyboard repeat rampup over time (reset on release)
  - [ ] 'Sticky' Meta (meta press state persist n ticks)
  - [x] Drag Reposition/Resize in Float
  - [x] Double-Click Titlebar Maximize-Restore in Float
  - [ ] Desktop Icons in Float-Mode
  - [x] Mouse-Hover Focus
  - [x] Mouse Scale Factors
  - [x] Mouse Follows Selection
  - [x] Mouse Lock to Window
  - [ ] Mouse Button Reordering
  - [ ] Meta + Mouse Button Binding
	- [ ] Custom Gestures to action binding
  - [x] Focus-Follows-Mouse
  - [x] Autohiding Mouse
  - [x] Per/Window Keyremapping
  - [ ] Macro Record / Replay
  - [ ] On-Screen Keyboard (custom button grid as window that don't focus)
  - [ ] Global forwards
    - [ ] Specific Binding
    - [ ] Specific Device
  - [ ] Input state to LED binding (keymap, active bindings for RGB keyboards)
- [ ] Internationalization
  - [ ] Menu Translations
  - [ ] Foreign IMEs
  - [x] Keyboard layout hotswapping
  - [ ] Per-Window keyboard layout override
  - [ ] Per-Keyboard Layout
  - [x] Custom Unicode Binding (global and per window)
- [ ] Program Save-State Management
  - [x] Save/Load
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
  - [ ] Content/Scrollbar Integration
  - [ ] Popup Windows
  - [ ] Move window to float/hidden that can be toggled to cursor position
  - [ ] Cursor Drag - Event Region
    - [x] Monitor region
    - [x] Snapshot region
    - [ ] Recording
		  -  [x] Single Target (A/V)
			-  [x] Visual Region (V)
		  -  [ ] Controllable A/V mixing
			-  [ ] Sync/Gain controls
			-  [ ] Video Filtering
			-  [ ] Streaming Destination
		- [ ] VNC Server
			-  [x] Passive
			-  [ ] Input mapping
		- [ ] Abstract Encode
		  -  [ ] OCR
			-  [ ] Text to Speech
			-  [ ] Speech Recognition
			-  [ ] Dictionary / Translation
  - [x] Automation
    -  [x] Fire-Once Timers
    -  [x] Idle-Timers
    -  [x] Timer-Bind
  - [x] Inactivity / Focus Notification
  - [ ] Auto Suspend/Resume
    - [ ] Follow Focus
    - [ ] Follow Workspace
  - [x] Font Hinting
  - [ ] Block Alerts
  - [x] LL Origo Invert
  - [ ] Window Configuration Save
  - [x] Display screenshot (through command channel)
- [ ] Cut and Paste
  - [x] Clipboard Management (local/global + history)
  - [x] Simple Text
  - [x] URL Catcher
  - [x] Paste text Reencoded
    - [x] Trim
    - [x] No CR/LF
    - [x] No consecutive whitespace
  - [ ] Persistant pasteboard (serialize to K/V store)
  - [ ] Streaming Text
  - [ ] Text Hash to Color on Copy (show in paste menu)
  - [x] Special clipboard tracking for detected URLs
  - [ ] Images
  - [ ] Videos
  - [ ] Audio
  - [ ] Drag N' Drop
- [ ] Security and Stability Measures
  - [ ] Visual Privilege Level Indicator
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
  - [ ] Change orientation
  -     [x] vertical / horizontal
  -     [ ] mirroring
  -     [ ] led layout in hinting (RGB to VRGB)
  - [x] Respect display DPI and use cm/font-pt as size
  - [ ] Remember DPI / overrides / orientation between launches
  - [x] Power Management Controls
  - [x] Gamma Correction
  - [ ] ICC / Color Calibration Profiles
  - [ ] Daltonization
  - [ ] Redshift Color Temperature
  - [ ] Advanced scaling effects (xBR, ...)
  - [x] Lockscreen
		- [ ] Autosuspend game/media on Lock

Keep in mind that a lot of these features are primarily mapping to what arcan
already supports and the remaining job is the user interface mapping rather than
time-consuming hardcore development.

Performance
=====
For lower power devices where multi-screen setups isn't needed, simple display
mode might be needed. This can be accessed by modifying gconf.lua or while
running through Config/System/Display Mode (requires a Reset to activate).

Simple display mode disables some other features as well, e.g. orientation
swap, some forms of recording / sharing and others that build on the main
surface being rendered to an off-screen buffer.

While somewhat buggy, one might also want to try out mouse\_mode = "native"
where cursor drawing is treated outside the normal rendering pipeline. This may
make the cursor feel more 'smooth' (but at the same time can't be used as an
indicator for slowdowns in the rendering pipeline that might be relevant to
investigate)

Extensions
=====
The above featureset mostly covers what would be useful from a tiling DE
perspective, but given the relative minimal effort in adding features that
would allow mimicking other DEs ('start' button, dock, control panel, ..) --
some extension scripts and support is planned but not currently implemented
(likely to be drop:able into a plugins folder that globbed / scanned on load
With some minimal hook api).

### start button, popup, control panel
While the status/etc. bar code should probably be replaced with a more flexible
system for adding dynamic bars and attachment points, adding a clickable button
to work like the normal windows-style start menu should be an easy thing.

The menu-code that uses the lbar currently could trivially be switched over
to use such popup-menu style navigation, though some icon field may need to
be added.

### external widgets
Sweep the database at launch for a specific tag and launch them all at startup,
attaching to a fixed size docklet "WindowMaker/NeXTStep style" or as part of the
global/target menu screen.

### content preview in browser
extending lbar to support dynamic asynch- content loading for associating
preview content with bar navigation. This could be simple things like unicode-
helper for utf-8 bind or more advanced like thumbnails of images and silent
prelaunch for videos.

### desktop icons / shortcuts
For float layouts, allow local icons and shortcuts to be added for launching,
but also for 'minimizing selected window' to desktop icon and some operation
to hide/reveal active windows.

### advanced keyboard - mouse navigation
Offscreen, run edge detection/amplification, downscale and readback to get
a 'navigation map' of continous regions that the mouse cursor can be centered
to, allowing much faster cursor positioning with keyboard and "sticky" regions
with mouse navigation.

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
        wnd_settings.lua - window serialization and restore
        lbar.lua         - support script for textedit control
        uiprim.lua       - UI primitives, buttons etc.
        bbar.lua         - binding bar, used for querying keybindings
        browser.lua      - lbar based resource browser
        suppl.lua        - text and menu convinience functions
        timer.lua        - one-off or recurrent timer events

    durden/atypes/* - menus and settings for specific client subtypes
    durden/menus/ - global menus and settings, target base menus and settings

We don't keep any necessary assets in the resource path as that should be
accessible to the browser (one could essentially set it to / or whatever
filesystem mount-point one wants).


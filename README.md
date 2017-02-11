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
licensing file.

The included terminal font, Hack-Bold is (c) Chris Simpkins
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
manpages for configuration options. If you're "lucky" (linux, normal "no-X" VT,
build dependencies fullfilled and KMS/GBM on) this should land in something like:

     git clone https://github.com/letoram/arcan.git
     git clone https://github.com/letoram/durden.git
     cd arcan/external/git; bash ./clone.sh
     cd ../ ; mkdir build ; cd build
     cmake -DVIDEO_PLATFORM=egl-dri -DSTATIC_SQLITE3=ON -DSTATIC_OPENAL=ON
        -DSTATIC_FREETYPE=ON ../src
     make -j 8
     ./arcan ../../durden/durden

Note: the egl-dri (and egl-nvidia) video platforms are for running this as a
dedicated desktop, if you just want to try things out, use the _sdl_ platform
instead. Some features when it comes to display management and input will behave
differently, and you likely want to bind a toggle for enabling/disabling
cursor locking.

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

Bindings
=====
Most features are accessed through the global or target menu. These are not
just UI elements, but rather two namespaces for activating or configuring UI
features, and is one of the more powerful parts of durden.

Any accessible menu path can be bound to a key, button, UI path, mouse
gesture, timer -- even external IPC, if one so desires.

Underneath the surface, these look something like:

     !config/visual/border=1
     #video/scaling/normal
     $!config/visual/border=1\n#video/scaling/normal

the first character indicates namespace (! for global, # for target or
$ for a compound path). Compond paths are a bit special since they group
multiple actions together into one ordered sequence, allowing you to make
'macros'.

See README.tree for an estimation of the existing list of target and global
menu paths (though the validity is evaulated at runtime, so not all paths
are valid all the time).

Configuration Files
=====
Although most features can be configured directly into the UI, and is stored
in the active database, there are also a few files that can be modified for
more permanent change (as the database can be reset with
arcan\_db drop\_appl durden - see the Database section further below)

These files are:

    autorun.lua -- run once on startup
    keybindings.lua -- default meta+sym to path mapping
    gconf.lua -- trim parameters

Along with the 'device maps' covered below.

Device Maps
=====
For detailed configuration of input and output device behaviors, scripts can
be added to the devmaps/ folder. Each folder has a separate README.md that
describes the expected format. On device added/ removed events, these maps are
scanned looking for a fitting map to tune how data from the device is interpreted
and routed.

Extensions
=====
Two folders are dedicated for extending the behavior of durden. One is widgets,
which contain scripts that trigger on a specific global or target menu path.
A typical example is widgets/ascii.lua that is activated when a utf-8 sequence
is to be bound.
The other are tools that add more generic features, examples being a 3d
modelviewer (3dsupport), a quake- style pulldown terminal (pulldown)
 and an automatic tiling layout manager (autolay).

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

Tools
====
The scripts in the tools subfolder are scanned on startup and extend the
existing feature set. It is the intention to move more advanced features to
this folder, with the explicit criterion that they should be removable without
any adverse effects to the rest of the environment.

The included example tools cover:

1. 3dmodel - simple 3D model viewer that can map the contents of another window
2. autolayouter - a set of strategies for automatically controlling weights and
   balancing the window tree in tiling mode
3. dropdown - terminal that is 'always on top' with a dedicated input path that
   should be more 'safe' to use for privileged operations.

Lockscreen
====
A lockscreen can be setup temporarily by accessing system/lock and enter a one-
use password, or as mentioned in the timers section, be bound to an idle timer
or similar mechanism.

In addition, it is possible to bind a path to lockscreen success or
fail "n" times by modifying gconf.lua, look for lock\_ok and lock\_fail entries.
This can be used for strong effects like starting webcam streaming, running
external commands or shutting down.

Database Configuration
====
The launch bar (default meta1+d) uses preconfigured execution profiles that are
managed with a separate external tool as part of Arcan, called *arcan_db*,
check the [Arcan Wiki](http://github.com/letoram/arcan/wiki) and the README in
the main Arcan git repository.

The specifics for downloading/compiling libretro cores and other data that
might be needed is outside the scope here, but an example on how to add a target:

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

Most settings are stored in the database, and can either be manually. In the
event of a broken configuration (where it is not possible to see or otherwise
access relevant menus), it is possible to reset to a default state by calling

    arcan_db drop_appl durden

Status / Command / Output channels
====
By default, durden creates three named pipes (FIFO) in the ipc subdirectory of
the APPLTEMP namespace (default, same as the durden path you run, but can be
changed with the ARCAN\_APPLTEMPPATH environment variable).

The respective fifos are called (write-only: status, control) and (read-only:
output). Status can be used for providing external information, e.g. open
files, available memory, network status and have it mapped on UI components
like the status bar. The command protocol is similar to 'lemonbar' (so i3status
with output format set to lemonbar can be used) with some additions.

    | is used as group separator
    %% escapes %
    %{fmtcmd} changes format (stateful)

    where possible fmtcmd values are:
     F#rrggbb set text color
     B#rrggbb set group background
     F- reset to default text color
     S+ switch to next screen
     S- switch to previous screen
     Sf switch to first (primary) screen
     Sl switch to last screen
     Snum switch to screen index 'num'
     Aidentifier set group "on click" action. This can only be set once for
     each group. If identifier is a valid path (#path/to/cmd or !path/to/cmd)
     on-click will run that path. Otherwise, identifier value will be written
     to output channel on click.

The command channel uses the same format as normal binds, meaning that there
is a 'hidden' group of functions and the normal groups that prefix with
!path/to/action or !path/to/value=somenum for global actions and #path/to/action
for target actions.

of (command, global, target). In addition, the command name or path must be
enabled in the built-in table in gconf.lua or manually added through the
global/config/command\_channel path. The feature works much like normal custom
target or global bindings, but with some additional (gfunc.lua) functions
available to be exposed.

There are few good mechanisms for probing the available command paths other
than reading through the source code in menus, but running arcan durden
dump\_menus will give a decent aproximation, but some paths are only visible /
available when certain preconditions have been fulfilled.

The output ipc channel acts as response for writes to both status and command
channels.

Browser
=====
The built-in browser is currently limited in a number of ways due to arcan
engine restrictions. The primary purpose is media selection (for sharing,
playlists, navigation) and therefore only shows extensions that have a chance
of being 'useful' (while also part of the shared resource- namespace) and does
not have the ability to directly alter this space (deletion, moving, renaming)
though it is likely that this functionality will be added as a system\_load
style .so/dll/dylib in the future.

Due to limitations in how arcan glob\_resource currently works, it is blocking
(nothing else happens until the operation finishes) and unbounded (you get all
or nothing, not a cutoff after a certain number of items or time) which means
that networked mappings and huge folders can introduce notable stalls, which
is of course not acceptible.

Features and Status
=====
To get an overview of the features that have been implemented and features that
are being implemented, we have the following list:

- [x] Basic Window Management Modes: float, tab, vertical-tab, tiled, fullscreen
- [ ] Preset configuration / themes ("desktop", tiling, enhanced security..)
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
  - [ ] Ws- switch time based on diff. in content brightness
  - [ ] Workspace color sample points mapped to external LEDs
  - [x] Workspace Event Notification
  - [x] Mouse Cursor Event Flash
  - [x] Font Customization
  - [x] Color (UI Shader Uniform settings) Customization
  - [x] Per Window canvas shader control
  - [x] Window Translucency
  - [x] Window Alpha Channel Behavior Control (using shader)
  - [x] Off-Screen Window Alert
  - [x] Centered canvas in overdimensioned windows (fullscreen)
  - [x] Bind target/global action to titlebar icon
  - [x] Bind target/global action to statusbar icon
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
    - [x] Reroute known game inputs to specific window
    - [ ] Axis Remapping
    - [ ] Axis Filtering
    - [ ] Analog Calibration
    - [ ] Autofire
  - [ ] Touchpads/screens
    - [x] Mouse Emulation
    - [x] Gesture- analysis profiler
    - [ ] Calibration Tool
  - [ ] Keyboard/Game Device Mouse Emulation
  - [x] Configurable/Per Window Keyboard Repeat
  - [ ] Keyboard repeat rampup over time (reset on release)
  - [x] Multicast Groups
  - [x] 'Sticky' Meta (meta press state persist n ticks)
  - [ ] Float Layout
    - [x] Drag Reposition/Resize in Float
    - [x] Double-Click Titlebar Maximize-Restore in Float
    - [ ] Desktop Icons in Float-Mode
    - [ ] Auto-layouter in Float-Mode (normalize + binpack)
  - [x] Mouse
    - [x] Focus follows:
      - [x] Hover
      - [x] Click
      - [x] Motion
    - [x] Scale Factor
    - [x] Follows Selection
    - [x] Lock to Window
    - [x] Autohide / Reveal
    - [x] Button Reordering
    - [ ] Meta+Click Binding
    - [x] Debounce
    - [ ] Abstract Gesture Training
  - [x] Per/Window Keyremapping
  - [ ] Macros
  - [ ] Custom On-Screen Keyboards
  - [ ] Global forwards
    - [ ] Specific Binding
    - [x] Specific Device
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
  - [ ] Cloning Windows
  - [ ] Overlay Surfaces
  - [ ] Content position indicator (scrollbar)
  - [ ] Icon to "Tray"
  - [ ] Content/Scrollbar Integration
  - [ ] Popup Windows
  - [ ] Move window to float/hidden that can be toggled to cursor position
  - [ ] Cursor Drag - Event Region
    - [x] Monitor region
    - [x] Snapshot region
    - [x] Single Target (A/V)
    - [x] Visual Region (V)
    - [x] OCR
    - [ ] Recording
      - [ ] Controllable A/V mixing
      - [ ] Sync/Gain controls
      - [ ] Video Filtering
      - [ ] Streaming Destination
    - [ ] Remote Sharing Server
      - [x] Passive
      - [ ] Input mapping
      - [ ] As separate 'display'
    - [ ] Abstract Encode/Decode
    - [ ] Text to Speech
    - [ ] Speech Recognition
    - [ ] Dictionary / Translation
  - [x] Window Canvas to Workspace Background Image
  - [x] Migrate Window Between Displays
  - [x] Debugging Subwindows
  - [x] Customized Titlebar
  - [x] Customized Cursors, Cursorhints
  - [x] Customized Border
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
  - [x] Persistant pasteboard (serialize to file)
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
  - [x] Limit subsurfaces per window
  - [x] Ratelimit external connections
  - [x] Cap external windows
  - [x] Trusted input path on high-privilege window
  - [ ] Notification on reaching VID limit threshold
        and suspend external/ subsegs temporarily
- [x] Basic Crash Recovery/Reset/Reload
- [ ] Advanced Displays Support
  - [x] Display Resolution Switching
  - [x] Synchronization Strategy Switching
  - [x] Offscreen Workspace Rendering
  - [x] Migrate Workspaces Between Displays
  - [x] Home Workspace to Preferred Display
  - [ ] Virtual Overlay Display
  - [ ] Change orientation
    - [x] vertical / horizontal
    - [ ] mirroring
    - [ ] led layout in hinting (RGB to VRGB)
  - [x] Respect display DPI and use cm/font-pt as size
  - [x] Remember DPI / overrides / orientation between launches
  - [x] Power Management Controls
  - [x] Gamma Correction
  - [ ] ICC / Color Calibration Profiles
  - [ ] Daltonization
  - [ ] Redshift Color Temperature (builtin, shader+update via control-ch works)
  - [ ] Advanced scaling effects (xBR, ...)
  - [x] Lockscreen
    - [x] Autosuspend game/media or all on Lock
    - [x] Customized action on repeated auth- failure
    - [x] Customized action on lock/unlock
  - [ ] Iconsheets
    - [ ] Static (for buttons)
    - [ ] Dynamic (advanced window management, client registred)

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
				extevh.lua       - default frameserver event handlers
        durden.lua       - main script, input routing and process management
        display.lua      - display and multiple-workspace manager
        tiler.lua        - main tiling layout, workspace management etc.
        lbar.lua         - support script for textedit control
        uiprim.lua       - UI primitives, buttons etc.
        bbar.lua         - binding bar, used for querying keybindings
        whitelist.lua    - IPC command whitelisting
        browser.lua      - lbar based resource browser
        suppl.lua        - text and menu convinience functions
        timer.lua        - one-off or recurrent timer events
        touchm.lua       - handles touch- device managent
        iostatem.lua     - per window input state machine tracking

    durden/atypes/*    - menus and settings for specific client subtypes
    durden/menus/      - global menus and settings, target base menus and settings
		durden/devmaps     - device (mouse, display, game, keyboard) default configuration
		durden/widgets/    - customized menu path- helpers
    durden/tools/      - loadable tools/plugins
		durden/shaders/ui/ - code for customizing decorations etc.
		durden/recordings  - video recording output stored here
		durden/ipc/        - iopipes will be created here

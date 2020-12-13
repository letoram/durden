# 0.6.0
* universal open/save:
Clients that announce support for global open/save via bchunk-hints
now trigger the file browser accordingly.

* display/share and target/share reworked:
Display/region/ based sharing removed (except for snapshot/monitor)
in favoring of a /target/share menu that consolidate all such options.

* uiprim/sbar:
statusbar custom button controls added, it is now possible to define
alt-action (such as custom popup spawn) as well as drag-action.

* workspace buttons now popup layout mode selector on altclick, and
migrate window on drag-drop

* uiprim/tbar:
titlebar merge-to-status bar mode on select (if hidden)
titlebar rclick now mappable (default, popup /target)

* uiprim/popup:
added basic popup component

* target-launch:
When activating global/target/launch to start a trusted application you
can also supply an application tag. This helps automation as you can now
specify that tag as part of /windows/by-tag etc. when there are no UUIDs
or other values to take advantage of.

* input/rotary added:
This tool implements basic gestures, commands and mapping for rotary devices
like the 'Surface Dial' and 'Griffin PowerMate'.

* tools/extbtn added:
Registers into global/settings/statusbar and adds option for external clients
to connect and attach custom buttons. This deprecates the statusbar IPC in
favor of solving this externally.

* tools/autostart added:
This tool allows a series of paths to be automatically run on startup.

* tools/profile\_picker added:
This tool is the first step towards better initial configuration. It triggers
on startup and installs UI schemas for default inputs, colors and security
profiles.

* triggers:
added per-window option to bind multiple custom triggers on select,
deselect and destroy

* layout/tile:
allow titlebar drag/drop as a mouse- triggered way to swap, m1 and m2 control
swap, join as child or join as sibling. allow better gap controls.

* layout/htab:
added side column based tabbed layout mode

* menu/hud:
Cipharius added support for fuzzy-string matching to the HUD, switch it on by
entering % and pick fuzzy_relevance as the sort method.

* menu/devmaps:
Custom menus/aliasmaps can now be built. These register in the menu root
(/menus) and are intended for shortcut button grids, popup menus, radial menus
and so on.

* workspaces assignment:
It is now possible to control which workspace new windows currently spawn at,
see the /global/settings/workspaces/spawn path.

* visual:
Add soft shadow controls to windows, ui elements and statusbar

* input/touch improvements:
New gestures, 'tap', 'doubletap', 'idle\_return', 'idle\_enter'. improved
relative mouse emulation to better handle click-select refactored some of the
code to more easilly accomodate custom classifiers. Some device profile based
values can now be changed through the path /global/input/touch. A classifier
that forwards as basic touch events has been added.

* first round of (non-text) icon management (caching, shared sets etc.) added

* displays/current/zoom added:
Bind to keyboard for zooming in/out around the mouse cursor position

* new tool: streamdeck
This allows external mini displays (touchbars etc.) to be hooked up and
act as restricted input devices as well as custom widget mappings

* new tool: todo
This tool allows for simple tracking of todo tasks that integrate with
the notification system, status bars and so on.

* new tool: tracing
This tool mixes the monitoring wm inspection parts of durden with the
tracing facility in arcan to produce chrome://tracing friendly json logs.

Minor / Fixes:
* global/settings/terminal/tpack added for temporarily forcing server-side
  text on for all new terminal windows (feature still experimental)

* display resolution picker should now bias towards the highest refresh
rate when there are multiple to chose from at the desired resolution

* added controls to insert subwindows as new windows or relative to their
parents, (global/settings/workspaces/tiled/subwindow=normal,child)

* removed the 'alternate' window feature (used with wayland toplevels and
terminal groups), the feature turned out way to complex and demanding in
the way it was implemented.

* float/minimize prefers client provided icon or canvas contents as statusbar
icon rather than a longer text representation

* added 'invert light' shader that retains most of hue while inverting
  dark/light colors

* handover subsegment allocation now routes correctly

* silent shutdown retains known window position and states, should
  recover properly when started back up.

* region selection closure management reworked

* more subsystems expose logging over the monitor ipc

* /global/displays/color can be used to change the default clear color
when there is no wallpaper. A single color background can also be
generated through /global/workspace/background.

* statusbar ws- button coloring now defaults to dynamic from hc palette

* /windows/name added for individual explicit window addressing

* started refactoring and splitting uiprim.lua

* started refactoring and splitting tiler.lua

* allow disabling meta-guard (rebinding) via /input/keyboard/meta\_guard

* gconf.lua split up into config.lua (keys) and gconf.lua (mgmt code)

* /bindtarget=/some/path sets a 'consume on use' path that allows interactive
  menu paths like key and button bindings to be automated

* target/window/move\_fx/fy added for display- size relative move

* firstrun.lua added to setup custom defaults on first run/config reset

* added color picker widget

* dropped the vr-viewer tool in favor of an upcoming way of allowing lwa
clients that use the vr-subsystem so that safespaces can be used nested
at minimal cost.

* display backlight controls changed into a submenu, added options for
stepping

* generalized/cleaned up the external-listener implementation. fixing
reliability and rate-limit misses.

* multiple changes to display hotplug behavior / detection, fallback when
edid fail after power cycle

* added visual indicators to window drag-reorder in tiling mode

* added dynamic statusbar buttons to control / reach other displays

* HC-palette color changes (global/settings/visual/colors/palette) persist

* input devices can be forgotten (global/input/all-devices/dev/forget=yes

* better error reporting for init-script errors

# 0.5.0
  * tools/advfloat:
     window-to-background will now receive input when no window is
     selected.

  * tools/advfloat:
     autolayout now recurses when one pass didn't position all windows
     autolayout also got a hide/reveal mode

   tools/vrviewer
     added 'vrviewer', an integrated 3D/VR tool that acts as a
     3D desktop-within-the-desktop.

  * distr/durden:
     launcher- script for reasonable defaults for linux/BSDs with
     arcan on egl-dri (native) platform.

  * widgets/input:
     new widget (target/input activated) that presents client provided
     input labels as clickable options

  * widgets/notification:
     new widget (activated on any path) that flushes the currently
     queued set of notifications on HUD activation

  * widgets/icon:
	   new widget (for UI button to emoji- unicode-subset mapping)

  * custom-crop:
     support cropping [t l d r] px from the canvas area

  * impostors:
     crop t- px and bind to a toggle-able titlebar

  * browser:
     add controls for preview-launch delay, and allow video previews

  * decorations:
     added controls to hide dynamic workspace buttons
     added per-window controls to override titlebar pattern
     added per-window controls to modify titlebar buttons
		 added paths for border/titlebar primary colors

  * cursortagging:
     added (target/window/cursortag) as an option, experimental

  * mass-actions:
	   the root node /windows can now be used to address collections of
		 windows based on some property, such as name or type

Breaking:
  * statusbar visual config area changed to [px] from % point and
    order changed to [t l r d] to match other similar functions

  * target titlebar controls moved to its own group

	* border settings moved to its own group (/global/settings/border)

  * control channel (ipc pipes) have switched to using a domain
    socket for both input and output

  * entire menu/browser system refactored to have a more shared codebase,
    this moves all paths to be explicit /global/path/to /target/path/to
    /browse/shared/

  * multiple menu functions moved around and regrouped, all toggle
    options have been merged into the YES/NO paths that have been
    extended with YES/NO/FLIP

  * mouse devices now get joined into one abstract label by default
	  for binding, to revert back to the devid\_subid setup, you can
		use /global/input/mouse/coalesce=false

Minor / Fixes:
  * activate GPU rescan on hotplug event

  * reworked multi-display state management / restoration / discovery

  * mouse should now work better with the HUD menu, particularly
	  mouse-wheel, navigation button clicks and right-click to exit.

  * regression in hotplugging causing nil table member dereference
    on remove event with active listeners

  * input focus can be changed by explicit display path / name

  * reworked most sizing / positioning code to be less strict on
    client- driven resizing

  * per- target default decoration color overrides

	* split border controls into float and other modes

  * expose target menu binding in recovery binding handler

  * expose input caret manipulation as part of basic bindings

  * system shutdown gets a silent option that doesn't tell clients
    to shut down, but rather to reconnect or migrate

  * add menu options to join 'n' windows to the left or right in
    tile mode as children of the selected window

  * added global/config/commit to make sure the current setings get
	  saved immediately

	* mouse/keyboard scripts are now switched to use the distribution
	  default from arcan

  * more terminal controls exposed: blinkrate, cursor style

  * added controls for border color

  * display preset map now respects density and backlight

  * launch targets with the tag 'autorun' will be launched on
	  startup

  * display orientation options are now explicit +- 90

	* added target/video/advanced/override\_size for testing client
	  behavior at explicit sizes (combine with _block_resize)

# 0.4.0
  * Display region sharing now supports force-pushing into clients
    that can handle input segments.

  * target/video/advance/migrate - send a migrate request to a
    client, which may prompt a client to jump to a different
    connection point or display server instance.

  * shader subsystem - added a multi-pass effect format along with
    some initial effects (gaussian blur, CRT-lottes).

  * tools/advfloat - extended float layout mode capabilities:
    spawn control (draw2spawn)
    hide-to-statusbar
    cursor-action-region (see tools/advfloat/cregion.lua for definition)
    automatic relayouter
    grid-cell align

  * tools/overview - added a HUD- like workspace switcher

  * tools/flair - added a visual effects layers and some initial
    effects, e.g. clothy windows, the natural successor to wobbly
    windows.

  * terminal-group spawn-mode added, allows a connection primitive
    to be generated per terminal and clients which connect via this
    group share the same logical window tree slot.

  * Tui/terminal clients are now allowed to spawn additional tui
    subsegments. This match the new support in afsrv_terminal that
    allows the window to be cloned into a copy-window.

  * File browser now expose wild-card matching (asterisk), Lua
    patterns (%%) and sort-order modification (typing % lists options).

  * retain some window and workspace properties across script errors
    crashes and resets

  * menu navigation can now shows a helper description of the
    currently selected item

  * mode-sensitive titlebar icons - window titlebar icons can now be
    set to be activated only in certain modes

Minor:
 * Destroying a window in fullscreen mode now returns the workspace
   to the last known mode instead of forcing to tile.

 * Double-tap input-lock automatically unlocks if the locked window
   is closed

 * Double-tap input-lock without a selected windows is now a no-op

 * Float mode border drag sizing, cursorhint and positioning fixes

 * Float mode drag now respects statusbar- imposed boundaries

 * Float mode canvas-drag/resize option for self-decorated clients

 * improved (less broken) handling for wayland popups and subsurfaces

 * Step-resize keybinding now aligns to window- cell size (terminals)

 * statusbar can now be sized/padded to percentage of display output
   (config/statusbar/borderpad)

 * statusbar specific configuration moved to (config/statusbar) from
   (config/visual/bars/...)

 * statusbar number prefix on known workspaces and statusbar mode
   button can now be toggled on/off

 * add support for window canvas overlays, intended for wayland-
   toplevel windows and senseye translators

# 0.3.0
  * Now requires arcan >= 0.5.3.

  * Documentation Moved to a separate webpage,
    http://durden.arcan-fe.com

  * Client- defined mouse-cursor support.

  * Window slicing: target/window/slice allows mouse-selected
    subregion to (active->input forward or passive) bind a subregion
    of one window to a new window.

  * External clipboard manager support: external clients can be
    permitted to read and/or inject entries unto the clipboard. See
    global/config/system/clipboard-bridge.

  * Gamma controls: external clients can be permitted to set custom
    color/ and gamma/ lookup tables, either per window or globally.
    See target/video/advanced/color-gamma synch and
    global/config/system/gamma-bridge.

  * Filesystem-like IPC: the iopipes IPC path has been extended to
    allow ls, read, write and exec like navigation of the menu
    subsystem. This can be bound to a FUSE-wrapper to fully control
    durden from a terminal.

  * LED devices: added support for profile driven LED device control
    see devmaps/led/README.md or global/config/led

  * Input multicast : added support for input multicast groups.
    Enable per window via target/input/multicast. Keyboard input
    received will be forwarded to all children.

  * Statusbar: can now be set to 'HUD' mode, where it is only visible on the
    global/ or target/ menu HUDs. (config/visual/bars/statusbar(HUD)/...)

  * Tools/Autolayout improvements: can now disable titlebars on
    side-columns, and allow a different shader on side-columns
    (see global/config/tools/autolayouting)

  * Tools/Overlay: [new], can now take the contents of a window and add
    to a vertical column stack at left or right edge as scaled-down
    previews.

  * Target/Video/Advanced: allow per-window output density overrides.

  * Atypes/wayland/x11: new scaling mode, 'client' to allow the client to
    know about the max dimensions, but let it chose its own actual size
    within those constraints.

  * Window- relayout/resize animations for float/tile:
    disable/enable via config/visual/window animation speed

  * Dynamically switchable visual/action schemes (devmaps/schemes/README.md)
    that can be used to set a global, per-display, per workspace or per window
    scheme of fonts and other configuration presets.

Minor:
  * (arcan > 0.5.2) allow GPU- authentication controls
  * Split mouse cursors into sets.
  * more consistent font/font-size switching when migrating across displays
  * default-off display profiles for vive/psvr
  * per window font override controls
  * defer window attachment to reduce resize operations
  * menu options for appl- switching (global/system/reset/...)
  * hidden bind path for suspend-state toggle (target/state/...)
  * menu path to reset workspace background (global/workspace/...)
  * menu path for global/workspace/switch/last
  * option to force bitmap font path for terminal
  * a shader for luma (monochrome) - only mode
  * atype- profile for wayland clients
  * option to disable/block mouse (global/input/mouse/block)
  * target menu path for set-x, set-y in float mode
  * mouse button debounce timer support (global/inpput/mouse/debounce)
  * expose backlight controls per display (global/display/displays/...)
  * path for setting workspace background to a solid color
  * Tools/pulldown: can now set a shadow/colored border

# 0.2.0 - New features

  * Tool: Added autolayouter

  * Tool: Added 3d-modelviewer, can remap contents of other
          windows unto a 3d-model.

  * Feature: OCR to Clipboard, access through global/display/region
             Requires tesseract- support in arcan encode frameserver

  * Cheatsheet Widget: Added path activation

  * Security/Safety: Added connection rate limiting

  * Performance: Added dedicated fullscreen mode

# 0.1.0 - Initial Release

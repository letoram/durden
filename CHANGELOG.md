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

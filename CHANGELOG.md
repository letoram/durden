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

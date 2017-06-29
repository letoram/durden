# 0.3.0
  * Now requires arcan >= 0.5.2.

  * Window slicing: target/window/slice allows mouse-selected
	  subregion to (active->input forward or passive) bind a subregion
		of one window to a new window.

  * Tools: added overlay tool

  * External clipboard manager support: external clients can be
	  permitted to read and/or inject entries unto the clipboard. See
		global/config/system/clipboard-bridge.

  * External Gamma controls: external clients can be permitted to set
    custom color/ and gamma/ lookup tables, either per window or globally.
		See target/video/advanced/color-gamma synch and
		global/config/system/gamma-bridge.

  * LED devices: added support for profile driven LED device control
	  see devmaps/led/README.md, global/config/led

  * Input multicast : added support for input multicast groups.
	  Enable per window via target/input/multicast. Keyboard input
		received will be forwarded to all children.

	* Statusbar: can now be set to 'HUD' mode, where it is only visible on the
		global/ or target/ menu HUDs. (config/visual/bars/statusbar(HUD)/...)

  * Tools/Autolayout improvements: can now disable titlebars on
	  side-columns, and allow a different shader on side-columns
		(see global/config/tools/autolayouting)

  * Client- defined mouse-cursor support.

  * Fixes:
	  More consistent font/font-size switching when migrating across
		displays.
		Automatically disable/ignore VIVE, PSVR monitors.
    Defer windows attachment to reduce resize operations.
    Mouse coordinates should be more consistent in dedicated-fullscreen.

  * Minor:
    \+ Split mouse cursors into sets.
		\+ menu options for appl- switching (global/system/reset/...)
    \+ hidden bind path for suspend-state toggle (target/state/...)
    \+ menu path to reset workspace background (global/workspace/...)
		\+ menu path for global/workspace/switch/last
		\+ a shader for luma (monochrome) - only mode
		\+ atype- profile for wayland clients
		\+ option to disable/block mouse (global/input/mouse/block)
		\+ target menu path for set-x, set-y in float mode
		\+ mouse button debounce timer support (global/inpput/mouse/debounce)
		\+ expose backlight controls per display (global/display/displays/...)
    \+ window centering inconsistencies
		\+ Tools/pulldown: can now set a shadow/colored border

  * Moved to a separate webpage, http://durden.arcan-fe.com
    (http because github.io + custom domain = fail, only doc.
		 no code/data distributed from here)

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

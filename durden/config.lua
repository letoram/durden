return {
	msg_timeout = 100,
	tbar_timeout = 200,
	font_def = "default.ttf",
	font_fb = "emoji.ttf",
	font_sz = 18,
	font_hint = 2,
	font_str = "",
	text_color = "\\#aaaaaa",

-- decoration settings
	borderw = 1,
	bordert = 1,
	bordert_float = 1,
	borderw_float = 4,
	border_color = {60, 104, 135},
	titlebar_color = {60, 104, 135},

-- quite expensive so need to be 'none' at start (or have a GPU probe stage)
	shadow_style = "none",
	shadow_focus = 0.5,
	shadow_defocus = 1.0,
	shadow_t = 10,
	shadow_l = 10,
	shadow_d = 10,
	shadow_r = 10,

-- soft, fixed
	shadow_style = "none",
	shadow_color = {0, 0, 0},

-- right now, the options are 'none', 'image', 'full'
	browser_preview = "full",
	browser_timer = 5,
	browser_position = 20,
	browser_trigger = "selection", -- or visibility

-- for the first run, enable more helpers
	first_run = true,

-- show the description field of the menu item that is selected
	menu_helper = true,

-- should entries that request a password show the input as *** chars
	passmask = false,

--
-- advanced lockscreen features, not currently mapped to UI
-- lock_ok = "/some/path/like/resume_all",
-- lock_on = "/some/path/like/suspend_all"
-- lock_fail_1 = "/system/output=fail_once",
-- lock_fail_10 = "/system/shutdown/ok",
--

-- default window dimensions (relative tiler size) for windows
-- created in float mode with unknown starting size
	float_defw = 0.3,
	float_defh = 0.2,

-- % ratio (0..1) of allocated column space for titlebar
	htab_barw = 0.1,

-- padding pixels
	htab_lpad = 0,
	htab_tpad = 0,
	htab_rpad = 0,

-- default encoder setting, used by suppl when building string. We don't
-- have a way to query the span of these parameters yet (like available
-- codecs).
	enc_fps = 30,
	enc_srate = -1,
	enc_vcodec = "H264",
	enc_vpreset = 8,
	enc_container = "mkv",
	enc_presilence = 0,
	enc_vbr = 0,
	enc_vqual = 7,

-- SECURITY: set _path to :disabled to disable these features
	extcon_path = "durden",
	control_path = ":disabled",

-- SECURITY: set to "full" to allow clients that request authentication tokens
-- against the GPU to let those tokens go through. This can compromise security
-- or safety as the privileges given for such a token may expose buffer contents
-- or queue GPU resources that may compromise the display server.
	gpu_auth = "full",

-- SECURITY: set to passive, active, full or none depending on the default
-- access permissions to any client that requests to manage gamma or clipboard
	gamma_access = "none",
	clipboard_access = "none",

-- if > 0, wait n ticks before re-activating external connection path
-- (default clock, ~25 == 1s.)
	extcon_rlimit = 25,
-- ignore rlimit first n ticks after startup (allow initial start burst)
	extcon_startdelay = 100,
-- if n > 0: while >= n external windows, disable external windows (
-- requires extcon_rlimit > 0 as it uses the same timer when evaluating)
	extcon_wndlimit = 0,
-- limit subwindows per connection, also covers hidden windows (e.g. clipboard)
	subwnd_limit = 10,

-- MANUAL/REQUIRES RESTART: setting this to true possibly reduces latency,
-- Performance footprint etc. but prevents certain features like selective
-- desktop sharing and multiple displays.
	display_simple = false,
	display_shader = "basic",

-- clear-color on display rendertarget when no wallpaper is set
	display_color = {30, 30, 30},

-- on dedicated- fullscreen, switch rendertarget refreshrate to the following
-- cloclvalue (0, disabled entirely, -n every n frame, n every n tick
	display_fs_rtrate = 2,

-- some people can't handle the flash transition between workspaces,
-- setting this to a higher value adds animation fade in/out
	transition = 10,
	animation = 10,
	wnd_animation = 10,

-- (none, move-h, move-v, fade)
	ws_transition_in = "fade",
	ws_transition_out = "fade",
	ws_autodestroy = true,
	ws_autoadopt = true,
	ws_default = "tile",
	ws_altmenu = "wsmenu",
	ws_child_default = "parent",
	ws_popup = "wsbtn",

-- per window toggle, global default here
	hide_titlebar = false,

-- if titlebars are "hidden" and this is true, merge the selected window
-- titlebar into the statusbar center area and recursively relayout
	titlebar_statusbar = false,

-- %(fmt-char) p (tag) t (title) i (ident) a (archetype)
-- optional character limit after each entry, whitespace breaks out of fmt-char
	titlebar_ptn = "%p %t - %i",

-- we repeat regular mouse/mstate properties here to avoid a separate
-- path for loading / restoring / updating
	mouse_focus_event = "click", -- motion, hover
	mouse_remember_position = true,
	mouse_factor = 1.0,
	mouse_autohide = true,
	mouse_reveal = true,
	mouse_dblclick = 12,
	mouse_hidetime = 420,
	mouse_hovertime = 40,
	mouse_dragdelta = 4,
	mouse_cursorset = "default",

-- use in iostatem to join all mouse devices into one label
	mouse_coalesce = true,

-- disable all mouse management and related menus
	mouse_block = false,

-- > 0, the minimum clock-delta before a button is accepted again
	mouse_debounce_1 = 0,
	mouse_debounce_2 = 0,
	mouse_debounce_3 = 0,
	mouse_debounce_4 = 0,
	mouse_debounce_5 = 0,
	mouse_debounce_6 = 0,
	mouse_debounce_7 = 0,
	mouse_debounce_8 = 0,

-- used for keyboard- move step size in float mode
	float_tile_sz = {16, 16},
	float_tbar_override = false,
	float_bg_rclick = "/global/tools/popup/menu=/menus/floatbg",
	float_bg_click = "",
	float_bg_dblclick = "",

-- used for adding 'gaps' in the tile layout
	tile_gap_w = 0,
	tile_gap_h = 0,

-- used as a workaround for mouse-control issues when we cannot get
-- relative samples etc. due to being in a windows mode with different
-- scaling parameters, SDL on OSX for instance.
	mouse_hardlock = false,

-- "native' or "nonnative", while native is more energy- efficient as mouse
-- motion do not contribute to a full refresh, it may be bugged on some
-- platforms and have problems with multiple monitors right now.
	mouse_mode = "nonnative",
	mouse_scalef = 1.0,

-- default classifier for unknown touch devices
	mt_classifier = "relmouse",

-- time since last input from which a device is considered in an 'idle' state
	idle_threshold = 2500,

-- audio settings
	global_gain = 1.0,
	gain_fade = 10,
	global_mute = false,

-- default keyboard repeat rate for all windows, some archetypes have
-- default overrides and individual windows can have strong overrides
	kbd_period = 4,
	kbd_delay = 600,

-- accepted values: m1, m2, none
	meta_lock = "m2",
	meta_stick_time = 0,
	meta_dbltime = 10,
	meta_guard = true,

-- minimum amount of ticks from epoch (-1 disables entirely)
-- before device- event notifications appears
	device_notification = 500,

-- built-in terminal defaults
	term_autosz = true, -- will ignore cellw / cellh and use font testrender
	term_cellw = 12,
	term_cellh = 12,
	term_font_sz = 12,
	term_font_hint = 2,
	term_blink = 0,
	term_cursor = "block",
	term_font = "hack.ttf",
	term_bgcol = {0x00, 0x00, 0x00},
	term_fgcol = {0xff, 0xff, 0xff},
	term_opa = 1.0,
	term_bitmap = false,
	term_palette = "",
	term_append_arg = "", -- ci=ind,r,g,b to override individual colors

-- input bar graphics
	lbar_dim = 0.8,
	lbar_tpad = 4,
	lbar_bpad = 0,
	lbar_spacing = 10,
	lbar_sz = 12, -- dynamically recalculated on font changes
	lbar_bg = {0x33, 0x33, 0x33},
	lbar_helperbg = {0x24, 0x24, 0x24},
	lbar_textstr = "\\#cccccc ",
	lbar_alertstr = "\\#ff0000 ",
	lbar_labelstr = "\\#00ff00 ",
	lbar_menulblstr = "\\#ffff00 ",
	lbar_menulblselstr = "\\#ffff00 ",
	lbar_helperstr = "\\#aaaaaa ",
	lbar_errstr = "\\#ff4444 ",
	lbar_caret_w = 2,
	lbar_caret_h = 16,
	lbar_caret_col = {0x00, 0xff, 0x00},
	lbar_seltextstr = "\\#ffffff ",
	lbar_seltextbg = {0x44, 0x66, 0x88},
	lbar_itemspace = 10,
	lbar_fltfun = "prefix",

-- binding bar
	bind_waittime = 30,
	bind_repeat = 5,

-- statusbar
	sbar_tpad = 2, -- add some space to the text
	sbar_bpad = 2,
	sbar_sz = 12, -- dynamically recalculated on font changes
	sbar_textstr = "\\#00ff00 ",
	sbar_alpha = 0.3,
	sbar_tspace = 0,
	sbar_lspace = 0,
	sbar_dspace = 0,
	sbar_rspace = 0,
	sbar_tshadow = 8,
	sbar_lshadow = 8,
	sbar_dshadow = 8,
	sbar_rshadow = 8,
	sbar_popup_pad = 4,
	sbar_shadow = "soft",
	sbar_shadow_color = {0x00, 0x00, 0x00},
	sbar_pos = "top",
	sbar_visible = "desktop", -- (desktop / hud / hidden)
	sbar_wsbuttons = true, -- show the dynamic workspace switch buttons
	sbar_numberprefix = true,
	sbar_lblcolor = "dynamic", -- or specific: "\\#ffff00",
	sbar_prefixcolor = "dynamic", -- "\\#ffffff ",

-- titlebar
	tbar_sz = 12, -- dynamically recalculated on font changes
	tbar_tpad = 4,
	tbar_bpad = 2,
	tbar_text = "left", -- left, center, right
	tbar_textstr = "\\#ffffff ",
	tbar_rclick = "/global/tools/popup/menu=/target",

-- icons
	icon_set = "default",

-- notification system
	notifications_enable = true,

-- LWA specific settings, only really useful for development / debugging
	lwa_autores = true
};

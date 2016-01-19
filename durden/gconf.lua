-- Copyright 2015, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: Global / Persistent configuration management copied from
-- senseye, tracks default font, border, layout and other settings.
--

-- here for the time being, will move with internationalization
LBL_YES = "yes";
LBL_NO = "no";
LBL_BIND_COMBINATION = "Press and hold the desired combination, %s to Abort";
LBL_UNBIND_COMBINATION = "Press and hold the combination to unbind, %s to Abort";
LBL_METAGUARD = "Query Rebind in %d keypresses";
LBL_METAGUARD_META = "Rebind \\bmeta keys\\!b  in %.2f second, %s to Abort";
LBL_METAGUARD_BASIC = "Rebind \\bbasic keys\\!b  in %.2f seconds, %s to Abort";
LBL_METAGUARD_MENU = "Rebind \\bmenu\\!b  binding in %.2f seconds, %s to Abort";

local defaults = {
	msg_timeout = 100,
	tbar_timeout = 200,
	font_def = "default.ttf",
	font_sz = 12,
	font_hint = 1,
	font_str = "",
	text_color = "\\#aaaaaa",
	label_color = "\\#ffff00",
	borderw = 1,
	bordert = 1,

-- set to empty or "" to disable
	extcon_path = "durden",
	status_path = "<durden_status",
	control_path = "<durden_control",

-- MANUAL/REQUIRES RESTART: setting this to true possibly reduces latency,
-- performance footprint etc. but prevents certain features like selective
-- desktop sharing and multiple displays.
	display_simple = false,

-- some people can't handle the flash transition between workspaces,
-- setting this to a higher value adds animation fade in/out
	transition = 10,

-- (none, move-h, move-v, fade)
	ws_transition_in = "fade",
	ws_transition_out = "fade",
	ws_autodestroy = false,
	ws_autoadopt = true,
	ws_default = "tile",

-- we repeat regular mouse/mstate properties here to avoid a separate
-- path for loading / restoring / updating
	mouse_focus_event = "click", -- motion, hover
	mouse_remember_position = false,
	mouse_factor = 1.0,
	mouse_autohide = false,
	mouse_dblclick_step = 12,
	mouse_hidetime = 40,
	mouse_hovertime = 40,
	mouse_dragdelta = 4,

-- used for keyboard- move step size in float mode
	float_tile_sz = {16, 16},

-- used as a workaround for mouse-control issues when we cannot get
-- relative samples etc. due to being in a windows mode with different
-- scaling parameters.
	mouse_hardlock = false,

-- "native' or "nonnative", while native is more energy- efficient as mouse
-- motion do not contribute to a full refresh, it may be bugged on some
-- platforms
	mouse_mode = "nonnative",

-- audio settings
	global_gain = 1.0,
	gain_fade = 10,
	global_mute = false,

-- default keyboard repeat rate for all windows, some archetypes have
-- default overrides and individual windows can have strong overrides
	kbd_period = 60,
	kbd_delay = 300,

-- built-in terminal defaults
	term_rows = 80,
	term_cols = 25,
	term_autosz = true, -- will ignore cellw / cellh and use font testrender
	term_cellw = 12,
	term_cellh = 12,
	term_font_sz = 12,
	term_font_hint = "none",
	term_font = "hack.ttf",
	term_bgcol = {0x00, 0x00, 0x00},
	term_fgcol = {0xff, 0xff, 0xff},
	term_opa = 1.0,

-- input bar graphics
	lbar_position = "center", -- top, center, bottom
	lbar_dim = 0.8,
	lbar_pad = 2,
	lbar_sz = 12, -- dynamically recalculated on font changes
	lbar_transition = 10,
	lbar_bg = {0x33, 0x33, 0x33},
	lbar_textstr = "\\#cccccc ",
	lbar_labelstr = "\\#00ff00 ",
	lbar_menulblstr = "\\#ffff00 ",
	lbar_menulblselstr = "\\#ffff00 ",
	lbar_errstr = "\\#ff4444 ",
	lbar_caret_w = 2,
	lbar_caret_h = 16,
	lbar_label_col = {0xff, 0xff, 0x00},
	lbar_caret_col = {0x00, 0xff, 0x00},
	lbar_seltextstr = "\\#ffffff ",
	lbar_seltextbg = {0x44, 0x66, 0x88},
	lbar_itemspace = 10,
	lbar_textsz = 12,

-- binding bar
	bind_waittime = 30,

-- sbar
	sbar_pad = 2,
	sbar_sz = 12, -- dynamically recalculated on font changes
	sbar_bg = {0x00, 0x00, 0x00},
	sbar_textstr = "\\#00ff00 ",
	sbar_alpha = 0.3,

-- titlebar
  tbar_pad = 2,
	tbar_sz = 12, -- dynamically recalculated on font changes
	tbar_bg = {0x28, 0x55, 0x77},
	tbar_textstr = "\\#ffffff ",

-- popup
	pcol_bg = {0x3c, 0x3c, 0x3c},
	pcol_border = {0x88, 0x88, 0x88},
	pcol_act_bg = {0x44, 0x44, 0xaa},
	pcol_act_border = {0x88, 0x88, 0xff},

-- tile
	tbar_active = {0x3c, 0x68, 0x89},
	tbar_inactive = {0x1c, 0x38, 0x59},
	tcol_border = {0x4c, 0x78, 0x99},
	tcol_inactive_border = {0x10, 0x10, 0x10},
	tcol_alert = {0xff, 0x8c, 0x00},
	tcol_alert_border = {0xff, 0xff, 0xff},
	pretile_border = {0x88, 0x00, 0x00},
	pretile_bg = {0x44, 0x00, 0x00},
	pretiletext_color = "\\#ffffff ",
};

local listeners = {};
function gconfig_listen(key, id, fun)
	if (listeners[key] == nil) then
		listeners[key] = {};
	end
	listeners[key][id] = fun;
end

function gconfig_set(key, val)
if (type(val) ~= type(defaults[key])) then
		warning(string.format("gconfig_set(), type (%s) mismatch (%s) for key (%s)",
			type(val), type(defaults[key]), key));
		return;
	end

	defaults[key] = val;

	if (listeners[key]) then
		for k,v in pairs(listeners[key]) do
			v(key, val);
		end
	end
end

function gconfig_get(key)
	return defaults[key];
end

local function gconfig_setup()
	for k,vl in pairs(defaults) do
		local v = get_key(k);
		if (v) then
			if (type(vl) == "number") then
				defaults[k] = tonumber(v);
-- no packing format for tables, ignore for now, since its a trusted context,
-- we can use concat / split without much issue, although store_key should
-- really support deep table serialization
			elseif (type(vl) == "table") then
				defaults[k] = defaults[k];
			elseif (type(vl) == "boolean") then
				defaults[k] = v == "true";
			else
				defaults[k] = v;
			end
		end
	end

	local ms = mouse_state();
	mouse_acceleration(defaults.mouse_factor, defaults.mouse_factor);
	ms.autohide = defaults.mouse_autohide;
	ms.hover_ticks = defaults.mouse_hovertime;
	ms.drag_delta = defaults.mouse_dragdelta;
	ms.hide_base = defaults.mouse_hidetime;
end

-- shouldn't store all of default overrides in database, just from a
-- filtered subset
function gconfig_shutdown()
	local ktbl = {};
	for k,v in pairs(defaults) do
		if (type(ktbl[k]) ~= "table") then
			ktbl[k] = tostring(v);
		end
	end

	store_key(ktbl);
end

gconfig_setup();

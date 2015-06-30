-- Copyright 2015, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: Global / Persistent configuration management copied from
-- senseye, tracks default font, border, layout and other settings.
--
local defaults = {
	msg_timeout = 100,
	transition_time = 10,
	font_str = "\\fdefault.ttf,12",
	text_color = "\\#aaaaaa",

-- "generic" UI interaction bindings that work in specialized contexts
-- (input bar, popups, ...)
	kbd_repeat = 100,
	ok_sym = "RETURN",
	cancel_sym = "ESCAPE",
	step_next = "UP",
	step_previous = "DOWN",
	caret_home = "HOME",
	caret_end = "END",
	caret_left = "LEFT",
	caret_right = "RIGHT",
	caret_delete = "DELETE",
	caret_erase = "BACKSPACE",

-- input bar
	lbar_position = "center", -- top, center, bottom
	lbar_sz = 16,
	lbar_bg = {0x33, 0x33, 0x33},
	lbar_textstr = "\\fdefault.ttf,12\\#cccccc ",
	lbar_labelstr = "\\fdefault.ttf,12\\#00ff00 ",
	lbar_menulblstr = "\\fdefault.ttf,12\\#ffff00 ",
	lbar_menulblselstr = "\\fdefault.ttf,12\\#ffff00 ",
	lbar_caret_w = 2,
	lbar_caret_h = 16,
	lbar_label_col = {0xff, 0xff, 0x00},
	lbar_caret_col = {0x00, 0xff, 0x00},
	lbar_seltextstr = "\\fdefault.ttf,12\\#ffffff ",
	lbar_seltextbg = {0x44, 0x66, 0x88},
	lbar_itemspace = 10,
	lbar_textsz = 12,

-- sbar
	sbar_sz = 16,
	sbar_bg = {0x00, 0x00, 0x00},

-- titlebar
  tbar_sz = 16,
	tbar_bg = {0x28, 0x55, 0x77},
	tbar_textstr = "\\fdefault.ttf,12\\#ffffff ",

-- popup
	pcol_bg = {0x3c, 0x3c, 0x3c},
	pcol_border = {0x88, 0x88, 0x88},
	pcol_act_bg = {0x44, 0x44, 0xaa},
	pcol_act_border = {0x88, 0x88, 0xff},

-- tile
	tcol_border = {0x4c, 0x78, 0x99},
	tcol_inactive_border = {0x10, 0x10, 0x10},
	tcol_alert = {0xff, 0x8c, 0x00},
	tcol_alert_border = {0xff, 0xff, 0xff},
};

function gconfig_set(key, val)
if (type(val) ~= type(defaults[key])) then
		warning("gconfig_set(), type mismatch for key: " .. key);
		return;
	end

	defaults[key] = val;
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
-- no packing format for tables, ignore for now
			elseif (type(vl) == "table") then
				defaults[k] = defaults[k];
			else
				defaults[k] = v;
			end
		end
	end
end

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

-- Copyright 2015, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: Global / Persistent configuration management copied from
-- senseye, tracks default font, border, layout and other settings.
--
local defaults = {
	msg_timeout = 100,
	font_str = "\\fdefault.ttf,12",
	text_color = "\\#aaaaaa",
-- sbar
	sbar_sz = 16,
	sbar_bg = {0x00, 0x00, 0x00},
-- popup
	pcol_bg = {0.2, 0.2, 0.2},
	pcol_border = {0.6, 0.6, 0.6},
	pcol_act_bg = {0.3, 0.3, 0.8},
	pcol_act_border = {0.6, 0.6, 1.0},
-- tile
	tcol_border = {0x00, 0xff, 0x00},
	tcol_inactive_border = {0x10, 0x10, 0x10},
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

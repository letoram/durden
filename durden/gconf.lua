-- Copyright 2015-2019, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
--
-- Description: Global / Persistent configuration management.
-- Deals with key lookup, update hooks and so on. For actual default
-- configuration values, see config.lua
--

local log, fmt = suppl_add_logfn("config");

-- here for the time being, will move with internationalization
LBL_YES = "yes";
LBL_NO = "no";
LBL_FLIP = "toggle";
LBL_BIND_COMBINATION = "Press and hold the desired combination, %s to Cancel";
LBL_BIND_KEYSYM = "Press and hold single key to bind keysym %s, %s to Cancel";
LBL_BIND_COMBINATION_REP = "Press and hold or repeat- press, %s to Cancel";
LBL_UNBIND_COMBINATION = "Press and hold the combination to unbind, %s to Cancel";
LBL_METAGUARD = "Query Rebind in %d keypresses";
LBL_METAGUARD_META = "Rebind (meta keys) in %.2f seconds, %s to Cancel";
LBL_METAGUARD_BASIC = "Rebind (basic keys) in %.2f seconds, %s to Cancel";
LBL_METAGUARD_MENU = "Rebind (global menu) in %.2f seconds, %s to Cancel";
LBL_METAGUARD_TMENU = "Rebind (target menu) in %.2f seconds, %s to Cancel";

HC_PALETTE = {
	"\\#efd469",
	"\\#43abc9",
	"\\#cd594a",
	"\\#b5c689",
	"\\#f58b4c",
	"\\#ed6785",
	"\\#d0d0d0",
};

local defaults = system_load("config.lua")();
local listeners = {};

function gconfig_listen(key, id, fun)
	if (listeners[key] == nil) then
		listeners[key] = {};
	end
	listeners[key][id] = fun;
end

-- for tools and other plugins to enable their own values
function gconfig_register(key, val)
	if (not defaults[key]) then
		local v = get_key(key);
		if (v ~= nil) then
			if (type(val) == "number") then
				v = tonumber(v);
			elseif (type(val) == "boolean") then
				v = v == "true";
			end
			defaults[key] = v;
		else
			defaults[key] = val;
		end
	end
end

function gconfig_set(key, val, force)
	if (type(val) ~= type(defaults[key])) then
		log(fmt(
			"key=%s:kind=error:type_in=%s:type_out=%s:value=%s",
			key, type(val), type(defaults[key]), val
		));
		return;
	end

-- lua5.1 timebomb, 5.2 adds to_lstring on args, 5.1 does not, might
-- need to go with a fixup where .format walks ... and tostrings boolean
	log(fmt("key=%s:kind=set:new_value=%s", key, tostring(val)));
	defaults[key] = val;

	if (force) then
		store_key(key, tostring(val));
	end

	if (listeners[key]) then
		for k,v in pairs(listeners[key]) do
			v(key, val);
		end
	end
end

function gconfig_get(key)
	return defaults[key];
end

--
-- these need special consideration, packing and unpacking so treat
-- them separately
--

gconfig_buttons = {
	all = {},
	float = {
	},
	tile = {
	},
};

gconfig_statusbar_buttons = {
};

-- for the sake of convenience, : is blocked from being a valid vsym as
-- it is used as a separator elsewhere (suppl_valid_vsymbol)
local function btn_str(v)
	return string.format("%s:%s:%s", v.direction, v.label, v.command);
end

local function str_to_btn(dst, v)
	local str, rest = string.split_first(v, "=");
	local dir, rest = string.split_first(rest, ":");
	local key, rest = string.split_first(rest, ":");
	local base, cmd = string.split_first(rest, ":");

	if (#dir > 0 and #rest > 0 and #key > 0) then
		local ind = string.sub(str, 10);

		table.insert(dst, {
			label = key,
			command = cmd,
			direction = dir,
			ind = tonumber(ind)
		});
		return true;
	end
end

function gconfig_statusbar_rebuild(nosynch)
--double negative, but oh well - save the current state as config
	if (not nosynch) then
		drop_keys("sbar_btn_%");
		drop_keys("sbar_btn_alt_%");
		drop_keys("sbar_btn_drag_%");
		local keys_out = {};

		for i,v in ipairs(gconfig_statusbar_buttons) do
			keys_out["sbar_btn_" .. tostring(i)] = btn_str(v);
			if (v.alt_command) then
				keys_out["sbar_btn_alt_" .. tostring(i)] = v.alt_command;
			end
			if (v.drag_command) then
				keys_out["sbar_btn_drag_" .. tostring(i)] = v.drag_command;
			end
		end
		store_key(keys_out);
	end

	gconfig_statusbar_buttons = {};
	local ofs = 0;
	for _,v in ipairs(match_keys("sbar_btn_%")) do
		if (str_to_btn(gconfig_statusbar_buttons, v)) then
			local ent = gconfig_statusbar_buttons[#gconfig_statusbar_buttons];
			if (ent.ind) then
				ent.alt_command = get_key("sbar_btn_alt_" .. tostring(ent.ind));
				ent.drag_command = get_key("sbar_btn_drag_" .. tostring(ent.ind));
			end
		end
	end

-- will take care of synching against gconfig_statusbar,
-- but only if the tiler itself expose that method (i.e.
-- gconf can be loaded before)
	if all_tilers_iter then
		for tiler in all_tilers_iter() do
			if (tiler.rebuild_statusbar_custom) then
				tiler:rebuild_statusbar_custom(gconfig_statusbar_buttons);
			end
		end
	end
end

function gconfig_buttons_rebuild(nosynch)
	local keys = {};

-- delete the keys, then rebuild buttons so we use the same code for both
-- update dynamically and for initial load
	if (not nosynch) then
		drop_keys("tbar_btn_all_%");
		drop_keys("tbar_btn_float_%");
		drop_keys("tbar_btn_tile_%");

		local keys_out = {};
		for _, group in ipairs({"all", "float", "tile"}) do
			for i,v in ipairs(gconfig_buttons[group]) do
				keys_out["tbar_btn_" .. group .. "_" .. tostring(i)] = btn_str(v);
			end
		end
		store_key(keys_out);
	end

	for _, group in ipairs({"all", "float", "tile"}) do
		gconfig_buttons[group] = {};
		for _,v in ipairs(match_keys("tbar_btn_" .. group .. "_%")) do
			str_to_btn(gconfig_buttons[group], v);
		end
	end
end

local function gconfig_setup()
	for k,vl in pairs(defaults) do
		local v = get_key(k);
		if (v) then
			if (type(vl) == "number") then
				defaults[k] = tonumber(v);
-- naive packing for tables (only used with colors currently), just
-- use : as delimiter and split/concat to manage - just sanity check/
-- ignore on count and assume same type.
			elseif (type(vl) == "table") then
				local lst = string.split(v, ':');
				local ok = true;
				for i=1,#lst do
					if (not vl[i]) then
						ok = false;
						break;
					end
					if (type(vl[i]) == "number") then
						lst[i] = tonumber(lst[i]);
						if (not lst[i]) then
							ok = false;
							break;
						end
					elseif (type(vl[i]) == "boolean") then
						lst[i] = lst[i] == "true";
					end
				end
				if (ok) then
					defaults[k] = lst;
				end
			elseif (type(vl) == "boolean") then
				defaults[k] = v == "true";
			else
				defaults[k] = v;
			end
		end
	end

-- separate handling for mouse
	local ms = mouse_state();
	mouse_acceleration(defaults.mouse_factor, defaults.mouse_factor);
	ms.autohide = defaults.mouse_autohide;
	ms.hover_ticks = defaults.mouse_hovertime;
	ms.drag_delta = defaults.mouse_dragdelta;
	ms.hide_base = defaults.mouse_hidetime;
	for i=1,8 do
		ms.btns_bounce[i] = defaults["mouse_debounce_" .. tostring(i)];
	end

-- and for the high-contrast palette used for widgets, ...
	for i,v in ipairs(match_keys("hc_palette_%")) do
		local cl = string.split(v, "=")[2];
		HC_PALETTE[i] = cl;
	end

-- and for global state of titlebar and statusbar
	gconfig_buttons_rebuild(true);
	gconfig_statusbar_rebuild(true);
end

local mask_state = false;
function gconfig_mask_temp(state)
	mask_state = state;
end

-- shouldn't store all of default overrides in database, just from a
-- filtered subset
function gconfig_shutdown()
	local ktbl = {};
	for k,v in pairs(defaults) do
		if (type(v) ~= "table") then
			ktbl[k] = tostring(v);
		else
			ktbl[k] = table.concat(v, ':');
		end
	end

	if not mask_state then
		for i,v in ipairs(match_keys("durden_temp_%")) do
			local k = string.split(v, "=")[1];
			ktbl[k] = "";
		end
	end
	store_key(ktbl);
end

gconfig_setup();

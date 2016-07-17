--
-- Default Keybindings
--
-- keys match SYMTABLE style fields, with the prefix:
-- m1_ for meta1
-- m2_ for meta2
-- m1_m2_ for meta1+meta2
--
-- the output resolves to an entry in GLOBAL_FUNCTIONS or
-- in a custom per/target config
--
-- These are >static defaults< meaning that they can be overridden at runtime
-- and saved in the appl- specific database.
--

-- system keys are special in that they are checked for collisions when
-- binding, hence should be kept to an absolute minimum.
SYSTEM_KEYS = {
	["meta_1"] = "MENU",
	["meta_2"] = "RSHIFT",
	["accept"] = "RETURN",
	["cancel"] = "ESCAPE",
	["next"] = "UP",
	["previous"] = "DOWN",
	["caret_home"] = "HOME",
	["caret_end"]  = "END",
	["caret_left"] = "LEFT",
	["caret_right"] = "RIGHT",
	["caret_delete"] = "DELETE",
	["caret_erase"] = "BACKSPACE"
};

-- bindings here match either the shared global_functions table, or a path for
-- those that should be treated as normal menu navigation (and may map more
-- dynamic options, i.e. setting values etc.)
local tbl = {};

-- table and save management is managed here, but manual invokation from
-- normal input event handler
local stbl = {};

-- state tracking table for locking/unlocking, double-tap tracking, and sticky
local mtrack = {
	m1 = nil,
	m2 = nil,
	last_m1 = 0,
	last_m2 = 0,
	unstick_ctr = 0,
	dblrate = 10,
	mstick = 0,
	mlock = "none"
};

function dispatch_reset(save)
	tbl = {};
	tbl["m1_RETURN"] = "spawn_terminal";
	tbl["m1_d"] = "!open/target";
	tbl["m1_c"] = "!display/cycle";
	tbl["m1_g"] = "global_actions";
	tbl["m1_h"] = "target_actions";
	tbl["m1_RIGHT"] = "step_right";
	tbl["m1_UP"] = "step_up";
	tbl["m1_LEFT"] = "step_left";
	tbl["m1_DOWN"] = "step_down";
	tbl["m1_m2_d"] = "destroy";
	tbl["m1_v"] = "clipboard_paste";
	tbl["m1_m2_LEFT"] = "shrink_h";
	tbl["m1_m2_RIGHT"] = "grow_h";
	tbl["m1_m2_UP"] = "shrink_v";
	tbl["m1_m2_DOWN"] = "grow_v";
	tbl["m1_m2_h"] = "swap_left";
	tbl["m1_m2_j"] = "swap_up";
	tbl["m1_m2_k"] = "swap_down";
	tbl["m1_m2_l"] = "swap_right";
	tbl["m1_m2_TAB"] = "tiletog";
	tbl["m1_t"] = "tab";
	tbl["m1_m2_t"] = "vtab";
	tbl["m1_r"] = "fullscreen";
	tbl["m1_m2_y"] = "float";
	tbl["m1_m"] = "mergecollapse";
	tbl["m2_LEFT"] = "move_nx";
	tbl["m2_RIGHT"] = "move_px";
	tbl["m2_UP"] = "move_ny";
	tbl["m2_DOWN"] = "move_py";
	tbl["m1_1"] = "switch_ws1";
	tbl["m1_2"] = "switch_ws2";
	tbl["m1_3"] = "switch_ws3";
	tbl["m1_4"] = "switch_ws4";
	tbl["m1_5"] = "switch_ws5";
	tbl["m1_6"] = "switch_ws6";
	tbl["m1_7"] = "switch_ws7";
	tbl["m1_8"] = "switch_ws8";
	tbl["m1_9"] = "switch_ws9";
	tbl["m1_0"] = "switch_ws10";
	tbl["m1_m2_r"] = "rename_space";
	tbl["m1_m2_1"] = "assign_ws1";
	tbl["m1_m2_2"] = "assign_ws2";
	tbl["m1_m2_3"] = "assign_ws3";
	tbl["m1_m2_4"] = "assign_ws4";
	tbl["m1_m2_5"] = "assign_ws5";
	tbl["m1_m2_6"] = "assign_ws6";
	tbl["m1_m2_7"] = "assign_ws7";
	tbl["m1_m2_8"] = "assign_ws8";
	tbl["m1_m2_9"] = "assign_ws9";
	tbl["m1_m2_0"] = "assign_ws10";

-- clear all existing and define new ones
	if (save) then
		local rst = {};
		for i,v in ipairs(match_keys("custk_%")) do
			local pos, stop = string.find(v, "=", 1);
			local key = string.sub(v, 1, pos-1);
			rst[key] = "";
		end

		store_key(rst);
		store_key(tbl);
	end
end

dispatch_reset();
-- the following line can be removed if meta state protection is not needed
system_load("meta_guard.lua")();

function dispatch_system(key, val)
	if (SYSTEM_KEYS[key] ~= nil) then
		SYSTEM_KEYS[key] = val;
		store_key("sysk_" .. key, val);
	else
		warning("tried to assign " .. key .. " / " .. val .. " as system key");
	end
end

function dispatch_tick()
	if (mtrack.unstick_ctr > 0) then
		mtrack.unstick_ctr = mtrack.unstick_ctr - 1;
		if (mtrack.unstick_ctr == 0) then
			mtrack.m1 = nil;
			mtrack.m2 = nil;
		end
	end
end

function dispatch_load(locktog)
	gconfig_listen("meta_stick_time", "keybindings.lua",
	function(key, val)
		mtrack.mstick = val;
	end);
	gconfig_listen("meta_dbltime", "keybindings.lua",
	function(key, val)
		mtrack.dblrate = val;
	end
	);
	gconfig_listen("meta_lock", "keybindings.lua",
	function(key, val)
		mtrack.mlock = val;
	end
	);

	mtrack.dblrate = gconfig_get("meta_dbltime");
	mtrack.mstick = gconfig_get("meta_stick_time");
	mtrack.mlock = gconfig_get("meta_lock");
	mtrack.locktog = locktog;

	for k,v in pairs(SYSTEM_KEYS) do
		local km = get_key("sysk_" .. k);
		if (km ~= nil) then
			SYSTEM_KEYS[k] = tostring(km);
		end
	end

	local get_kv = function(str)
		local pos, stop = string.find(str, "=", 1);
		local key = string.sub(str, 7, pos - 1);
		local val = string.sub(str, stop + 1);
		return key, val;
	end

-- custom bindings, global shared
	for i,v in ipairs(match_keys("custg_%")) do
		local key, val = get_kv(v);
		if (val and string.len(val) > 0) then
			tbl[key] = "!" .. val;
		end
	end

-- custom bindings, window shared
	for i,v in ipairs(match_keys("custs_%")) do
		local key, val = get_kv(v);
		if (val and string.len(val) > 0) then
			tbl[key] = "#" .. val;
		end
	end
end

function dispatch_list()
	local res = {};
	for k,v in pairs(tbl) do
		table.insert(res, k .. "=" .. v);
	end
	table.sort(res);
	return res;
end

function dispatch_custom(key, val, nomb, wnd, global, falling)
	if (falling) then
		key = "f_" .. key;
	end

	local old = tbl[key];
	local pref = wnd and "custs_" or "custg_";
-- go through these hoops to support unbind (nomb),
-- global/target prefix (which uses symbols not allowed as dbkey)
	if (nomb) then
		tbl[key] = val;
	else
		tbl[key] = val and ((wnd and "#" or "!") .. val) or nil;
	end

	store_key(pref .. key, val and val or "");
	return old;
end

function dispatch_meta()
	return mtrack.m1 ~= nil, mtrack.m2 ~= nil;
end

function dispatch_meta_reset(m1, m2)
	mtrack.m1 = m1 and CLOCK or nil;
	mtrack.m2 = m2 and CLOCK or nil;
end

function dispatch_toggle(forcev, state)
	local oldign = mtrack.ignore;

	if (mtrack.mlock == "none") then
		mtrack.ignore = false;
		return;
	end

	if (forcev ~= nil) then
		mtrack.ignore = forcev;
	else
		mtrack.ignore = not mtrack.ignore;
	end

-- run cleanup hook
	if (type(oldign) == "function" and mtrack.ignore ~= oldign) then
		oldign();
	end

	if (mtrack.locktog) then
		mtrack.locktog(mtrack.ignore, state);
	end
end

local function track_label(iotbl, keysym, hook_handler)
	local metadrop = false;
	local metam = false;

-- notable state considerations here, we need to construct
-- a string label prefix that correspond to the active meta keys
-- but also take 'sticky' (release- take artificially longer) and
-- figure out 'gesture' (double-press)
	local function metatrack(s1)
		local rv1, rv2;
		if (iotbl.active) then
			if (mtrack.mstick > 0) then
				mtrack.unstick_ctr = mtrack.mstick;
			end
			rv1 = CLOCK;
		else
			if (mtrack.mstick > 0) then
				rv1 = s1;
			else
-- rv already nil
			end
			rv2 = CLOCK;
		end
		metam = true;
		return rv1, rv2;
	end

	if (keysym == SYSTEM_KEYS["meta_1"]) then
		local m1, m1d = metatrack(mtrack.m1, mtrack.last_m1);
		mtrack.m1 = m1;
		if (m1d and mtrack.mlock == "m1") then
			if (m1d - mtrack.last_m1 <= mtrack.dblrate) then
				dispatch_toggle();
			end
			mtrack.last_m1 = m1d;
		end
	elseif (keysym == SYSTEM_KEYS["meta_2"]) then
		local m2, m2d = metatrack(mtrack.m2, mtrack.last_m2);
		mtrack.m2 = m2;
		if (m2d and mtrack.mlock == "m2") then
			if (m2d - mtrack.last_m2 <= mtrack.dblrate) then
				dispatch_toggle();
			end
			mtrack.last_m2 = m2d;
		end
	end

	local lutsym = "" ..
		(mtrack.m1 and "m1_" or "") ..
		(mtrack.m2 and "m2_" or "") .. keysym;

	if (hook_handler) then
		hook_handler(active_display(), keysym, iotbl, lutsym, metam, tbl[lutsym]);
		return true, lutsym;
	end

	if (metam or not meta_guard(mtrack.m1 ~= nil, mtrack.m2 ~= nil)) then
		return true, lutsym;
	end

	return false, lutsym;
end

--
-- Central input management / routing / translation outside of
-- mouse handlers and iostatem_ specific translation and patching.
--
-- definitions:
-- SYM = internal SYMTABLE level symble
-- LUTSYM = prefix with META1 or META2 (m1, m2) state (or device data)
-- OUTSYM = prefix with normal modifiers (ALT+x, etc.)
-- LABEL = more abstract and target specific identifier
--
local last_deferred = nil;
function dispatch_translate(iotbl, nodispatch)
	local ok, sym, outsym, lutsym;
	local sel = active_display().selected;

-- apply keymap (or possibly local keymap), note that at this stage,
-- iostatem_ has converted any digital inputs that are active to act
-- like translated
	if (iotbl.translated or iotbl.dsym) then
		if (iotbl.dsym) then
			sym = iotbl.dsym;
			outsym = sym;
		elseif (sel and sel.symtable) then
			sym, outsym = sel.symtable:patch(iotbl);
		else
			sym, outsym = SYMTABLE:patch(iotbl);
		end
-- generate durden specific meta- tracking or apply binding hooks
		ok, lutsym = track_label(iotbl, sym, active_display().input_lock);
	end

	if (not lutsym or mtrack.ignore) then
		if (type(mtrack.ignore) == "function") then
			return mtrack.ignore(lutsym, iotbl, tbl[lutsym]);
		end

		return false, nil, iotbl;
	end

	if (ok or nodispatch) then
		return true, lutsym, iotbl, tbl[lutsym];
	end

	local rlut = "f_" ..lutsym;
	if (tbl[lutsym] or (not iotbl.active and tbl[rlut])) then
		if (iotbl.active and tbl[lutsym]) then
			dispatch_symbol(tbl[lutsym]);
			if (tbl[rlut]) then
				last_deferred = tbl[rlut];
			end

		elseif (tbl[rlut]) then
			dispatch_symbol(tbl[rlut]);
			last_deferred = nil;
		end

-- don't want to run repeat for valid bindings
		iostatem_reset_repeat();
		return true, lutsym, iotbl;
	elseif (last_deferred) then
		dispatch_symbol(last_deferred);
		last_deferred = nil;
		return true, lutsym, iotbl;
	elseif (not sel) then
		return false, lutsym, iotbl;
	end

-- we can have special bindings on a per window basis
	if (sel.bindings and sel.bindings[lutsym]) then
		if (iotbl.active) then
			sel.bindings[lutsym](sel);
		end
		ok = true;
-- or an input handler unique for the window
	elseif (not iotbl.analog and sel.key_input) then
		sel:key_input(outsym, iotbl);
		ok = true;
	else
-- for label bindings, we go with the non-internal view of modifiers
		if (sel.labels) then
			iotbl.label = sel.labels[outsym] and sel.labels[outsym] or iotbl.label;
		end
	end

	return ok, outsym, iotbl;
end

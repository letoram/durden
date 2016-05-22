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

-- We assume that all relevant input related functions go
-- through this one as it is used to map track meta_ key state.
local meta_1_state = false;
local meta_2_state = false;

function dispatch_system(key, val)
	if (SYSTEM_KEYS[key] ~= nil) then
		SYSTEM_KEYS[key] = val;
		store_key("sysk_" .. key, val);
	else
		warning("tried to assign " .. key .. " / " .. val .. " as system key");
	end
end

function dispatch_load()
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

function dispatch_custom(key, val, nomb, wnd, global)
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
	return meta_1_state, meta_2_state;
end

function dispatch_meta_reset(m1, m2)
	meta_1_state = m1 and m1 or false;
	meta_2_state = m2 and m2 or false;
end

local function track_label(iotbl, keysym, hook_handler)
	local metadrop = false;

	local metam = false;
	if (keysym == SYSTEM_KEYS["meta_1"]) then
		meta_1_state = iotbl.active;
		metam = true;

	elseif (keysym == SYSTEM_KEYS["meta_2"]) then
		meta_2_state = iotbl.active;
		metam = true;
	end

	local lutsym = "" ..
		(meta_1_state == true and "m1_" or "") ..
		(meta_2_state == true and "m2_" or "") .. keysym;

	if (hook_handler) then
		hook_handler(active_display(), keysym, iotbl, lutsym, metam, tbl[lutsym]);
		return true, lutsym;
	end

	if (metam or not meta_guard(meta_1_state, meta_2_state)) then
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

	elseif (iotbl.analog) then
		if (active_display().input_alock) then
			ok = active_display().input_alock(iotbl);
		end
	else
-- miss handling of other sensors and touch devices here
	end

	if (not lutsym) then
		return false, nil, iotbl;
	end

	if (ok or nodispatch) then
		return true, lutsym, iotbl, tbl[lutsym];
	end

	if (tbl[lutsym]) then
		if (iotbl.active) then
			dispatch_symbol(tbl[lutsym]);
		end
-- don't want to run repeat for valid bindings
		iostatem_reset_repeat();
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

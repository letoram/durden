--
-- Keyboard dispatch
--
local tbl = system_load("keybindings.lua")();

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

local function update_meta(m1, m2)
	mtrack.m1 = m1;
	mtrack.m2 = m2;

-- forward the state change to the led manager
	m1, m2 = dispatch_meta();
	if (m1 or m2) then
		local pref = (m1 and "m1_" or "") .. (m2 and "m2_" or "");
		local global = {};
		local target = {};

-- filter out set of valid bindings
		for k,v in pairs(tbl) do
			if (string.sub(k, 1, string.len(pref)) == pref) then
				if (string.sub(k, string.len(pref)+1, 2) == "m2") then
-- special case, m1_ on m1_m2__ binding
				else
					if (string.sub(v, 1, 1) == "#") then
						table.insert(target, {string.sub(k, string.len(pref)+1), v});
					else
						table.insert(global, {string.sub(k, string.len(pref)+1), v});
					end
				end
			end
		end

		ledm_kbd_state(m1, m2, dispatch_locked(), global, target);
	else
	-- get the default and bound locals
		ledm_kbd_state(m1, m2, dispatch_locked()
			-- locked
			-- globals
			-- targets
			-- locals
		);
	end
end

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
			update_meta(nil, nil);
		end
	end
end

function dispatch_locked()
	return mtrack.ignore ~= false and mtrack.ignore ~= nil;
end

function dispatch_load(locktog)
	gconfig_listen("meta_stick_time", "dispatch.lua",
	function(key, val)
		mtrack.mstick = val;
	end);
	gconfig_listen("meta_dbltime", "dispatch.lua",
	function(key, val)
		mtrack.dblrate = val;
	end
	);
	gconfig_listen("meta_lock", "dispatch.lua",
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

	for _, v in ipairs(match_keys("custom_%")) do
		local pos, stop = string.find(v, "=", 1);
		if (pos and stop) then
			local key = string.sub(v, 8, pos - 1);
			local val = string.sub(v, stop + 1);
			if (val and string.len(val) > 0) then
				tbl[key] = val;
			end
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

function dispatch_meta()
	return mtrack.m1 ~= nil, mtrack.m2 ~= nil;
end

function dispatch_set(key, path)
	store_key("custom_" ..key, path);
	tbl[key] = path;
end

function dispatch_meta_reset(m1, m2)
	update_meta(m1 and CLOCK or nil, m2 and CLOCK or nil);
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
	local m1, m2 = dispatch_meta();
	ledm_kbd_state(m1, m2, mtrack.ignore);
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
		update_meta(m1, mtrack.m2);
		if (m1d and mtrack.mlock == "m1") then
			if (m1d - mtrack.last_m1 <= mtrack.dblrate) then
				dispatch_toggle();
			end
			mtrack.last_m1 = m1d;
		end
	elseif (keysym == SYSTEM_KEYS["meta_2"]) then
		local m2, m2d = metatrack(mtrack.m2, mtrack.last_m2);
		update_meta(mtrack.m1, m2);
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
local deferred_id = 0;

function dispatch_repeatblock(iotbl)
	if (iotbl.translated) then
		sym, outsym = SYMTABLE:patch(iotbl);
		return (sym == SYSTEM_KEYS["meta_1"] or sym == SYSTEM_KEYS["meta_2"]);
	end
	return false;
end

-- sym contains multiple symbols embedded, with linefeed as a separator
local function dispatch_multi(sym, arg, ext)
	local last_i = 2;
	local len = string.len(sym, arg, ext);
	for i=2,len do
		if ((string.sub(sym, i, i) == '\n' or i == len) and
			i ~= last_i) then
			dispatch_symbol(string.sub(sym, last_i, i), arg, ext);
			last_i = i;
		end
	end
end

local dispatch_locked = nil;
local dispatch_queue = {};

-- take the list of accumulated symbols to dispatch and push them out now,
-- note that this can trigger another dispatch_symbol_lock and so on..
function dispatch_symbol_unlock(flush)
	assert(dispatch_locked == true);
	dispatch_locked = nil;
end

function dispatch_symbol_lock()
	assert(dispatch_locked == nil);
	dispatch_locked = true;
	dispatch_queue = {};
end

-- Setup menu navigation (interactively) in a way that we can hook rather
-- than activated a selected path or even path/key=value. There is a special
-- case for a tiler where the lbar is currently active (timers) as we want
-- to wait after the current one has been destroyed or the hook will fire
-- erroneously.
function dispatch_symbol_bind(callback, path)
	local menu = menu_resolve(path and path or "/");
	menu_hook_launch(callback);
	menu_launch(active_display(),
		{list = menu, show_invisible = true}, {}, "/", menu_default_lookup(menu));
end

-- placeholder, just to annotate code, only works with the global due to
-- problems with the menu system design, active_display()
function dispatch_symbol_wnd(sym, wnd)
-- cheat-set selection status on the active display, things to consider:
	dispatch_symbol(sym);
end

function dispatch_symbol(sym, menu_opts)
-- note, it's up to us to forward the argument for validator before exec
	local menu, msg, val, enttbl = menu_resolve(sym);
	if (DEBUGLEVEL > 1) then
		print("dispatch_symbol", sym, msg, val, debug.traceback());
	end

-- catch all the 'value path returned', submenu returned, ...
	if (not menu or menu.validator and not menu.validator(val)) then
		return false;
	end

-- just queue if locked
	if (dispatch_locked) then
		table.insert(dispatch_queue, {menu, msg, val});
		return true;
	end

-- shortpath the common case
	if (menu.handler and not menu.submenu) then
		menu:handler(val);
		return true;
	end

-- actual menu returned, need to spawn
	if (type(menu[1]) == "table") then
		menu_launch(active_display(),
			{list = menu}, menu_opts, sym, menu_default_lookup(enttbl));
	else
-- actually broken result
		return false;
	end

	return true;
end

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

-- just perform the translation?
	if (ok or nodispatch) then
		return true, lutsym, iotbl, tbl[lutsym];
	end

-- we can have special bindings on a per window basis
	if (sel and sel.bindings and sel.bindings[lutsym]) then
		if (iotbl.active) then
			if (type(sel.bindings[lutsym]) == "function") then
				sel.bindings[lutsym](sel);
			else
				dispatch_symbol(sel.bindings[lutsym]);
			end
		end

-- don't want to run repeat for valid bindings
		iostatem_reset_repeat();
		return true, lutsym, iotbl;
	end

	local rlut = "f_" ..lutsym;
	if (tbl[lutsym] or (not iotbl.active and tbl[rlut])) then
		if (iotbl.active and tbl[lutsym]) then
			dispatch_symbol(tbl[lutsym]);
			if (tbl[rlut]) then
				last_deferred = tbl[rlut];
				deferred_id = iotbl.devid;
			end

		elseif (tbl[rlut]) then
			dispatch_symbol(tbl[rlut]);
			last_deferred = nil;
		end

-- don't want to run repeat for valid bindings
		iostatem_reset_repeat();
		return true, lutsym, iotbl;
	elseif (last_deferred and iotbl.devid == deferred_id) then
		dispatch_symbol(last_deferred);
		last_deferred = nil;
		return true, lutsym, iotbl;
	elseif (not sel) then
		return false, lutsym, iotbl;
	end

-- or an input handler unique for the window
	if (not iotbl.analog and sel.key_input) then
		sel:key_input(outsym, iotbl);
		ok = true;
	else

-- for label bindings, we go with the prefixed view of modifiers
		if (sel.labels and sel.labels[outsym]) then
			iotbl.label = sel.labels[outsym];
		end
	end

	return ok, outsym, iotbl;
end

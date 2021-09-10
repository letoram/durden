local function gen_mbutton_menu()
	local res = {};
	for i=1,7 do
		table.insert(res, {
			name = tostring(i),
			kind = "action",
			description = "Simulate clicking button " .. tostring(i),
			label = MOUSE_LABELLUT[i] and MOUSE_LABELLUT[i] or tostring(i),
			handler = function()
				mouse_button_input(i, true);
				mouse_button_input(i, false);
			end
		});
	end
	return res;
end

local function gen_mbounce_menu()
	local res = {};
	for i=1,7 do
		table.insert(res, {
			name = tostring(i),
			kind = "value",
			description = "Change debounce- timing for button " .. tostring(i),
			label = MOUSE_LABELLUT[i] and MOUSE_LABELLUT[i] or tostring(i),
			hint = string.format("(%d Hz ticks, 0: disable)", CLOCKRATE),
			initial = tostring(mouse_state().btns_bounce[i]),
			validator = gen_valid_num(0, 100),
			handler = function(ctx, val)
				gconfig_set("mouse_debounce_" .. tostring(i), tonumber(val));
				mouse_state().btns_bounce[i] = tonumber(val);
			end
		});
	end
	return res;
end

local
scroll_menu = {
	{
		name = "analog_vertical",
		kind = "value",
		label = "Analog-Vertical",
		validator = gen_valid_num(-100, 100),
		handler = function(ctx, val)
			local wnd = active_display().selected;
			if not wnd or not wnd.scroll then
				return;
			end
			wnd:scroll(0, tonumber(val));
		end,
	},
	{
		name = "analog_horizontal",
		kind = "value",
		label = "Analog-Horizontal",
		validator = gen_valid_num(-100, 100),
		handler = function(ctx, val)
			local wnd = active_display().selected;
			if not wnd or not wnd.scroll then
				return;
			end
			wnd:scroll(tonumber(val), 0);
		end
	}
};

local remap_menu = {
	{
		name = "remap_123",
		kind = "action",
		description = "Default mouse button order",
		label = "Left(1),Middle(2),Right(3)",
		handler = function()
			local mstate = mouse_state();
			mstate.btns_remap[1] = 1;
			mstate.btns_remap[2] = 2;
			mstate.btns_remap[3] = 3;
		end
	},
	{
		name = "remap_321",
		kind = "action",
		description = "Left-handed mouse button order",
		label = "Right(1),Middle(2),Left(3)",
		handler = function()
			local mstate = mouse_state();
			mstate.btns_remap[1] = 3;
			mstate.btns_remap[2] = 2;
			mstate.btns_remap[3] = 1;
		end
	},
	{
		name = "remap_132",
		kind = "action",
		description = "Middle-right swap button order",
		label = "Left(1),Right(2),Middle(3)",
		handler = function()
			local mstate = mouse_state();
			mstate.btns_remap[1] = 1;
			mstate.btns_remap[2] = 3;
			mstate.btns_remap[3] = 2;
		end
	}
};

local mouse_menu = {
	{
		name = "scale",
		kind = "value",
		label = "Sensitivity",
		description = "Change uniform mouse input sample scale factor",
		hint = function() return "(0.01..10)"; end,
		eval = function() return not mouse_blocked(); end,
		validator = gen_valid_num(0, 10),
		initial = function()
			return tostring(gconfig_get("mouse_factor"));
		end,
		handler = function(ctx, val)
			val = tonumber(val);
			val = val < 0.01 and 0.01 or val;
			gconfig_set("mouse_factor", val);
			mouse_acceleration(val, val);
		end
	},
	{
		name = "dblclick",
		kind = "value",
		label = "Double-Click",
		description = "Change the double-click mouse timing sensitivity",
		eval = function() return not mouse_blocked(); end,
		hint = function() return "(deadline for double click)"; end,
		validator = gen_valid_num(5, 100),
		initial = function()
			return tostring(gconfig_get("mouse_dblclick"));
		end,
		handler = function(ctx, val)
			gconfig_set("mouse_dblclick", tonumber(val));
		end
	},
	{
		name = "hover",
		kind = "value",
		label = "Hover Delay",
		description = "Change the mouse hover timing sensitivity",
		eval = function() return not mouse_blocked(); end,
		hint = function() return "10..80"; end,
		validator = gen_valid_num(0, 80),
		initial = function()
			return tostring(gconfig_get("mouse_hovertime"));
		end,
		handler = function(ctx, val)
			val = math.ceil(tonumber(val));
			val = val < 10 and 10 or val;
			gconfig_set("mouse_hovertime", val);
			mouse_state().hover_ticks = val;
		end
	},
	{
		name = "button",
		label = "Button",
		description = "Simulate a single mouse button click",
		eval = function() return not mouse_blocked(); end,
		submenu = true,
		kind = "action",
		handler = gen_mbutton_menu,
	},
	{
		name = "ping",
		label = "Ping",
		description = "Trigger the mouse reveal animation",
		kind = "action",
		handler = function()
			local hook = mouse_state().reveal_hook;
			if hook then
				hook();
			end
		end
	},
	{
		name = "debounce",
		label = "Debounce",
		description = "Configure mouse button 'debouncing' (accidental clicks)",
		eval = function() return not mouse_blocked(); end,
		submenu = true,
		kind = "action",
		handler = gen_mbounce_menu
	},
	{
		name = "reorder",
		label = "Reorder",
		description = "Configure mouse button order",
		eval = function() return not mouse_blocked(); end,
		submenu = true,
		kind = "action",
		handler = remap_menu
	},
	{
		name = "scroll",
		kind = "action",
		label = "Scrolling",
		description = "Synthesize smooth (analog) scrolling values",
		submenu = true,
		handler = scroll_menu
	},
	{
		name = "save_pos",
		kind = "value",
		label = "Remember Position",
		description = "Track/Warp mouse position when keyboard-switching window focus",
		set = {LBL_YES, LBL_NO, LBL_FLIP},
		eval = function() return not mouse_blocked(); end,
		initial = function()
			return gconfig_get("mouse_remember_position") and LBL_YES or LBL_NO;
		end,
		handler = suppl_flip_handler("mouse_remember_position")
	},
	{
		name = "hide",
		kind = "value",
		label = "Autohide",
		description = "Set mouse audio-hiding on inactivity behavior",
		set = {LBL_YES, LBL_NO, LBL_FLIP},
		eval = function() return not mouse_blocked(); end,
		initial = function()
			return gconfig_get("mouse_autohide") and LBL_YES or LBL_NO;
		end,
		handler = function(ctx, val)
			if (val == LBL_FLIP) then
				val = not gconfig_get("mouse_autohide");
			else
				val = val == LBL_YES;
			end
			gconfig_set("mouse_autohide", val);
			mouse_state().autohide = val;
		end
	},
	{
		name = "reveal",
		kind = "value",
		label = "Reveal/Hide",
		description = "Control the visual effect used when mouse goes from hidden to visible",
		set = {LBL_YES, LBL_NO, LBL_FLIP},
		eval = function() return not mouse_blocked(); end,
		initial = function()
			return gconfig_get("mouse_reveal") and LBL_YES or LBL_NO;
		end,
		handler = function(ctx, val)
			if (val == LBL_FLIP) then
				val = not gconfig_get("mouse_reveal");
			else
				val = val == LBL_YES;
			end
			gconfig_set("mouse_reveal", val);
			mouse_reveal_hook(val);
		end
	},
	{
		name = "coalesce",
		kind = "value",
		label = "Coalesce",
		description = "Merge all mouse- capable devices into one abstract mouse1_ device",
		set = {LBL_YES, LBL_NO, LBL_FLIP},
		eval = function() return not mouse_blocked(); end,
		initial = function()
			return gconfig_get("mouse_coalesce") and LBL_YES or LBL_NO;
		end,
		handler = function(ctx, val)
			if (val == LBL_FLIP) then
				val = not gconfig_get("mouse_coalesce");
			else
				val = val == LBL_YES;
			end
			gconfig_set("mouse_coalesce", val);
		end,
	},
	{
		name = "lock",
		kind = "value",
		label = "Hard Lock",
		set = {LBL_YES, LBL_NO, LBL_FLIP},
		description = "Hard- lock/grab the mouse pointer (on supported platforms)",
		eval = function() return not mouse_blocked(); end,
		initial = function()
			return gconfig_get("mouse_hardlock") and LBL_YES or LBL_NO;
		end,
		handler = function(ctx, val)
			if (val == LBL_FLIP) then
				val = not gconfig_get("mouse_hardlock");
			else
				val = val == LBL_YES;
			end
			gconfig_set("mouse_hardlock", val);
			toggle_mouse_grab(val and MOUSE_GRABON or MOUSE_GRABOFF);
		end
	},
	{
		name = "hide_delay",
		kind = "value",
		label = "Autohide Delay",
		description = "Change the minimum delay before the inactive-hide state is triggered",
		eval = function() return not mouse_blocked(); end,
		hint = function() return "40..400"; end,
		validator = gen_valid_num(0, 400),
		initial = function()
			return tostring(gconfig_get("mouse_hidetime"));
		end,
		handler = function(ctx, val)
			val = math.ceil(tonumber(val));
			val = val < 40 and 40 or val;
			gconfig_set("mouse_hidetime", val);
			mouse_state().hide_base = val;
		end
	},
	{
		name = "focus",
		kind = "value",
		label = "Focus Event",
		description = "Change the mouse action needed to select/focus a window",
		eval = function() return not mouse_blocked(); end,
		set = {"click", "motion", "hover", "none"},
		initial = function()
			return gconfig_get("mouse_focus_event");
		end,
		handler = function(ctx, val)
			gconfig_set("mouse_focus_event", val);
		end
	},
	{
		name = "block",
		kind = "value",
		label = "Block",
		set = {LBL_YES, LBL_NO, LBL_FLIP},
		description = "Block all mouse processing",
		initial = function()
			return gconfig_get("mouse_block") and LBL_YES or LBL_NO;
		end,
		handler = function(ctx, val)
			if (val == LBL_FLIP) then
				val = not gconfig_get("mouse_block");
			else
				val = val == LBL_YES;
			end
			gconfig_set("mouse_block", val);
			if (val) then
				mouse_block();
			else
				mouse_unblock();
			end
		end
	},
};
local function list_keymaps()
	local km = SYMTABLE:list_keymaps();
	local kmm = {};
	for k,v in ipairs(km) do
		table.insert(kmm, {
			name = "map_" .. tostring(k),
			kind = "action",
			label = v,
			description = "Activate keyboard map: " .. v,
			handler = function() SYMTABLE:load_keymap(v .. ".lua"); end
		});
	end
	return kmm;
end

local function bind_utf8()
	suppl_bind_u8(function(sym, val, sym2, iotbl)
		SYMTABLE:update_map(iotbl, val);
	end);
end

local function gen_axismenu(devid, subid, pref)
	return {};
end

local function gen_analogmenu(v, pref)
	local res = {};
	local state = inputanalog_query(v.devid, 100);

	local i = 0;
	while (true) do
		local state = inputanalog_query(v.devid, i);
		if (not state.subid) then
			break;
		end

-- this can be very exhausting for a device that exposes many axes, but we have
-- no mechanism for identifying or labeling these in any relevant layer. The
-- fallback would be a database, but that's quite a bad solution. Indeed, this
-- interface should only really be used for binding specific settings in edge
-- cases that require it, but this is really a problem that calls for a
-- 'analog- monitor-UI' where we map samples arriving, allowing pick/drag to
-- change values
		table.insert(res, {
			label = tostring(i),
			name = pref .. "_ax_" .. tostring(i),
			kind = "action",
			submenu = true,
			eval = function() return false; end,
			handler = function() return gen_axismenu(v, pref); end
		});
		i = i + 1;
	end

	return res;
end

local function gen_bmenu(v, pref)
	local res = {
		{
			label = "UTF-8",
			name = pref .. "UTF-8",
			kind = "action",
			handler = function()
-- launch filtered bind, set iostatem_ translate emit
			end
		}
	};
	return res;
end

local function gen_smenu(v, pref)
	return
		{
			label = "Slot",
			name = pref .. "slotv",
			kind = "value",
			hint = "index (1..10, 0 disable)",
			description = "Set the game input device slot this device should use",
			validator = gen_valid_num(1, 8),
			initial = tostring(v.slot),
			handler = function(ctx, val)
				v.slot = tonumber(val);
			end
		};
end

local function dev_menu(v)
	local pref = string.format("dev_%d_", v.devid);
	local res = {
		{
			name = pref .. "bind",
			label = "Bind",
			description = "Bind device-specific button or axis",
			handler = function() return gen_bmenu(v, pref .. "_bind"); end,
			kind = "action",
			submenu = true
		},
		{
			name = pref .. "always_on",
			label = "Always On",
			kind = "value",
			description = "Always process input device analog samples",
			set = {LBL_YES, LBL_NO, LBL_FLIP},
			eval = false,
			initial = function()
				return v.force_analog and LBL_YES or LBL_NO;
			end,
		},
		{
			name = pref .. "forget",
			label = "Forget",
			description = "Release the device and its resources",
			kind = "value",
			set = {LBL_YES, LBL_NO},
			handler = function(ctx, val)
				if val == LBL_YES then
					inputanalog_filter(v.devid, 0, 0, 0, 0, 0, "forget")
				end
			end,
		},
		gen_smenu(v, pref)
	};
	local state = inputanalog_query(v.devid);

-- might have disappeared while waiting
	if (not state) then
		return;
	else
		table.insert(res, {
			name = pref .. "analog",
			label = "Analog",
			submenu = true,
			kind = "action",
			description = "Change analog axis calibration and mapping",
			eval = function() return #gen_analogmenu(v, pref) > 0; end,
			handler = function()
				return gen_analogmenu(v, pref .. "alog_");
			end
		});
	end

	return res;
end

local function gen_devmenu(slotted)
	local res = {};
	for k,v in iostatem_devices(slotted) do
		table.insert(res, {
			name = string.format("dev_%d_main", v.devid),
			label = v.label,
			kind = "action",
			description = "Custom binding, mapping and calibration of " .. v.label,
			hint = string.format("(id %d, slot %d)", v.devid, v.slot),
			submenu = true,
			handler = function() return dev_menu(v); end
		});
	end
	return res;
end

local function keymap_actions(id, verb, ...)
	local ok = false
	repeat
		ok = input_remap_translation(id, verb, ...)
		id = id - 1
	until id >= -1 or not ok
end

local devid_opts = {}
local function ensure_set(devid, ind, val)
	val = val and val or "";
	if not devid_opts[devid] then
		devid_opts[devid] = {"", "", "", ""}; -- layout, model, variant, options
	end
	devid_opts[devid][ind] = val;
end

local function get_keymap_menu(devid)
	return {
	{
		name = "reset",
		label = "Reset",
		kind = "action",
		description = "Reset keyboard translation options to platform default",
		handler = function()
			keymap_actions(devid, TRANSLATION_CLEAR)
		end,
	},
	{
		name = "layout",
		label = "Layout",
		kind = "value",
		initial = function()
			return devid_opts[devid] and devid_opts[devid][1] or "";
		end,
		description = "Change the set of mapped keyboard layouts",
		hint = "(, separate: us,cz,de)",
		handler = function(ctx, val)
			ensure_set(devid, 1, val);
			keymap_actions(devid, TRANSLATION_SET, unpack(devid_opts[devid]));
		end,
	},
	{
		name = "model",
		label = "Model",
		kind = "value",
		description = "Change the active keyboard model",
		hint = "(pc104)",
		initial = function()
			return devid_opts[devid] and devid_opts[devid][2] or "";
		end,
		handler = function(ctx, val)
			ensure_set(devid, 2, val);
			keymap_actions(devid, TRANSLATION_SET, unpack(devid_opts[devid]));
		end
	},
	{
		name = "variant",
		label = "Variant",
		kind = "value",
		description = "Change the active keyboard variant",
		hint = "(basic)",
		initial = function()
			return devid_opts[devid] and devid_opts[devid][3] or "";
		end,
		handler = function(ctx, val)
			ensure_set(devid, 3, val);
			keymap_actions(devid, EVENT_TRANSLATION_SET, unpack(devid_opts[devid]));
		end
	},
	{
		name = "options",
		label = "Options",
		kind = "value",
		description = "Set keyboard layout options",
		hint = "(grp:alt_shift_toggle)",
		initial = function()
			return devid_opts[devid] and devid_opts[devid][4] or "";
		end,
		handler = function(ctx, val)
			ensure_set(devid, 4, val);
			keymap_actions(devid, TRANSLATION_SET, unpack(devid_opts[devid]));
		end
	},
	}
end

local keymaps_menu = {
	{
		name = "bind_utf8",
		label = "Bind UTF-8",
		kind = "action",
		description = "Associate a keyboard key with a UTF-8 defined unicode codepoint",
		external_block = true,
		handler = bind_utf8,
	},
	{
		name = "platform",
		label = "Platform",
		kind = "action",
		description = "Override current evdev input platform keymap for all keyboards",
		submenu = true,
		eval = function()
			return string.match(API_ENGINE_BUILD, "evdev") and input_remap_translation ~= nil;
		end,
		handler = get_keymap_menu(-1)
	},
	{
		name = "bind_sym",
		label = "Bind Keysym",
		kind = "value",
		description = "Associate a keyboard key with a symbolic name",
		set = function()
			local res = {};
			for k,v in pairs(SYMTABLE) do
				if (type(k) == "number") then
					table.insert(res, v);
				end
			end
			return res;
		end,
		external_block = true,
		handler = function(ctx, val)
			local bwt = gconfig_get("bind_waittime");
			local bb = tiler_bbar(active_display(),
				string.format(LBL_BIND_KEYSYM, val, SYSTEM_KEYS["cancel"]),
				true, bwt, nil, SYSTEM_KEYS["cancel"],
				function(sym, done, sym2, iotbl)
					if (done and iotbl.number) then
						SYMTABLE.symlut[iotbl.number] = val;
					end
				end);
		end
	},
	{
		name = "switch",
		label = "Load",
		description = "Switch the currently active keyboard map",
		kind = "action",
		eval = function() return #(SYMTABLE:list_keymaps()) > 0; end,
		handler = list_keymaps,
		submenu = true
	},
	{
		name = "save",
		label = "Save",
		kind = "value",
		description = "Save the currently active keyboard map under a new name",
		validator = function(val) return val and string.len(val) > 0 and
			not resource("devmaps/keyboard/" .. val .. ".lua", SYMTABLE_DOMAIN); end,
		handler = function(ctx, val)
			SYMTABLE:save_keymap(val);
		end
	},
	{
		name = "replace",
		label = "Replace",
		kind = "value",
		description = "Update the on-disk store of the active keyboard map",
		set = function() return SYMTABLE:list_keymaps(true); end,
		handler = function(ctx, val)
			SYMTABLE:save_keymap(val);
		end
	}
};

local keyb_menu = {
	{
		name = "repeat",
		label = "Repeat Period",
		kind = "value",
		initial = function() return tostring(gconfig_get("kbd_period")); end,
		hint = "ticks/cycle (0:disabled - 50)",
		description = "Change how quickly a keypress is repeated (for new windows)",
		validator = gen_valid_num(0, 100),
		handler = function(ctx, val)
			val = tonumber(val);
			gconfig_set("kbd_period", val);
			iostatem_repeat(val);
		end
	},
	{
		name = "delay",
		label = "Initial Delay",
		kind = "value",
		initial = function()
			return tostring(gconfig_get("kbd_delay"));
		end,
		hint = "ms (0:disable - 1000)",
		description = "Change how long time need to elapse before repeating starts (for new windows)",
		handler = function(ctx, val)
			val = tonumber(val);
			gconfig_set("kbd_delay", val);
			iostatem_repeat(nil, val);
		end
	},
	{
		name = "mlock",
		label = "Lock Toggle",
		set = {"Meta-1 doubletap", "Meta-2 doubletap", "None"},
		kind = "value",
		description = "Change the gesture used to toggle the locked/raw-input mode",
		initial = function() return gconfig_get("meta_lock"); end,
		handler = function(ctx, val)
			if (val == "Meta-1 doubletap") then
				val = "m1";
			elseif (val == "Meta-2 doubletap") then
				val = "m2";
			else
				val = "none";
			end
			gconfig_set("meta_lock", val);
		end,
	},
	{
		name = "pressrate",
		label = "Lock Timing",
		hint = "ticks between releases for doubletap",
		kind = "value",
		description = "Change the keyboard double-tap gesture timeout",
		initial = function() return tostring(gconfig_get("meta_dbltime")); end,
		validator = gen_valid_num(4, 100),
		handler = function(ctx, val)
			gconfig_set("meta_dbltime", tonumber(val));
		end
	},
	{
		name = "sticky",
		label = "Sticky Meta",
		kind = "value",
		hint = "release-delay (0: disable)",
		validator = gen_valid_num(0, 100),
		description = "(Accessibility) Hold meta- keypresses for a certain time",
		initial = function() return tostring(gconfig_get("meta_stick_time")); end,
		handler = function(ctx, val)
			gconfig_set("meta_stick_time", tonumber(val));
		end
	},
	{
		name = "meta_guard",
		label = "Meta Guard",
		kind = "value",
		description = "Enable / Disable the meta-guard on device-lost feature",
		set = {LBL_YES, LBL_NO, LBL_FLIP},
		initial = function()
			return gconfig_get("meta_guard") and LBL_YES or LBL_NO;
		end,
		handler = suppl_flip_handler("meta_guard")
	},
	{
		name = "maps",
		label = "Maps",
		kind = "action",
		submenu = true,
		description = "Keyboard map controls",
		handler = keymaps_menu
	},
	{
		name = "reset",
		label = "Reset",
		kind = "action",
		description = "Reset the current keyboard translation tables",
		handler = function() SYMTABLE:reset(); end
	}
};

local function rebind_meta()
	local bwt = gconfig_get("bind_waittime");

-- wm, msg, key, time, 'ok', 'cancel', callback, rpress
	local bb = tiler_bbar(active_display(),
		string.format("Press and hold (Meta 1), %s to Abort",
			SYSTEM_KEYS["cancel"]), true, bwt, nil, SYSTEM_KEYS["cancel"],
		function(sym, done)
			if (done) then
				local bb2 = tiler_bbar(active_display(),
					string.format("Press and hold (Meta 2), %s to Abort",
					SYSTEM_KEYS["cancel"]), true, bwt, nil, SYSTEM_KEYS["cancel"],
					function(sym2, done)
						if (done) then
							active_display():message(
								string.format("Meta 1,2 set to %s, %s", sym, sym2));
							dispatch_system("meta_1", sym);
							dispatch_system("meta_2", sym2);
							meta_guard_reset();
							suppl_binding_queue(false);
						end
						if (sym2 == sym) then
							return "Already bound to Meta 1";
						end
				end);
				bb2.on_cancel = function() suppl_binding_queue(true); end
			end
		end, 5
	);

	bb.on_cancel = function() suppl_binding_queue(true); end
end

--
-- quite complicated, chain a binding bar one after the other until we run
-- out of entries - when that happens, request the next in the binding queue.
--
local function rebind_basic()
	local tbl = {
		{"Accept", "accept"},
		{"Cancel", "cancel"},
		{"Next", "next"},
		{"Previous", "previous"},
		{"Home", "home"},
		{"End", "end"},
		{"Left", "left"},
		{"Right", "right"},
		{"Erase", "erase"},
		{"Delete", "delete"}
	};

	local used = {};

	local runsym = function(self)
		local ent = table.remove(tbl, 1);
		if (ent == nil) then
			suppl_binding_queue(false);
			return;
		end
		local bb = tiler_bbar(active_display(),
			string.format("Bind %s, press current: %s or hold new to rebind.",
				ent[1], SYSTEM_KEYS[ent[2]]), true, gconfig_get("bind_waittime"),
				SYSTEM_KEYS[ent[2]], nil,
				function(sym, done)
					if (done) then
						dispatch_system(ent[2], sym);
						table.insert(used, {sym, ent[2]});
						self(self);
					else
						for k,v in ipairs(used) do
							if (v[1] == sym) then
								return "Already bound to " .. v[2];
							end
						end
					end
				end
		);
		bb.on_cancel = function() suppl_binding_queue(true); end
	end

	runsym(runsym);
end

local function bind_path(path, msg)
	return function()
		local bh = function(sym, helper)
			dispatch_set(sym, path);
			suppl_binding_queue(false);
		end

		local ctx =
			suppl_binding_helper("", "", function() end);

-- need to reset the queue on cancel
		ctx.on_cancel = function()
			suppl_binding_queue(true);
		end

-- override the callback so the dispatch_symbol_bind function won't trigger
		ctx.cb = function(sym, done)
			if (not done) then
				return;
			end
			bh(sym);
		end
	end
end

-- reduced version of durden input that only uses dispatch_lookup to
-- figure out of we are running a symbol that maps to input_lock_* functions
local input_lock_toggle;
local input_lock_on;
local inputlock_off;
local ign_input = function(iotbl)
	local ok, sym, outsym, lutval = dispatch_translate(iotbl, true);
	if (iotbl.kind == "status") then
		durden_iostatus_handler(iotbl);
		return;
	end

	if (iotbl.active and lutval) then
		paths = {
			["/global/input/toggle"] = input_lock_toggle,
			["/global/input/on"] = input_lock_on,
			["/global/input/off"] = input_lock_off
		};
		if (paths[lutval]) then
			paths[lutval]();
		end
	end
end

input_lock_toggle = function()
	if (durden_input == ign_input) then
		input_lock_off();
	else
		input_lock_on();
	end
end

local iolog = suppl_add_logfn("idevice");

input_lock_on = function()
	durden_input_sethandler(function() end, "global/input/lock");
	dispatch_meta_reset();
	iostatem_save();
	iostatem_repeat(0, 0);
	active_display():message("Ignore input enabled");
end

input_lock_off = function()
	dispatch_meta_reset();
	iostatem_restore(iostate);
	dispatch_meta_reset();
	durden_input_sethandler()
	active_display():message("Ignore input disabled");
end

-- these are all really complex as we need to both query for the binding
-- itself, then navigate the related menus without them triggering widgets
-- or other special menu hooks or paths
local bind_menu = {
	{
		name = "custom",
		kind = "action",
		label = "Custom",
		description = "Bind a menu path to a meta+button press combination",
-- use m1 to determine if we bind the path or the value=
		external_block = true,
		handler = function()
			suppl_binding_helper("", "", dispatch_set);
		end
	},
	{
		name = "custom_falling",
		kind = "action",
		label = "Custom(Release)",
		description = "Bind a menu path to a meta+button release combination",
		external_block = true,
		handler = function()
			suppl_binding_helper("f_", "", dispatch_set);
		end
	},
	{
		name = "unbind",
		kind = "value",
		label = "Unbind",
		set = function()
			local lst = match_keys("custom_%");
			local res = {};
			for _,str in ipairs(lst) do
				local pos, stop = string.find(str, "=", 1);
				local key = string.sub(str, 8, pos - 1);
				table.insert(res, key);
			end
			return res;
		end,
		eval = function()
			local lst = match_keys("custom_%");
			return #lst > 0;
		end,
		description = "Unset a previous custom binding",
		handler = function(ctx, val)
			dispatch_set(val, "");
		end
	},
	{
		name = "meta",
		kind = "action",
		label = "Meta",
		description = "Query for new meta keys",
		external_block = true,
		handler = rebind_meta
	},
	{
		name = "basic",
		kind = "action",
		label = "Basic",
		description = "Rebind the basic navigation keys",
		external_block = true,
		handler = rebind_basic
	},
	{
		name = "menu",
		kind = "action",
		label = "Menu",
		external_block = true,
		description = "Query for the global menu keybinding",
		handler = bind_path("/global")
	},
	{
		name = "target_menu",
		kind = "action",
		label = "Target Menu",
		external_block = true,
		description = "Query for the global menu keybinding",
		handler = bind_path("/target")
	}
};

return {
	{
		name = "bind",
		kind = "action",
		label = "Bind",
		submenu = true,
		description = "Manage bindings",
		handler = bind_menu
	},
	{
		name = "keyboard",
		kind = "action",
		label = "Keyboard",
		submenu = true,
		description = "Keyboard specific settings",
		handler = keyb_menu
	},
	{
		name = "mouse",
		kind = "action",
		label = "Mouse",
		submenu = true,
		description = "Mouse specific settings",
		handler = mouse_menu
	},
	{
		name = "slotted",
		kind = "action",
		label = "Slotted Devices",
		submenu = true,
		description = "Device to Game input mapping",
		eval = function()
			return #gen_devmenu(true) > 0;
		end,
		handler = function()
			return gen_devmenu(true);
		end
	},
	{
		name = "alldev",
		kind = "action",
		label = "All Devices",
		submenu = true,
		description = "Configuration for all known input devices",
		eval = function()
			return #gen_devmenu() > 0;
		end,
		handler = function()
			return gen_devmenu();
		end
	},
	{
		name = "rescan",
		kind = "action",
		label = "Rescan",
		description = "Issue an asynchronous device rescan (platform specific)",
		handler = function()
-- sideeffect, actually rescans on some platforms
			inputanalog_query(nil, nil, true);
		end
	},
-- don't want this visible as accidental trigger would lock you out
	{
		name = "toggle",
		kind = "action",
		label = "Toggle Lock",
		description = "Bind to toggle all input processing on/off",
		handler = input_lock_toggle,
		invisible = true
	},
	{
		name = "off",
		kind = "action",
		label = "Disable Input",
		description = "Disable all input processing",
		handler = input_lock_on,
		invisible = true
	},
	{
		name = "on",
		kind = "action",
		label = "Enable Input",
		description = "Enable input processing",
		handler = input_lock_off,
		invisible = true
	},
	{
		name = "idle",
		kind = "value",
		label = "Idle Threshold",
		initial = function()
			local num = gconfig_get("idle_threshold");
			return tostring(math.floor(1000 / CLOCKRATE * num));
		end,
		validator = gen_valid_num(0, 10000),
		hint = "(0: disabled, n: seconds)",
		description = "Change the amount of seconds of inactivity before a device is considered 'idle'",
		handler = function(ctx, val)
			gconfig_set("idle_threshold", math.floor(1000 / CLOCKRATE * tonumber(val)));
		end
	}
};

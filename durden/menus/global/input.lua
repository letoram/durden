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
	},
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
		name = "save_pos",
		kind = "value",
		label = "Remember Position",
		description = "Track/Warp mouse position when keyboard-switching window focus",
		set = {LBL_YES, LBL_NO},
		eval = function() return not mouse_blocked(); end,
		initial = function()
			return gconfig_get("mouse_remember_position") and LBL_YES or LBL_NO;
		end,
		handler = function(ctx, val)
			gconfig_set("mouse_remember_position", val == LBL_YES);
			mouse_state().autohide = val == LBL_YES;
		end
	},
	{
		name = "hide",
		kind = "value",
		label = "Autohide",
		description = "Set mouse audio-hiding on inactivity behavior",
		set = {LBL_YES, LBL_NO},
		eval = function() return not mouse_blocked(); end,
		initial = function()
			return gconfig_get("mouse_autohide") and LBL_YES or LBL_NO;
		end,
		handler = function(ctx, val)
			gconfig_set("mouse_autohide", val == LBL_YES);
			mouse_state().autohide = val == LBL_YES;
		end
	},
	{
		name = "reveal",
		kind = "value",
		label = "Reveal/Hide",
		description = "Control the visual effect used when mouse goes from hidden to visible",
		set = {LBL_YES, LBL_NO},
		eval = function() return not mouse_blocked(); end,
		initial = function()
			return gconfig_get("mouse_reveal") and LBL_YES or LBL_NO;
		end,
		handler = function(ctx, val)
			gconfig_set("mouse_reveal", val == LBL_YES);
			mouse_reveal_hook(val == LBL_YES);
		end
	},
	{
		name = "lock",
		kind = "value",
		label = "Hard Lock",
		set = {LBL_YES, LBL_NO},
		description = "Hard- lock/grab the mouse pointer (on supported platforms)",
		eval = function() return not mouse_blocked(); end,
		initial = function()
			return gconfig_get("mouse_hardlock") and LBL_YES or LBL_NO;
		end,
		handler = function(ctx, val)
			gconfig_set("mouse_hardlock", val == LBL_YES);
			toggle_mouse_grab(val == LBL_YES and MOUSE_GRABON or MOUSE_GRABOFF);
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
		set = {LBL_YES, LBL_NO},
		description = "Block all mouse processing",
		initial = function()
			return gconfig_get("mouse_block") and LBL_YES or LBL_NO;
		end,
		handler = function(ctx, val)
			gconfig_set("mouse_block", val == LBL_YES);
			if (val == LBL_YES) then
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
	fglobal_bind_u8(function(sym, val, sym2, iotbl)
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
			label = "Global Action",
			name = pref .. "_global",
			kind = "action",
			handler = function()
-- launch filtered bind that resolves to dig_id_subid
			end
		},
		{
			label = "Target Action",
			name = pref .. "_target",
			kind = "action",
			handler = function()
-- launch filtered bind that resolves to dig_id_subid
			end
		},
		{
			label = "",
			name = pref .. "UTF-8",
			kind = "action",
			handler = function()
-- launch filtered bind, set iostatem_ translate emit
			end
		},
		{
			label = "",
			name = pref .. "Label",
			kind = "value",
			initial = "BUTTON1",
			validator = strict_fname_valid,
			handler = function(ctx, val)
-- launch filtered bind, set iostatem_ label
			end
		},
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
			set = {LBL_YES, LBL_NO},
			initial = function()
				return v.force_analog and LBL_YES or LBL_NO;
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

local keymaps_menu = {
	{
		name = "bind_utf8",
		label = "Bind UTF-8",
		kind = "action",
		description = "Associate a keyboard key with a UTF-8 defined unicode codepoint",
		handler = bind_utf8,
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
		handler = function(ctx, val)
			local bwt = gconfig_get("bind_waittime");
			tiler_bbar(active_display(),
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

local bind_menu = {
	{
		name = "custom",
		kind = "action",
		label = "Custom",
		description = "Bind a menu path to a meta+keypress",
		handler = grab_global_function("bind_custom")
	},
	{
		name = "custom_falling",
		kind = "action",
		label = "Custom(Release)",
		description = "Bind a menu path to a meta+keyrelease",
		handler = grab_global_function("bind_custom_falling")
	},
	{
		name = "unbind",
		kind = "action",
		label = "Unbind",
		description = "Unset a previous custom binding",
		handler = grab_global_function("unbind_combo")
	},
	{
		name = "meta",
		kind = "action",
		label = "Meta",
		description = "Query for new meta keys",
		handler = grab_global_function("rebind_meta")
	},
	{
		name = "basic",
		kind = "action",
		label = "Basic",
		description = "Rebind the basic navigation keys",
		handler = grab_global_function("rebind_basic")
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
		name = "input_toggle",
		kind = "action",
		label = "Toggle Lock",
		description = "Bind to toggle all input processing on/off",
		handler = grab_global_function("input_lock_toggle"),
		invisible = true
	}
};

local mouse_menu = {
	{
		name = "scale",
		kind = "value",
		label = "Sensitivity",
		hint = function() return "(0.01..10)"; end,
		validator = function(val)
			return gen_valid_num(0, 10)(val);
		end,
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
		name = "hover",
		kind = "value",
		label = "Hover Delay",
		hint = function() return "10..80"; end,
		validator = function(val)
			return gen_valid_num(0, 80)(val);
		end,
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
		name = "save_pos",
		kind = "value",
		label = "Remember Position",
		set = {LBL_YES, LBL_NO},
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
		set = {LBL_YES, LBL_NO},
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
		set = {LBL_YES, LBL_NO},
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
		hint = function() return "40..400"; end,
		validator = function(val)
			return gen_valid_num(0, 400)(val);
		end,
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
		set = {"click", "motion", "hover", "none"},
		initial = function()
			return gconfig_get("mouse_focus_event");
		end,
		handler = function(ctx, val)
			gconfig_set("mouse_focus_event", val);
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
			handler = function() SYMTABLE:load_keymap(v); end
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
		}
	};
end

local function gen_smenu(v, pref)
	return
		{
			label = "Slot",
			name = pref .. "slotv",
			kind = "value",
			hint = "index (1..10, 0 disable)",
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
			handler = function() return gen_bmenu(v, pref .. "_bind"); end,
			eval = function() return false; end,
			kind = "action",
			submenu = true
		},
		{
			name = pref .. "always_on",
			label = "Always On",
			kind = "value",
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
		handler = bind_utf8,
	},
	{
		name = "bind_sym",
		label = "Bind Keysym",
		kind = "value",
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
					if (done and iotbl.keysym) then
						SYMTABLE.symlut[iotbl.keysym] = val;
					end
				end);
		end
	},
	{
		name = "switch",
		label = "Load",
		kind = "action",
		eval = function() return #(SYMTABLE:list_keymaps()) > 0; end,
		handler = list_keymaps,
		submenu = true
	},
	{
		name = "save",
		label = "Save",
		kind = "value",
		validator = function(val) return val and string.len(val) > 0 and
			not resource("keymaps/" .. val .. ".lua", SYMTABLE_DOMAIN); end,
		handler = function(ctx, val)
			SYMTABLE:save_keymap(val);
		end
	},
	{
		name = "replace",
		label = "Replace",
		kind = "value",
		set = function() return SYMTABLE:list_keymaps(true); end,
		handler = function(ctx, val)
			SYMTABLE:save_keymap(val);
		end
	}
};

local keyb_menu = {
	{
		name = "keyboard_repeat",
		label = "Repeat Period",
		kind = "value",
		initial = function() return tostring(gconfig_get("kbd_period")); end,
		hint = "ticks/cycle (0:disabled - 50)",
		note = "sets as new default, applies to new windows",
		validator = gen_valid_num(0, 100);
		handler = function(ctx, val)
			val = tonumber(val);
			gconfig_set("kbd_period", val);
			iostatem_repeat(val);
		end
	},
	{
		name = "keyboard_delay",
		label = "Initial Delay",
		kind = "value",
		initial = function() return tostring(gconfig_get("kbd_delay")); end,
		hint = "milliseconds (0:disable - 1000)",
		note = "sets as new default, applies to new windows",
		handler = function(ctx, val)
			val = tonumber(val);
			gconfig_set("kbd_delay", val);
			iostatem_repeat(nil, val);
		end
	},
	{
		name = "keyboard_maps",
		label = "Maps",
		kind = "action",
		submenu = true,
		handler = keymaps_menu
	},
	{
		name = "keyboard_reset",
		label = "Reset",
		kind = "action",
		handler = function() SYMTABLE:reset(); end
	}
};

local bind_menu = {
	{
		name = "basic",
		kind = "action",
		label = "Basic",
		handler = grab_global_function("rebind_basic")
	},
	{
		name = "custom",
		kind = "action",
		label = "Custom",
		handler = grab_global_function("bind_custom")
	},
	{
		name = "meta",
		kind = "action",
		label = "Meta",
		handler = grab_global_function("rebind_meta")
	},
	{
		name = "unbind",
		kind = "action",
		label = "Unbind",
		handler = grab_global_function("unbind_combo")
	},
};

return {
	{
		name = "bind",
		kind = "action",
		label = "Bind",
		submenu = true,
		handler = bind_menu
	},
	{
		name = "keyboard",
		kind = "action",
		label = "Keyboard",
		submenu = true,
		handler = keyb_menu
	},
	{
		name = "mouse",
		kind = "action",
		label = "Mouse",
		submenu = true,
		handler = mouse_menu
	},
	{
		name = "slotted",
		kind = "action",
		label = "Slotted Devices",
		submenu = true,
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
		handler = grab_global_function("input_lock_toggle"),
		invisible = true
	}
};

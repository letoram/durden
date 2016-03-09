local mouse_menu = {
	{
		name = "mouse_sensitivity",
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
		name = "mouse_hover_delay",
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
		name = "mouse_remember_position",
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
		name = "mouse_autohide",
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
		name = "mouse_hardlock",
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
		name = "mouse_hide_delay",
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
		name = "mouse_focus",
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
			name = "keymap_" .. tostring(k),
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

local keymaps_menu = {
	{
		name = "keymap_switch",
		label = "Load",
		kind = "action",
		eval = function() return #(SYMTABLE:list_keymaps()) > 0; end,
		handler = list_keymaps,
		submenu = true
	},
	{
		name = "keymap_bind_utf8",
		label = "Bind UTF-8",
		kind = "action",
		handler = bind_utf8,
	},
	{
		name = "keymap_save",
		label = "Save",
		kind = "value",
		hint = "(name)",
		validator = function(val) return val and string.len(val) > 0; end,
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
		hint = "cps (0:disabled - 100)",
		validator = gen_valid_num(0, 100);
		handler = function(ctx, val)
			val = tonumber(val);
			gconfig_set("kbd_period", val);
			iostatem_repeat(val, nil);
		end
	},
	{
		name = "keyboard_delay",
		label = "Initial Delay",
		kind = "value",
		initial = function() return tostring(gconfig_get("kbd_delay")); end,
		hint = "ms (0:disable - 1000)",
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
		name = "input_rebind_basic",
		kind = "action",
		label = "Basic",
		handler = grab_global_function("rebind_basic")
	},
	{
		name = "input_rebind_custom",
		kind = "action",
		label = "Custom",
		handler = grab_global_function("bind_custom")
	},
	{
		name = "input_rebind_meta",
		kind = "action",
		label = "Meta",
		handler = grab_global_function("rebind_meta")
	},
	{
		name = "input_unbind",
		kind = "action",
		label = "Unbind",
		handler = grab_global_function("unbind_combo")
	},
	{
		name = "input_bind_utf8",
		kind = "action",
		label = "UTF-8",
		handler = grab_global_function("bind_utf8")
	}
};

return {
	{
		name = "input_bind_menu",
		kind = "action",
		label = "Bind",
		submenu = true,
		handler = bind_menu
	},
	{
		name = "input_keyboard_menu",
		kind = "action",
		label = "Keyboard",
		submenu = true,
		handler = keyb_menu
	},
	{
		name = "input_mouse_menu",
		kind = "action",
		label = "Mouse",
		submenu = true,
		handler = mouse_menu
	}
};



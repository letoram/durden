-- font hint translation tables
local hint_lut = {
	none = 0,
	mono = 1,
	light = 2,
	normal = 3,
	subpixel = 4 -- need to specify +1 in the case of rotated display
};
local hint_rlut = {};
for k,v in pairs(hint_lut) do
	hint_rlut[v] = k;
end

local config_terminal_font = {
	{
		name = "font_sz",
		label = "Size",
		kind = "value",
		description = "Change the default UI font pt size",
		validator = gen_valid_num(1, 100),
		initial = function() return tostring(gconfig_get("term_font_sz")); end,
		handler = function(ctx, val)
			gconfig_set("term_font_sz", tonumber(val));
		end
	},
	{
		name = "font_hint",
		label = "Hinting",
		kind = "value",
		description = "Change anti-aliasing hinting algorithm",
		set = {"none", "mono", "light", "normal", "subpixel"},
		initial = function() return hint_rlut[gconfig_get("term_font_hint")]; end,
		handler = function(ctx, val)
			gconfig_set("term_font_hint", hint_lut[val]);
		end
	},
	{
		name = "force_bitmap",
		label = "Force Bitmap",
		kind = "value",
		description = "Force the use of a built-in bitmap only font",
		hint = "(new terminals only)",
		initial = function() return gconfig_get("term_bitmap") and LBL_YES or LBL_NO; end,
		set = {LBL_YES, LBL_NO, LBL_FLIP},
		handler = suppl_flip_handler("term_bitmap")
	},
-- should replace with some "font browser" but we don't have asynch font
-- loading etc. and no control over cache size
	{
		name = "font_name",
		label = "Name",
		kind = "value",
		set = function()
			local set = glob_resource("*", SYS_FONT_RESOURCE);
			set = set ~= nil and set or {};
			table.insert(set, "BUILTIN");
			return set;
		end,
		description = "Change the default terminal font",
		initial = function() return gconfig_get("term_font"); end,
		handler = function(ctx, val)
			gconfig_set("term_font", val == "BUILTIN" and "" or val);
		end
	}
};

local cursor_menu = {
	{
		name = "style",
		label = "Style",
		kind = "value",
		description = "Change the cursor shape",
		set = {"block", "frame", "halfblock", "vline", "uline"},
		initial = function() return gconfig_get("term_cursor"); end,
		handler = function(ctx, val)
			gconfig_set("term_cursor", val);
		end
	},
	{
		name = "blink",
		label = "Blinking",
		kind = "value",
		description = "Change the cursor blink rate",
		initial = function() return tostring(gconfig_get("term_blink")); end,
		handler = function(ctx, val)
			gconfig_set("term_blink", tonumber(val));
		end,
		validator = gen_valid_num(0, 100),
		hint = "(0 = off, 1..n ticks)"
	}
};

return {
	{
		name = "alpha",
		label = "Background Alpha",
		kind = "value",
		hint = "(0..1)",
		validator = gen_valid_float(0, 1),
		description = "Change the background opacity for all terminals",
		initial = function() return tostring(gconfig_get("term_opa")); end,
		handler = function(ctx, val)
			gconfig_set("term_opa", tonumber(val));
		end
	},
	{
		name = "palette",
		label = "Palette",
		kind = "value",
		set = {"default", "solarized", "solarized-black", "solarized-white", "srcery"},
		description = "[DEPRECATED] Change palette used by terminal at startup",
		initial = function() return gconfig_get("term_palette"); end,
		handler = function(ctx, val)
			gconfig_set("term_palette", val);
		end
	},
	{
		name = "colorscheme",
		label = "Scheme",
		kind = "value",
		description = "Change the current and default set of colors used for terminal/tui clients",
		set = function()
			return suppl_colorschemes()
		end,
		initial = function() return gconfig_get("tui_colorscheme"); end,
		handler = function(ctx, val)
			gconfig_set("tui_colorscheme", val)
			for wnd in all_windows("tui", true) do
				suppl_tgt_color(wnd.external, val)
			end
			for wnd in all_windows("terminal", true) do
				suppl_tgt_color(wnd.external, val)
			end
		end
	},
	{
		name = "engine",
		label = "Engine",
		kind = "value",
		set = {"st", "tsm"},
		description = "Set the default state machine for terminal emulation",
		initial =
		function()
			return gconfig_get("term_interp");
		end,
		handler =
		function(ctx, val)
			gconfig_set("term_interp", val);
		end
	},
	{
		name = "font",
		label = "Font",
		kind = "action",
		submenu = true,
		description = "Switch font-set used by all terminals",
		handler = config_terminal_font
	},
	{
		name = "cursor",
		label = "Cursor",
		kind = "action",
		submenu = true,
		handler = cursor_menu,
		description = "Cursor look and feel"
	}
};

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

system_load("menus/global/schemes.lua")();

local durden_font = {
	{
		name = "size",
		label = "Size",
		kind = "value",
		description = "Change the default UI font pt size",
		validator = gen_valid_num(1, 100),
		initial = function() return tostring(gconfig_get("font_sz")); end,
		handler = function(ctx, val)
			gconfig_set("font_sz", tonumber(val));
		end
	},
	{
		name = "hinting",
		label = "Hinting",
		kind = "value",
		description = "Change anti-aliasing hinting algorithm",
		set = {"none", "mono", "light", "normal", "subpixel"},
		initial = function() return hint_rlut[gconfig_get("font_hint")]; end,
		handler = function(ctx, val)
			gconfig_set("font_hint", hint_lut[val]);
		end
	},
	{
		name = "name",
		label = "Font",
		kind = "value",
		description = "Set the default font used for UI elements",
		set = function()
			local set = glob_resource("*", SYS_FONT_RESOURCE);
			set = set ~= nil and set or {};
			return set;
		end,
		initial = function() return gconfig_get("font_def"); end,
		handler = function(ctx, val)
			gconfig_set("font_def", val);
		end
	},
	{
		name = "fbfont",
		label = "Fallback",
		kind = "value",
		description = "Set the fallback font used for missing glyphs (emoji, symbols)",
		set = function()
			local set = glob_resource("*", SYS_FONT_RESOURCE);
			set = set ~= nil and set or {};
			return set;
		end,
		initial = function() return gconfig_get("font_fb"); end,
		handler = function(ctx, val)
			gconfig_set("font_fb", val);
		end
	}
};

return {
-- thickness is dependent on area, make sure the labels and
-- constraints update dynamically
	{
		name = "font",
		label = "Font",
		kind = "action",
		submenu = true,
		description = "Generic UI font settings",
		handler = durden_font
	},
	{
		name = "bars",
		label = "Bars",
		kind = "action",
		submenu = true,
		description = "Controls/Settings for titlebars, statusbar and launch bar",
		handler = system_load("menus/global/bars.lua")();
	},
	{
		name = "border",
		label = "Border",
		kind = "action",
		submenu = true,
		description = "Global window border style and settings",
		handler = system_load("menus/global/border.lua")();
	},
	{
		name = "shadow",
		label = "Shadow",
		kind = "action",
		submenu = true,
		description = "Global window and UI element shadow settings",
		handler = system_load("menus/global/shadow.lua")();
	},
	{
		name = "shaders",
		label = "Shaders",
		kind = "action",
		submenu = true,
		description = "Control/Tune GPU- accelerated UI and display effects",
		handler = system_load("menus/global/shaders.lua")();
	},
	{
		name = "animations",
		label = "Animations",
		kind = "action",
		submenu = true,
		description = "Control animation speed and effect",
		handler = system_load("menus/global/animations.lua")();
	},
	{
		name = "mouse_scale",
		label = "Mouse Scale",
		kind = "value",
		hint = "(0.1 .. 10.0)",
		description = "Change the base scale factor used for the mouse cursor",
		initial = function() return tostring(gconfig_get("mouse_scalef")); end,
		handler = function(ctx, val)
			gconfig_set("mouse_scalef", tonumber(val));
			display_cycle_active(true);
		end
	},
	{
		name = "colors",
		label = "Colors",
		description = "Special colors that are not shader- defined or decorations",
		kind = "action",
		submenu = true,
		handler = system_load("menus/global/colors.lua")
	}
};

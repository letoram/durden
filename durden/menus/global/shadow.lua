local res = {
	{
		name = "style",
		label = "Style",
		description = "Set the drawing method for windowed UI elements (on-creation)",
		set = {"soft", "textured", "none"},
		kind = "value",
		initial = function()
			return gconfig_get("shadow_style");
		end,
		handler = function(ctx, val)
			gconfig_set("shadow_style", val);
		end
	},
	{
		name = "focus",
		label = "Focus Weight",
		description = "Set the shadow opacity when its owner is in focus",
		kind = "value",
		initial = function()
			return tostring(gconfig_get("shadow_focus"));
		end,
		validator = gen_valid_num(0, 1),
		handler = function(ctx, val)
			gconfig_set("shadow_focus", tonumber(val));
		end
	},
	{
		name = "defocus",
		label = "Defocus Weight",
		description = "Set the shadow opacity when its owner is not in focus",
		kind = "value",
		initial = function()
			return tostring(gconfig_get("shadow_defocus"));
		end,
		validator = gen_valid_num(0, 1),
		handler = function(ctx, val)
			gconfig_set("shadow_defocus", tonumber(val));
		end
	},
	{
		name = "offset",
		label = "Offset",
		description = "Set the shadow region offset",
		kind = "value",
		initial = function()
			return string.format("%.2d %.2d %.2d %.2d",
				gconfig_get("shadow_t"), gconfig_get("shadow_l"),
				gconfig_get("shadow_d"), gconfig_get("shadow_r")
			);
		end,
		hint = "(t l d r) px (w + l|r, h + t|d)",
		validator = suppl_valid_typestr("ffff", 0.0, 100.0, 0.0),
		handler = function(ctx, val)
			local elem = string.split(val, " ");
			if (#elem ~= 4) then
				return;
			end
			gconfig_set("shadow_t", math.floor(tonumber(elem[1])));
			gconfig_set("shadow_l", math.floor(tonumber(elem[2])));
			gconfig_set("shadow_d", math.floor(tonumber(elem[3])));
			gconfig_set("shadow_r", math.floor(tonumber(elem[4])));
		end
	},
	{
		name = "shader",
		label = "Shader",
		kind = "action",
		submenu = true,
		description = "Shader UI settings",
		alias = "/global/settings/visual/shaders/ui/dropshadow"
	},
	{
		name = "color",
		label = "Color",
		kind = "value",
		description = "Set the shadow base color"
	},
};

suppl_append_color_menu(
	gconfig_get("shadow_color"), res[#res],
	function(fmt, r, g, b)
		gconfig_set("shadow_color", {r * 0.003921, g * 0.003921, b * 0.003921});
	end);

return res;

return
{
	{
		name = "thickness",
		label = "Thickness",
		kind = "value",
		description = "Visible portion of the border area in tiled modes",
		hint = function() return
			string.format("(0..%d px)", gconfig_get("borderw")) end,
		validator = function(val)
			return gen_valid_num(0, gconfig_get("borderw"))(val);
		end,
		initial = function() return tostring(gconfig_get("bordert")); end,
		handler = function(ctx, val)
			local num = tonumber(val);
			gconfig_set("bordert", tonumber(val));
			active_display():rebuild_border();
			for k,v in pairs(active_display().spaces) do
				v:resize();
			end
		end
	},
	{
		name = "thickness_float",
		label = "Thickness (Float)",
		kind = "value",
		description = "Visible portion of the border area in float mode",
		hint = function() return
			string.format("(0..%d px)", gconfig_get("borderw_float")) end,
		validator = function(val)
			return gen_valid_num(0, gconfig_get("borderw_float"))(val);
		end,
		initial = function() return tostring(gconfig_get("bordert_float")); end,
		handler = function(ctx, val)
			local num = tonumber(val);
			gconfig_set("bordert_float", tonumber(val));
			active_display():rebuild_border();
			for k,v in pairs(active_display().spaces) do
				v:resize();
			end
		end
	},
	{
		name = "area",
		label = "Area",
		kind = "value",
		hint = "(0..100 px)",
		initial = function() return tostring(gconfig_get("borderw")); end,
		validator = gen_valid_num(0, 100),
		description = "Set the reserved (visible+nonvisible) border area",
		handler = function(ctx, val)
			gconfig_set("borderw", tonumber(val));
			active_display():rebuild_border();
			for wnd in all_windows(nil, true) do
				wnd:resize();
			end
			for k,v in pairs(active_display().spaces) do
				v:resize();
			end
		end
	},
	{
		name = "area_float",
		label = "Area (Float)",
		kind = "value",
		hint = "(0..100 px)",
		initial = function() return tostring(gconfig_get("borderw_float")); end,
		validator = gen_valid_num(0, 100),
		description = "Set the reserved (visible+nonvisible) border area",
		handler = function(ctx, val)
			gconfig_set("borderw_float", tonumber(val));
			active_display():rebuild_border();
			for wnd in all_windows(nil, true) do
				wnd:resize();
			end
			for k,v in pairs(active_display().spaces) do
				v:resize();
			end
		end
	},
	{
		name = "color",
		label = "Color",
		kind = "value",
		hint = "(r g b)[0..255]",
		initial = function()
			local bc = gconfig_get("border_color");
			return string.format("%.0f %.0f %.0f", bc[1], bc[2], bc[3]);
		end,
		validator = suppl_valid_typestr("fff", 0, 255, 0),
		description = "The color used as the active border color state",
		handler = function(ctx, val)
			local tbl = suppl_unpack_typestr("fff", val, 0, 255);
			for wnd in all_windows(nil, true) do
				image_color(wnd.border, tbl[1], tbl[2], tbl[3]);
			end
			gconfig_set("border_color", tbl);
		end,
	},
};

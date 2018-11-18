local function remove_button(dir)
	local res = {};

	for group, list in pairs(gconfig_buttons) do
		for i,v in ipairs(list) do
			if (not dir or v.direction == string.lower(dir)) then
				table.insert(res, {
					name = tostring(i),
					label = group .. "_" .. tostring(i),
					description = "Button Label: " .. v.label,
					kind = "action",
					handler = function()
						table.remove(gconfig_buttons[group], i);
						gconfig_buttons_rebuild();
					end
				});
			end
		end

	end
	return res;
end

local function button_query_path(wnd, vsym, dir, group)
	dispatch_symbol_bind(function(path)
		local wm = active_display();
-- can actually change during interaction time so verify
		table.insert(gconfig_buttons[group], {
			label = vsym,
			direction = dir,
			command = path
		});
		gconfig_buttons_rebuild();
	end);
end

local function titlebar_buttons(dir, lbl)
	local wnd = active_display().selected;
	local hintstr = "(0x:byte seq | icon:ref | string)";
	return
	{
		{
		label = "Remove",
		name = "remove",
		kind = "action",
		submenu = true,
		description = "Remove a button",
		eval = function() return #remove_button(dir) > 0; end,
		handler = function()
			return remove_button(dir);
		end
		},
		{
		label = "Add",
		name = "add",
		kind = "value",
		hint = hintstr,
		validator = function(val)
			return suppl_valid_vsymbol(val);
		end,
		widget = "special:icon",
		description = "Add a new button used in all layout modes",
		handler = function(ctx, val)
			local st, val = suppl_valid_vsymbol(val);
			button_query_path(active_display().selected, val, dir, "all");
		end
		},
		{
		label = "Add (Tile)",
		name = "add_tile",
		kind = "value",
		hint = hintstr,
		widget = "special:icon",
		description = "Add a new button for tiled layout modes",
		validator = function(val)
			return suppl_valid_vsymbol(val);
		end,
		handler = function(ctx, val)
			local wnd = active_display().selected;
			button_query_path(active_display().selected, val, dir, "tile");
		end
		},
		{
		label = "Add (Float)",
		name = "add_float",
		kind = "value",
		hint = hintstr,
		widget = "special:icon",
		validator = function(val)
			return suppl_valid_vsymbol(val);
		end,
		description = "Add a new button for floating layout mode",
		handler = function(ctx, val)
			button_query_path(active_display().selected, val, dir, "float");
		end
		}
	}
end

local titlebar_buttons = {
	{
		name = "left",
		kind = "action",
		label = "Left",
		description = "Modify buttons in the left group",
		submenu = true,
		handler = function()
			return titlebar_buttons("left", "Left");
		end
	},
	{
		name = "right",
		kind = "action",
		submenu = true,
		label = "Right",
		description = "Modify buttons in the right group",
		submenu = true,
		handler = function()
			return titlebar_buttons("right", "Right");
		end
	}
};

return
{
	{
		name = "color",
		label = "Color",
		kind = "value",
		hint = "(r g b)[0..255]",
		initial = function()
			local bc = gconfig_get("titlebar_color");
			return string.format("%.0f %.0f %.0f", bc[1], bc[2], bc[3]);
		end,
		validator = suppl_valid_typestr("fff", 0, 255, 0),
		description = "The color used as the active titlebar color state",
		handler = function(ctx, val)
			local tbl = suppl_unpack_typestr("fff", val, 0, 255);
			for wnd in all_windows(nil, true) do
				image_color(wnd.titlebar.anchor, tbl[1], tbl[2], tbl[3]);
			end
			gconfig_set("titlebar_color", tbl);
		end,
	},
	{
		name = "pattern",
		label = "Pattern",
		kind = "value",
		description = "Change the format string used to populate the titlebar text",
		initial = function() return gconfig_get("titlebar_ptn"); end,
		hint = "%p (tag) %t (title.) %i (ident.)",
		validator = function(str)
			return string.len(str) > 0 and not string.find(str, "%%", 1, true);
		end,
		handler = function(ctx, val)
			gconfig_set("titlebar_ptn", val);
			for tiler in all_tilers_iter() do
				for i, v in ipairs(tiler.windows) do
					v:set_title();
				end
			end
		end
	},
	{
		name = "hide",
		label = "Hidden",
		kind = "value",
		description = "Control if the titlebar should be hidden or not for new windows",
		set = {LBL_YES, LBL_NO, LBL_FLIP},
		initial = function() return
			gconfig_get("hide_titlebar") and LBL_YES or LBL_NO end,
		handler = suppl_flip_handler("hide_titlebar")
	},
	{
		name = "merge",
		label = "Merge",
		kind = "value",
		description = "Hidden titlebars gets shown in the center area of the statusbar",
		set = {LBL_YES, LBL_NO, LBL_FLIP},
		initial = function() return
			gconfig_get("titlebar_statusbar") and LBL_YES or LBL_NO;
		end,
		handler = suppl_flip_handler("titlebar_statusbar")
	},
	{
		name = "buttons",
		label = "Buttons",
		kind = "action",
		submenu = true,
		description = "Modify the default set of decoration buttons added to new windows",
		handler = titlebar_buttons
	},
};

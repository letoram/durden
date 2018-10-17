local function button_query_path(vsym, dir, group)
	dispatch_symbol_bind(
		function(path)
			table.insert(gconfig_statusbar, {
				label = vsym,
				direction = dir,
				command = path
			});
			gconfig_statusbar_rebuild();
		end
	);
end

local function remove_button(dir)
	local res = {};

		for i,v in ipairs(gconfig_statusbar) do
			if (not dir or v.direction == string.lower(dir)) then
				table.insert(res, {
					name = tostring(i),
					label = group .. "_" .. tostring(i),
					description = "Button Label: " .. v.label,
					kind = "action",
					handler = function()
						table.remove(gconfig_statusbar, i);
						gconfig_statusbar_rebuild();
					end
				});
			end
	end

	return res;
end

local function statusbar_buttons(dir, lbl)
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
		name = "add",
		label = "Add",
		kind = "value",
		hint = hintstr,
		validator = function(val)
			return suppl_valid_vsymbol(val);
		end,
		widget = "special:icon",
		description = "Add a new button used in all layout modes",
		handler = function(ctx, val)
			local st, val = suppl_valid_vsymbol(val);
			button_query_path(val, dir, "all");
		end
	}
};
end

local statusbar_buttons_dir = {
	{
		name = "left",
		kind = "action",
		label = "Left",
		description = "Modify buttons in the left group",
		submenu = true,
		handler = function()
			return statusbar_buttons("left", "Left");
		end
	},
	{
		name = "right",
		kind = "action",
		label = "Right",
		description = "Modify buttons in the right group",
		submenu = true,
		handler = function()
			return statusbar_buttons("right", "Right");
		end
	}
};

return {
	{
		name = "border_pad",
		label = "Border Padding",
		description = "Insert padding (% of display size)",
		kind = "value",
		initial = function()
			return string.format("%.2d %.2d %.2d %.2d",
				gconfig_get("sbar_tspace"), gconfig_get("sbar_lspace"),
				gconfig_get("sbar_dspace"), gconfig_get("sbar_rspace"));
		end,
		hint = "(t l d r) px",
		validator = suppl_valid_typestr("ffff", 0.0, 100.0, 0.0),
		handler = function(ctx, val)
			local elem = string.split(val, " ");
			if (#elem ~= 4) then
				return;
			end
			gconfig_set("sbar_tspace", math.floor(tonumber(elem[1])));
			gconfig_set("sbar_lspace", math.floor(tonumber(elem[2])));
			gconfig_set("sbar_dspace", math.floor(tonumber(elem[3])));
			gconfig_set("sbar_rspace", math.floor(tonumber(elem[4])));
			for disp in all_tilers_iter() do
				disp:tile_update();
			end
		end
	},
	{
		name = "mode_button",
		label = "Mode Button",
		kind = "value",
		description = "Control the presence of the dynamic mode- statusbar button",
		initial = function()
			return gconfig_get("sbar_modebutton") and LBL_YES or LBL_NO; end,
		set = {LBL_YES, LBL_NO},
		handler = function(ctx, val)
			gconfig_set("sbar_modebutton", val == LBL_YES);
			for tiler in all_tilers_iter() do
				tiler:tile_update();
			end
		end
	},
	{
		name = "ws_buttons",
		label = "Workspace Buttons",
		kind = "value",
		description = "Control the presence of workspace indicator buttons",
		initial = function()
			return gconfig_get("sbar_wsbuttons") and LBL_YES or LBL_NO; end,
		set = {LBL_YES, LBL_NO},
		handler = function(ctx, val)
			gconfig_set("sbar_wsbuttons", val == LBL_YES);
			for tiler in all_tilers_iter() do
				tiler:tile_update();
			end
		end
	},
	{
		name = "force_prefix",
		label = "Number Prefix Buttons",
		kind = "value",
		description = "Force number prefix on tagged workspaces",
		initial = function()
			return gconfig_get("sbar_numberprefix") and LBL_YES or LBL_NO; end,
		set = {LBL_YES, LBL_NO},
		handler = function(ctx, val)
			gconfig_set("sbar_numberprefix", val == LBL_YES);
			for tiler in all_tilers_iter() do
				tiler:tile_update();
			end
		end
	},
	{
		name = "buttons",
		label = "Buttons",
		kind = "action",
		submenu = true,
		description = "Add/Remove custom buttons",
		handler = statusbar_buttons_dir
	},
	{
		name = "position",
		label = "Position",
		kind = "value",
		description = "Change the statusbar vertical position",
		set = {"top", "bottom"},
		initial = function()
			return gconfig_get("sbar_pos");
		end,
		handler = function(ctx, val)
			gconfig_set("sbar_pos", val);
			active_display():tile_update();
		end
	},
	{
		name = "visibility",
		label = "Visibility",
		kind = "value",
		description = "Control where/if the statusbar should be visible",
		set = {"desktop", "hud", "hidden"},
		initial = function() return gconfig_get("sbar_visible"); end,
		handler = function(ctx, val)
			gconfig_set("sbar_visible", val);
			for tiler in all_tilers_iter() do
				tiler:tile_update();
				tiler:resize();
			end
		end
	}
};

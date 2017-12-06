return {
	{
		name = "border_pad",
		label = "Border Padding",
		description = "Insert padding (% of display size)",
		kind = "value";
		initial = function()
			return string.format("%.2d %.2d %.2d %.2d",
				gconfig_get("sbar_lspace")*100, gconfig_get("sbar_rspace")*100,
				gconfig_get("sbar_tspace")*100, gconfig_get("sbar_bspace")*100);
		end,
		hint = "(l r t b) % (0..20)",
		validator = suppl_valid_typestr("ffff", 0.0, 20.0, 0.0),
		handler = function(ctx, val)
			local elem = string.split(val, " ");
			if (#elem ~= 4) then
				return;
			end
			gconfig_set("sbar_lspace", tonumber(elem[1]) * 0.01);
			gconfig_set("sbar_rspace", tonumber(elem[2]) * 0.01);
			gconfig_set("sbar_tspace", tonumber(elem[3]) * 0.01);
			gconfig_set("sbar_bspace", tonumber(elem[4]) * 0.01);
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
		name = "Position",
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
		name = "hud",
		label = "HUD mode",
		kind = "value",
		description = "Show the statusbar exclusively on the HUD",
		set = {LBL_YES, LBL_NO},
		initial = function()
			return gconfig_get("sbar_hud") and LBL_YES or LBL_NO;
		end,
		handler = function(ctx, val)
			gconfig_set("sbar_hud", val == LBL_YES);
			active_display():tile_update();
			for k,v in pairs(active_display().spaces) do
				v:resize();
			end
		end
	}
};

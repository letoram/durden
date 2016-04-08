local swap_menu = {
	{
		name = "up",
		label = "Up",
		kind = "action",
		handler = grab_global_function("swap_up")
	},
	{
		name = "merge_collapse",
		label = "Merge/Collapse",
		kind = "action",
		handler = grab_shared_function("mergecollapse")
	},
	{
		name = "down",
		label = "Down",
		kind = "action",
		handler = grab_global_function("swap_down")
	},
	{
		name = "left",
		label = "Left",
		kind = "action",
		handler = grab_global_function("swap_left")
	},
	{
		name = "right",
		label = "Right",
		kind = "action",
		handler = grab_global_function("swap_right")
	},
};

return {
	{
		name = "tag",
		label = "Tag",
		kind = "value",
		validator = function() return true; end,
		handler = function(ctx, val)
			local wnd = active_display().selected;
			if (wnd) then
				wnd:set_prefix(string.gsub(val, "\\", "\\\\"));
			end
		end
	},
	{
		name = "swap",
		label = "Swap",
		kind = "action",
		submenu = true,
		handler = swap_menu
	},
	{
		name = "reassign_name",
		label = "Reassign",
		kind = "action",
		handler = grab_shared_function("reassign_wnd_bywsname");
	},
	{
		name = "canvas_to_bg",
		label = "Workspace-Background",
		kind = "action",
		handler = grab_shared_function("wnd_tobg");
	},
	{
		name = "titlebar_toggle",
		label = "Titlebar On/Off",
		kind = "action",
		handler = function()
			local wnd = active_display().selected;
			wnd.hide_titlebar = not wnd.hide_titlebar;
			wnd:set_title(wnd.title_text);
		end
	},
	{
		name = "target_opacity",
		label = "Opacity",
		kind = "value",
		hint = "(0..1)",
		validator = gen_valid_num(0, 1),
		handler = function(ctx, val)
			local wnd = active_display().selected;
			if (wnd) then
				local opa = tonumber(val);
				blend_image(wnd.border, opa);
				blend_image(wnd.canvas, opa);
			end
		end
	},
	{
		name = "delete_protect",
		label = "Delete Protect",
		kind = "value",
		set = {LBL_YES, LBL_NO},
		initial = function() return active_display().selected.delete_protect and
			LBL_YES or LBL_NO; end,
		handler = function(ctx, val)
			active_display().selected.delete_protect = val == LBL_YES;
		end
	},
	{
		name = "migrate_display",
		label = "Migrate",
		kind = "action",
		submenu = true,
		handler = grab_shared_function("migrate_wnd_bydspname"),
		eval = function()
			return gconfig_get("display_simple") == false and #(displays_alive()) > 1;
		end
	},
	{
		name = "destroy",
		label = "Destroy",
		kind = "action",
		handler = grab_shared_function("destroy")
	}
};

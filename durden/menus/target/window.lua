local swap_menu = {
	{
		name = "window_swap_up",
		label = "Up",
		kind = "action",
		handler = grab_global_function("swap_up")
	},
	{
		name = "window_swap_down",
		label = "Down",
		kind = "action",
		handler = grab_global_function("swap_down")
	},
	{
		name = "window_swap_left",
		label = "Left",
		kind = "action",
		handler = grab_global_function("swap_left")
	},
	{
		name = "window_swap_right",
		label = "Right",
		kind = "action",
		handler = grab_global_function("swap_right")
	},
};

return {
	{
		name = "window_prefix",
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
		name = "window_swap",
		label = "Swap",
		kind = "action",
		submenu = true,
		handler = swap_menu
	},
	{
		name = "window_reassign_byname",
		label = "Reassign",
		kind = "action",
		handler = grab_shared_function("reassign_wnd_bywsname");
	},
	{
		name = "window_tobackground",
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
		name = "window_migrate_display",
		label = "Migrate",
		kind = "action",
		submenu = true,
		handler = grab_shared_function("migrate_wnd_bydspname"),
		eval = function()
			return gconfig_get("display_simple") == false and #(displays_alive()) > 1;
		end
	},
	{
		name = "window_destroy",
		label = "Destroy",
		kind = "action",
		handler = grab_shared_function("destroy")
	}
};

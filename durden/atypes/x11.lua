--
-- X11- bridge, for use with Xarcan.
--

local toplevel_menu = {
	{
		name = "debug",
		label = "Debug Bridge",
		kind = "action",
		description = "Send a debug window to the bridge client",
		validator = function()
			local wnd = active_display().selected;
			return wnd.bridge and valid_vid(wnd.bridge.external, TYPE_FRAMESERVER);
		end,
		handler = wayland_debug_wnd,
	}
};

return {
	atype = "bridge-x11",
	default_shader = {"simple", "noalpha"},
	actions =
	{
		{
			name = "x11",
			label = "X11",
			description = "X11 specific window management options",
			submenu = true,
			kind = "action",
			handler = toplevel_menu
		}
	},
-- props will be projected upon the window during setup (unless there
-- are overridden defaults)
	props = {
		kbd_period = 0,
		kbd_delay = 0,
		centered = true,
		scalemode = "normal",
		filtermode = FILTER_NONE,
		rate_unlimited = true,
		clipboard_block = true,
		font_block = true,
	},
	dispatch = {
		preroll = function(wnd, source, tbl)
			target_displayhint(source, wnd.max_w, wnd.max_h, 0, active_display().disptbl);
			if (TARGET_ALLOWGPU ~= nil and gconfig_get("gpu_auth") == "full") then
				target_flags(source, TARGET_ALLOWGPU);
			end
		end
	}
};

--
-- X11- bridge, for use with Xarcan.
--
return {
	atype = "bridge-x11",
	default_shader = {"simple", "noalpha"},
	actions = {
	{
-- custom menu goes here
	},
-- props will be projected upon the window during setup (unless there
-- are overridden defaults)
	},
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

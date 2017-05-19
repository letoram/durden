--
-- X11- bridge, for use with Xarcan.
--
return {
	atype = "bridge-x11",
	default_shader = {"simple", "noalpha"},
	actions = {
	{
	name = "bridge",
	label = "Bridge",
	kind = "action",
	submenu = true,
	handler = retrosub
	},
-- props will be projected upon the window during setup (unless there
-- are overridden defaults)
	},
	props = {
		kbd_period = 0,
		kbd_delay = 0,
		centered = true,
		scalemode = "aspect",
		filtermode = FILTER_NONE,
		rate_unlimited = true,
		clipboard_block = true,
		font_block = true,
	},
	dispatch = {
		preroll = function(wnd, source, tbl)
			target_displayhint(source, wnd.width, wnd.height, 0, active_display().disptbl);
		end
	}
};

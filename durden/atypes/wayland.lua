--
-- Wayland- bridge, for use with src/tools/waybridge.
--
return {
	atype = "bridge-wayland",
	default_shader = {"simple", "noalpha"},
	actions = {},
-- props will be projected upon the window during setup (unless there
-- are overridden defaults)
	props = {
-- wayland implements client-side defined repeats
		kbd_period = 0,
		kbd_delay = 0,
		centered = true,
		scalemode = "client",
		filtermode = FILTER_NONE,
		rate_unlimited = true,
		clipboard_block = true,
		font_block = true,
-- so, depending on the protocol state we may or may not have decorations
--		hide_titlebar = true,
--		hide_border = true,
		allowed_segments = {"bridge-wayland", "popup", "cursor"},
	},
	dispatch = {
		preroll = function(wnd, source, tbl)
			target_displayhint(source, wnd.max_w, wnd.max_h, 0, active_display().disptbl);
		end
	}
};

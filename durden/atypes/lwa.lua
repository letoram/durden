local rtbl = {
	atype = "lightweight arcan",
	actions = {
	{
		name = "lwa_debugdisp",
		label = "Add Display",
		eval = function() return DEBUGLEVEL > 0; end,
		handler = function(wnd)
			if (valid_vid(wnd.external, TYPE_FRAMESERVER)) then
				local vid = target_alloc(wnd.external, function() end, "debug");
				local wnd = durden_launch(vid, ":debug_display", "");
				wnd.scalemode = "stretch";
				wnd:resize(wnd.width, wnd.height);
			end
		end,
		kind = "action"
	}
	},
	bindings = {},
	dispatch = {},
	props = {
		kbd_period = 0,
		kbd_delay = 0,
		centered = true,
		default_shader = {"simple", "crop"},
		scalemode = "stretch",
		autocrop = true,
		rate_unlimited = true,
		filtermode = FILTER_NONE,
		clipboard_block = true,
		font_block = false
	},
};
return rtbl;

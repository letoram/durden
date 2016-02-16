--
-- Game archetype, settings and menus specific for game- frameserver
-- session (e.g. synchronization mode, state transfers, a/v filtering,
-- latency and buffering compensation, core options, debug features,
-- special input workarounds)
--

local skiptbl = {};
skiptbl["Automatic"] = 0;
skiptbl["None"] = -1;
skiptbl["Skip 1"] = 1;
skiptbl["Skip 2"] = 2;
skiptbl["Skip 3"] = 3;
skiptbl["Skip 4"] = 4;

-- preaudio
-- framealign
-- target_framemode(vid, skipval, align, preaudio, jitterstep, jitterxfer)
-- target_postfilter(hue, sat, contrast[1], bright, gamma, sharp[2],
-- fast-forward (val)

local retrosub = {
	{
	name = "gamewnd_reqdbg",
	label = "Debug-stats",
	kind = "action",
	eval = function() return DEBUGLEVEL > 0; end,
	handler = function(wnd)
		if (valid_vid(wnd.external, TYPE_FRAMESERVER)) then
			local vid = target_alloc(wnd.external, function() end, "debug");
			durden_launch(vid, "game:debug", "");
		end
	end
	}
};

return {
	atype = "game",
	default_shader = {"simple", "noalpha"},
	actions = {
	{
	name = "gamewnd_retro",
	label = "Game",
	kind = "action",
	submenu = true,
	handler = retrosub
	}
	},
-- props witll be projected upon the window during setup (unless there
-- are overridden defaults)
	props = {
		kbd_period = 0,
		kbd_delay = 0,
		scalemode = "aspect",
		filtermode = FILTER_NONE,
		rate_unlimited = true,
		clipboard_block = true,
		font_block = true
	},
	default_shader = "noalpha"
};

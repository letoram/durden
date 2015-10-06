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

-- map coreopt
-- toggle debug-graph subwindow
-- preaudio
-- framealign
-- target_framemode(vid, skipval, align, preaudio, jitterstep, jitterxfer)
-- target_postfilter(hue, sat, contrast[1], bright, gamma, sharp[2],
-- fast-forward (val)
-- input (lock / unlock)

return {
	atype = "game",
	actions = {
	{
		name = "gamewnd_reqdbg",
		label = "Debug-Subwindow",
		kind = "action",
		handler = function(wnd)
			if (valid_vid(wnd.external, TYPE_FRAMESERVER)) then
				target_graphmode(wnd.external, 1);
			end
		end
	},
	},

	props = {
		kbd_period = 0,
		kbd_delay = 0,
<<<<<<< Updated upstream
		scalemode = "aspect",
		filtermode = FILTER_NONE,
=======
		rate_unlimited = true,
>>>>>>> Stashed changes
	}
};

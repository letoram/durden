--
-- Game archetype, settings and menus specific for game- frameserver
-- session - primarily display hints and synchronization control
--

local skiptbl = {};

skiptbl["Automatic"] = 0;
skiptbl["None"] = -1;
skiptbl["Skip 1"] = 1;
skiptbl["Skip 2"] = 2;
skiptbl["Skip 3"] = 3;
skiptbl["Skip 4"] = 4;

local skipset = {"Automatic", "None", "Skip 1", "Skip 2", "Skip 3", "Skip 4"};
for k,v in ipairs(skipset) do
	assert(skiptbl[v] ~= nil);
end

local function update_synch(ctx)
	local cs = ctx.synch;
	if (not cs) then
		warning("atype/game, update_synch fields missing");
		return;
	end

	if (valid_vid(ctx.external, TYPE_FRAMESERVER)) then
		target_framemode(ctx.external, skiptbl[cs.skipmode],
			cs.framealign, cs.preaudio, cs.jitterstep, cs.jitterxfer);
	end
end

local synch_menu = {
	{
	name = "gamewnd_synchmode",
	label = "Mode",
	kind = "value",
	set = skipset,
	initial = function(ctx) return active_display().selected.synch.skipmode; end,
	handler = function(ctx, val)
		local wnd = active_display().selected;
		wnd.synch.skipmode = val;
		update_synch(wnd);
	end
	},
	{
	name = "gamewnd_preaud",
	label = "Preaudio",
	kind = "value",
	initial = function(ctx, val)
		local wnd = active_display().selected;
		return tostring(wnd.synch.preaudio);
	end,
	validator = gen_valid_num(0, 8),
	handler = function(ctx, val)
		local wnd = active_display().selected;
		wnd.synch.preaudio = tonumber(val);
		update_synch(wnd);
	end
	},
	{
	name = "framealign",
	label = "Framealign",
	kind = "value",
	initial = function() return "0"; end,
	validator = gen_valid_num(0, 14),
	handler = function(ctx, val)
		local wnd = active_display().selected;
		wnd.synch.framealign = tonumber(cal);
		update_synch(wnd);
	end
	}
};

local retrosub = {
	{
	name = "gamewnd_reqdbg",
	label = "Debug-stats",
	kind = "action",
	eval = function() return DEBUGLEVEL > 0; end,
	handler = function(ctx, val)
		local wnd = active_display().selected;
		if (valid_vid(wnd.external, TYPE_FRAMESERVER)) then
			local vid = target_alloc(wnd.external, function() end, "debug");
			durden_launch(vid, "game:debug", "");
		end
	end
	},
	{
	name = "gamewnd_syncopt",
	label = "Synchronization",
	kind = "action",
	submenu = true,
	handler = synch_menu
	},
	{
	name = "gamewnd_slotgrab",
	label = "Slotted-Grab",
	kind = "action",
	handler = function(ctx, val)
		local wnd = active_display().selected;
		iostatem_slotgrab(wnd);
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
	},
-- props witll be projected upon the window during setup (unless there
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
-- current defaults, safe values match the synchronization menu above
		synch = {
			preaudio = 1,
			skipmode = "None",
			framealign = 8,
			jitterstep = 0,
			jitterxfer = 0
		}
	}
};

--
-- Menus and fglobal registration for functions that are shared between all
-- windows that has an external connection. Additional ones can be superimposed
-- based on archetype or even windows identification for entirely custom
-- handling (integrating senseye sensors for instance).
--

local function shared_valid01_float(inv)
	if (string.len(inv) == 0) then
		return true;
	end

	local val = tonumber(inv);
	return val and (val >= 0.0 and val <= 1.0) or false;
end

local function shared_reset(wnd)
	if (wnd.external) then
		reset_target(wnd.external);
	end
end

local function shared_resume(wnd)
	if (wnd.external) then
		resume_target(wnd.external);
	end
end

local function shared_suspend(wnd)
	if (wnd.external) then
		suspend_target(wnd.external);
	end
end

local function gain_stepv(gainv, abs)
	local wnd = displays.main.selected;
	if (not wnd or not wnd.source_audio) then
		return;
	end

	if (not abs) then
		gainv = gainv + (wnd.source_gain and wnd.source_gain or 1.0);
	end

	gainv = gainv < 0.0 and 0.0 or gainv;
	gainv = gainv > 1.0 and 1.0 or gainv;
	wnd.source_gain = gainv;
	audio_gain(wnd.source_audio, gconfig_get("global_gain") * gainv,
		gconfig_get("gain_fade"));
end

local shared_settings = {
	{
		name = "filtering",
		label = "Filtering",
		kind = "list",
		validator = {
			None = FILTER_NONE,
			Linear = FILTER_LINEAR,
			Bilinear = FILTER_BILINEAR,
			Trilinear = FILTER_TRILINEAR
		},
		handler = function(ctx, value)
			image_texfilter(ctx.external, value);
		end
	}
};

local audio_menu = {
	{
		name = "target_audio",
		label = "Toggle On/Off",
		kind = "action",
		handler = toggle_audio
	},
	{
		name = "gain_add10",
		label = "+10%",
		kind = "action",
		handler = function() gain_stepv(0.1); end
	},
	{
		name = "gain_sub10",
		label = "-10%",
		kind = "action",
		handler = function() gain_stepv(-0.1); end
	},
	{
		name ="target_audio_gain",
		label = "Gain",
		hint = "(0..1)",
		kind = "value",
		validator = shared_valid01_float,
		handler = function(ctx, val) gain_stepv(tonumber(val), true); end
	},
};

local function set_scalef(mode)
	local wnd = displays.main.selected;
	if (wnd) then
		wnd.scalemode = mode;
		wnd:resize(wnd.width, wnd.height);
	end
end

local scalemodes = {
	{
		name = "target_scale_normal",
		label = "Normal",
		kind = "action",
		handler = function() set_scalef("normal"); end
	},
	{
		name = "target_scale_stretch",
		label = "Stretch",
		handler = function() set_scalef("stretch"); end
	}
};

local video_menu = {
	{
		name = "target_scaling",
		label = "Scaling",
		kind = "action",
		hint = "Scale Mode:",
		submenu = true,
		force = true,
		handler = scalemodes
	},
	{
		name = "target_filtering",
		label = "Filtering",
		kind = "action",
		hint = "Basic Filter:",
		submenu = true,
		force = true,
		handler = filtermodes
	}
-- good place to add advanced upscalers (xBR, CRT etc.)
};

-- Will be presented in order, not sorted. Make sure they come in order
-- useful:safe -> uncommon:dangerous to reduce the change of some quick
-- mispress doing something damaging
local shared_actions = {
	{
		name = "shared_suspend",
		label = "Suspend",
		kind = "action",
		handler = shared_suspend
	},
	{
		name = "shared_resume",
		label = "Resume",
		kind = "action",
		handler = shared_resume
	},
	{
		name = "shared_audio",
		label = "Audio",
		submenu = true,
		kind = "action",
		handler = audio_menu,
		force = true,
		eval = function(ctx)
			return displays.main.selected and displays.main.selected.source_audio
		end
	},
	{
		name = "shared_video",
		label = "Video",
		kind = "action",
		submenu = true,
		force = true,
		handler = video_menu,
		hint = "Video:"
	},
	{
		name = "reset",
		label = "Reset",
		kind = "action",
		dangerous = true,
		handler = shared_reset
	},
};

local function query_tracetag()
	local bar = tiler_lbar(displays.main, function(ctx,msg,done,set)
		if (done and displays.main.selected) then
			image_tracetag(displays.main.selected.canvas, msg);
		end
		return {};
	end);
	bar:set_label("tracetag (wnd.canvas):");
end

local debug_menu = {
	{
		name = "query_tracetag",
		label = "Tracetag",
		kind = "action",
		handler = query_tracetag
	}
};

if (DEBUGLEVEL > 0) then
	table.insert(shared_actions, {
		name = "debug",
		label = "Debug",
		kind = "action",
		hint = "Debug:",
		submenu = true,
		force = true,
		handler = debug_menu
	});
end

--
-- Missing:
-- Input (local binding / rebinding or call once)
--  [atype game: frame management,
--   special filtering,
--   preaudio,
--   block opposing,
--  ]
-- State Management (if state-size is known)
-- Advanced (spawn debug, autojoin workspace)
-- Clone
--

-- the handler maneuver is to make sure that the callback that is triggered
-- matches the format in gfunc/shared so that we can reuse both for scripting
-- and for menu navigation.
local function show_shmenu(wnd)
	wnd = wnd == nil and displays.main or wnd;
	if (wnd == nil) then
		return;
	end

	local ctx = {
		list = wnd.dispatch and merge_menu(shared_actions, wnd.dispatch) or
			shared_actions,
		handler = wnd
	};

	launch_menu(wnd.wm, ctx, true, "Action:");
end

--gf["cycle_scalemode"] = function()
--	local sel = displays.main.selected;
--	local modes = displays.main.scalemodes;

--	if (sel and modes) then
--		local ind = 1;

--		for i,v in ipairs(modes) do
--			if (v == sel.scalemode) then
--				ind = i;
--				break;
--			end
--		end

-- recall that not all displays need to support the same scalemodes, this is
-- due to the cost/filtering capability of some special displays
--		ind = (ind + 1 > #modes) and 1 or (ind + 1);
--		sel.scalemode = modes[ind];
--		sel:resize(sel.width, sel.height);
--	end
--end

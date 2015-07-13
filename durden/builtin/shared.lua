--
-- Menus and fglobal registration for functions that are shared between all
-- windows that has an external connection. Additional ones can be superimposed
-- based on archetype or even windows identification for entirely custom
-- handling (integrating senseye sensors for instance).
--

local function shared_valid01_float(inv)
	local val = tonumber(inv);
	return val >= 0.0 and val <= 1.0;
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

local shared_settings = {
	{
		name = "set_gain",
		label = "Gain",
		kind = "number",
		validator = shared_valid01_float,
		handler = function(ctx, value)
			if (ctx.wnd.source_audio) then
				audio_gain(ctx.wnd.source_audio, value, gconfig_get("transition_time"));
			end
		end,
	},
	{
		name = "auto_suspend",
		label = "Auto Suspend",
		kind = "boolean",
		handler = function(ctx, value)
		end
	},
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
	},
-- scaler
-- positioning
};

-- Will be presented in order, not sorted. Make sure they come in order
-- useful:safe -> uncommon:dangerous to avoid the change of some quick
-- mispress doing something damaging
local shared_actions = {
	{
		name = "suspend",
		label = "Suspend",
		kind = "action",
		eval = function(ctx) return true; end,
		handler = shared_suspend
	},
	{
		name = "suspend",
		label = "Resume",
		kind = "action",
		eval = function(ctx) return true; end,
		handler = shared_resume
	},
	{
		name = "reset",
		label = "Reset",
		kind = "action",
		handler = shared_reset
	},
};

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
	local ctx = {
		list = wnd.dispatch and merge_menu(shared_actions, wnd.dispatch) or
			shared_actions,
		handler = wnd
	};

	launch_menu(wnd.wm, ctx, true, "Action:");
end

local function show_setmenu(wnd)
	launch_menu(wnd.wm, shared_settings, true, "Settings:");
end

register_shared("pause", pausetgt);
register_shared("reset", resettgt);
register_shared("target_actions", show_shmenu);
register_shared("target_settings", show_setmenu);

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

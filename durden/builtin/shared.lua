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
	reset_target(wnd.source);
end

local function shared_resume(wnd)
	resume_target(wnd.source);
end

local function shared_suspend(wnd)
	suspend_target(wnd.source);
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
			image_texfilter(ctx.source, value);
		end
	},
-- scaler
-- positioning
};

-- Will be presented in order, not sorted. Make sure they come in order
-- useful:safe -> uncommon:dangerous to avoid the change of some quick
-- mispress doing something damaging.
local shared_actions = {
	{
		name = "suspend",
		label = "Suspend",
		eval = function() return true; end,
		shared_resume,
	},
	{
		name = "suspend",
		label = "Suspend",
		eval = function() return true; end,
		shared_suspend,
	},
	{
		name = "reset",
		label = "Reset",
		shared_reset,
	},
};

local function show_shmenu(wnd)
	if (wnd.dispatch) then
		launch_menu(wnd.wm, sf, false, "Action:");
	else
		launch_menu(wnd.wm, sf, false, "Action:");
	end
end

local function show_setmenu(wnd)
	launch_menu(wnd.wm, shared_settings, false, "Settings:");
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

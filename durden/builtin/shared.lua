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
	local wnd = active_display().selected;
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

local function run_input_label(wnd, v)
	if (not valid_vid(wnd.external, TYPE_FRAMESERVER)) then
		return;
	end

	local iotbl = {
		kind = "digital",
		label = v[1],
		active = true,
		devid = 8,
		subid = 8
	};

	target_input(wnd.external, iotbl);
	iotbl.active = false;
	target_input(wnd.external, iotbl);
end

local function build_labelmenu()
	local wnd = active_display().selected;
	if (not wnd or not wnd.input_labels or #wnd.input_labels == 0) then
		return;
	end

	local res = {};
	for k,v in ipairs(wnd.input_labels) do
		table.insert(res, {
			name = "input_" .. v[1],
			label = v[1],
			vref = v,
			handler = function()
				run_input_label(wnd, v);
			end
		});
	end

	return res;
end

local function build_bindmenu(wide)
	local wnd = active_display().selected;
	if (not wnd or not wnd.input_labels or #wnd.input_labels == 0) then
		return;
	end
	local bwt = gconfig_get("bind_waittime");
	local res = {};
	for k,v in ipairs(wnd.input_labels) do
		table.insert(res, {
			name = "target_input_" .. v[1],
			label = v[1],
			kind = "action",
			handler = function()
				tiler_bbar(active_display(),
					string.format("Bind: %s, hold desired combination.", v[1]),
					"keyorcombo", bwt, nil, SYSTEM_KEYS["cancel"],
					function(sym)
						wnd.labels[sym] = v[1];
					end
				);
			end
		});
	end

	return res;
end

local label_menu = {
	{
		name = "input",
		label = "Input",
		kind = "action",
		hint = "Input Label:",
		submenu = true,
		force = true,
		handler = build_labelmenu
	},
	{
		name = "target_input_localbind",
		label = "Local-Bind",
		kind = "action",
		hint = "Action:",
		submenu = true,
		force = true,
		handler = function() return build_bindmenu(true); end
	},
	{
		name = "target_input_globalbind",
		label = "Global-Bind",
		kind = "action",
		hint = "Action:",
		submenu = true,
		force = true,
		handler = function() return build_bindmenu(false); end
	}
};

local kbd_menu = {
	{
		name = "target_bind_utf8",
		kind = "action",
		label = "Bind UTF-8",
		eval = function(ctx)
			local sel = active_display().selected;
			return (sel and sel.u8_translation) and true or false;
		end,
		handler = grab_shared_function("bind_utf8")
	},
	{
		name = "target_keyboard_repeat",
		label = "Repeat Period",
		kind = "value",
		initial = function() return tostring(0); end,
		hint = "cps (0:disabled - 100)",
		validator = gen_valid_num(0, 100);
		handler = function()
			warning("set repeat rate");
		end
	},
	{
		name = "target_keyboard_delay",
		label = "Initial Delay",
		kind = "value",
		initial = function() return tostring(0); end,
		hint = "ms (0:disable - 1000)",
		handler = function()
			warning("set repeat delay");
		end
	},
};

local input_menu = {
	{
		name = "target_input_labels",
		label = "Labels",
		kind = "action",
		submenu = true,
		force = true,
		eval = function(ctx)
			local sel = active_display().selected;
			return sel and sel.input_labels and #sel.input_labels > 0;
		end,
		handler = label_menu
	},
	{
		name = "target_input_keyboard",
		label = "Keyboard",
		kind = "action",
		submenu = true,
		force = true,
		handler = kbd_menu
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
	local wnd = active_display().selected;
	if (wnd) then
		wnd.scalemode = mode;
		wnd.settings.scalemode = mode;
		wnd:resize(wnd.width, wnd.height);
	end
end

local function set_filterm(mode)
	local wnd = active_display().selected;
	if (mode and wnd) then
		wnd.settings.filtermode = mode;
		image_texfilter(wnd.canvas, mode);
	end
end

local filtermodes = {
	{
		name = "target_filter_none",
		label = "None",
		kind = "action",
		handler = function() set_filterm(FILTER_NONE); end
	},
	{
		name = "target_filter_linear",
		label = "Linear",
		kind = "action",
		handler = function() set_filterm(FILTER_LINEAR); end
	},
	{
		name = "target_filter_bilinear",
		label = "Bilinear",
		kind = "action",
		handler = function() set_filterm(FILTER_BILINEAR); end
	},
	{
		name = "target_filter_trilinear",
		label = "Trilinear",
		kind = "action",
		handler = function() set_filterm(FILTER_TRILINEAR); end
	}
};

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
		kind = "action",
		handler = function() set_scalef("stretch"); end
	},
	{
		name = "target_scale_aspect",
		label = "Aspect",
		kind = "action",
		handler = function() set_scalef("aspect"); end
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
	},
	{
		name = "Opacity",
		label = "Opacity",
		kind = "value",
		hint = "(0..1)",
		validator = gen_valid_num(0, 1),
		handler = function(ctx, val)
			local wnd = active_display().selected;
			if (wnd) then
				local opa = tonumber(val);
				wnd.settings.opacity = opa;
				blend_image(wnd.border, opa);
				blend_image(wnd.canvas, opa);
			end
		end
	},
-- good place to add advanced upscalers (xBR, CRT etc.)
};

local swap_menu = {
	{
		name = "window_swap_up",
		label = "Up",
		kind = "action",
		handler = grab_global_function("swap_up")
	},
	{
		name = "window_swap_down",
		label = "Down",
		kind = "action",
		handler = grab_global_function("swap_down")
	},
	{
		name = "window_swap_left",
		label = "Left",
		kind = "action",
		handler = grab_global_function("swap_left")
	},
	{
		name = "window_swap_right",
		label = "Right",
		kind = "action",
		handler = grab_global_function("swap_right")
	},
};

local window_menu = {
	{
		name = "window_prefix",
		label = "Tag",
		kind = "value",
		validator = function() return true; end,
		handler = function(ctx, val)
			local wnd = active_display().selected;
			if (wnd) then
				wnd:set_prefix(string.gsub(val, "\\", "\\\\"));
			end
		end
	},
	{
		name = "window_swap",
		label = "Swap",
		kind = "action",
		submenu = true,
		handler = swap_menu
	},
	{
		name = "window_reassign_byname",
		label = "Reassign",
		kind = "action",
		handler = grab_shared_function("reassign_wnd_bywsname");
	},
	{
		name = "window_tobackground",
		label = "Workspace-Background",
		kind = "action",
		handler = grab_shared_function("wnd_tobg");
	},
	{
		name = "window_migrate_display",
		label = "Migrate Display",
		kind = "action",
		handler = grab_shared_function("migrate_wnd_bydspname"),
		eval = function() return gconfig_get("display_simple") == false; end
	}
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
		name = "shared_input",
		label = "Input",
		submenu = true,
		kind = "action",
		force = true,
		handler = input_menu
	},
	{
		name = "shared_audio",
		label = "Audio",
		submenu = true,
		kind = "action",
		handler = audio_menu,
		force = true,
		eval = function(ctx)
			return active_display().selected and active_display().selected.source_audio
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
		name = "shared_window",
		label = "Window",
		kind = "action",
		submenu = true,
		force = true,
		handler = window_menu,
		Hint = "Window: "
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
	local bar = tiler_lbar(active_display(), function(ctx,msg,done,set)
		if (done and active_display().selected) then
			image_tracetag(active_display().selected.canvas, msg);
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

local sdisp = {
	input_label = function(wnd, source, tbl)
		if (not wnd.input_labels) then wnd.input_labels = {}; end
		if (#wnd.input_labels < 100) then
			table.insert(wnd.input_labels, {tbl.labelhint, tbl.idatatype});
		end
	end
};

function shared_dispatch()
	return sdisp;
end

-- the handler maneuver is to make sure that the callback that is triggered
-- matches the format in gfunc/shared so that we can reuse both for scripting
-- and for menu navigation.
local function show_shmenu(wnd)
	wnd = wnd == nil and active_display() or wnd;
	if (wnd == nil) then
		return;
	end

	local ctx = {
		list = merge_menu(wnd.no_shared and {} or shared_actions, wnd.actions),
		handler = wnd
	};

	launch_menu(wnd.wm, ctx, true, "Action:");
end

register_shared("target_actions", show_shmenu);

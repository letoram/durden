--
-- Menus and fglobal registration for functions that are shared between all
-- windows that has an external connection. Additional ones can be superimposed
-- based on archetype or even windows identification for entirely custom
-- handling (integrating senseye sensors for instance).
--

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
		gainv = gainv + (wnd.gain and wnd.gain or 1.0);
	end

	gainv = gainv < 0.0 and 0.0 or gainv;
	gainv = gainv > 1.0 and 1.0 or gainv;
	gainv = gainv * gconfig_get("global_gain");
	wnd.gain = gainv;
	audio_gain(wnd.source_audio, gainv, gconfig_get("gain_fade"));
end

local function run_input_label(wnd, v)
	if (not valid_vid(wnd.external, TYPE_FRAMESERVER)) then
		return;
	end

	local iotbl = {
		kind = "digital",
		label = v[1],
		translated = true,
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
			kind = "action",
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
		handler = build_labelmenu
	},
	{
		name = "target_input_localbind",
		label = "Local-Bind",
		kind = "action",
		hint = "Action:",
		submenu = true,
		handler = function() return build_bindmenu(true); end
	},
	{
		name = "target_input_globalbind",
		label = "Global-Bind",
		kind = "action",
		hint = "Action:",
		submenu = true,
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

local function mouse_lockfun(x, y, rx, ry, wnd)
--	print("forward input to target:", x, y, rx, ry, wnd);
end

local mouse_menu = {
	{
		name = "target_mouse_lock",
		label = "Mouse Lock",
		kind = "value",
		set = {"Disabled", "Constrain", "Center"},
		initial = function()
			local wnd = active_display().selected;
			return wnd.mouse_lock and wnd.mouse_lock or "Disabled";
		end,
		handler = function(ctx, val)
			local wnd = active_display().selected;
			if (val == "Disabled") then
				wnd.mouse_lock = nil;
				mouse_lockto(nil, nil);
			else
				wnd.mouse_lock = val;
				mouse_lockto(wnd.canvas, mouse_lockfun, val == "Center", wnd);
			end
		end
	},
	{
		name = "target_mouse_cursor",
		label = "Cursor Mode",
		kind = "value",
		set = {"default", "hidden"},
		initial = function()
			local wnd = active_display().selected;
			return wnd.cursor ==
				"hidden" and "hidden" or "default";
		end,
		handler = function(ctx, val)
			if (val == "hidden") then
				mouse_hide();
			else
				mouse_show();
			end
			active_display().selected.cursor = val;
		end
	},
	{
		name = "target_mouse_rlimit",
		label = "Rate Limit",
		kind = "value",
		set = {LBL_YES, LBL_NO},
		initial = function()
			return active_display().selected.rate_unlimited and LBL_NO or LBL_YES;
		end,
		handler = function(ctx, val)
			if (val == LBL_YES) then
				active_display().selected.rate_unlimited = false;
			else
				active_display().selected.rate_unlimited = true;
			end
		end
	},
};

local input_menu = {
	{
		name = "target_input_labels",
		label = "Labels",
		kind = "action",
		submenu = true,
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
		handler = kbd_menu
	},
	{
		name = "target_input_bindcustom",
		label = "Bind Custom",
		kind = "action",
		handler = grab_shared_function("bind_custom"),
	},
	{
		name = "target_input_mouse",
		label = "Mouse",
		kind = "action",
		submenu = true,
		handler = mouse_menu
	}
};

local audio_menu = {
	{
		name = "target_audio",
		label = "Toggle On/Off",
		kind = "action",
		handler = grab_shared_function("toggle_audio")
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
		wnd.filtermode = mode;
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
		handler = scalemodes
	},
	{
		name = "target_filtering",
		label = "Filtering",
		kind = "action",
		hint = "Basic Filter:",
		submenu = true,
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
	{
		name = "target_shader",
		label = "Shader",
		kind = "value",
		set = shader_list(),
		handler = function(ctx, val)
			local key = shader_getkey(val);
			if (key ~= nil) then
				shader_setup(active_display().selected, key);
			end
		end
	}
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
		eval = function()
			return gconfig_get("display_simple") == false and #(displays_alive()) > 1;
		end
	}
};

local function pastefun(wnd, msg)
	local dst = wnd.clipboard_out;

	if (not dst) then
		local dst = alloc_surface(1, 1);

-- this approach triggers an interesting bug that may be worthwhile to explore
--		wnd.clipboard_out = define_recordtarget(alloc_surface(1, 1),
--			wnd.external, "", {null_surface(1,1)}, {},
--			RENDERTARGET_DETACH, RENDERTARGET_NOSCALE, 0, function()
--		end);
		wnd.clipboard_out = define_nulltarget(wnd.external,
		function()
		end);
	end

	if (msg and string.len(msg) > 0) then
		target_input(wnd.clipboard_out, msg);
	end
end

local function clipboard_paste()
	local wnd = active_display().selected;
	pastefun(wnd, CLIPBOARD.globals[1]);
end

local function clipboard_paste_local()
	local wnd = active_display().selected;
	pastefun(wnd, CLIPBOARD:list_local(wnd.clipboard)[1]);
end

local function shorten(s)
	if (s == nil or string.len(s) == 0) then
		return "";
	end

	local r = string.gsub(
		string.gsub(s, " ", ""), "\n", ""
	);
	return r and r or "";
end

local function clipboard_histgen(wnd, lst)
	local res = {};
	for k, v in ipairs(lst) do
		table.insert(res, {
			name = "clipboard_lhist_" .. tostring(k),
			label = string.format("%d:%s", k, string.sub(shorten(v), 1, 20)),
			kind = "action",
			handler = function()
				local m1, m2 = dispatch_meta();
				pastefun(wnd, v);
				if (m1) then
					CLIPBOARD:set_global(v);
				end
			end
		});
	end
	return res;
end

local function clipboard_local_history()
	local wnd = active_display().selected;
	return clipboard_histgen(wnd, CLIPBOARD:list_local(wnd.clipboard));
end

local function clipboard_history()
	return clipboard_histgen(active_display().selected, CLIPBOARD.globals);
end

local clipboard_menu = {
	{
		name = "clipboard_paste",
		label = "Paste",
		kind = "action",
		eval = function() return valid_vid(
			active_display().selected.external, TYPE_FRAMESERVER);
		end,
		handler = clipboard_paste
	},
	{
		name = "clipboard_paste_local",
		label = "Paste-Local",
		kind = "action",
		eval = function()
		return valid_vid(
			active_display().selected.external, TYPE_FRAMESERVER);
		end,
		handler = clipboard_paste_local
	},
	{
		name = "clipboard_local_history",
		label = "History-Local",
		kind = "action",
		eval = function()
		return valid_vid(
			active_display().selected.external, TYPE_FRAMESERVER);
		end,
		submenu = true,
		handler = clipboard_local_history
	},
	{
		name = "clipboard_global_history",
		label = "History",
		kind = "action",
		submenu = true,
		eval = function()
		return valid_vid(
			active_display().selected.external, TYPE_FRAMESERVER);
		end,
		handler = clipboard_history
	}
};

local state_menu = {
	{
		name = "state_load",
		label = "Restore",
		kind = "action",
		submenu = true,
		eval = function()
			return false;
-- eval namespaces for matching state-id
-- tostring(active_display().selected.stateinf)
		end
	},
};

local function set_temporary(wnd, slot, val)
	print("set_temporary", wnd, slot, val);
end

local function list_values(wnd, ind, optslot, trigfun)
	local res = {};
	for k,v in ipairs(optslot.values) do
		table.insert(res, {
			handler = function()
				trigfun(wnd, ind, optslot, v);
			end,
			name = "coreopt_val_" .. v,
			kind = "action"
		});
	end
	return res;
end

local function list_coreopts(wnd, trigfun)
	local res = {};
	for k,v in ipairs(wnd.coreopt) do
		if (#v.values > 0 and v.description) then
			table.insert(res, {
				name = "coreopt_" .. v.description,
				kind = "action",
				submenu = true,
				handler = function()
					return list_values(wnd, k, v, trigfun);
				end
			});
		end
	end
	return res;
end

local opts_menu = {
	{
		name = "coreopt_set",
		label = "Set",
		kind = "action",
		submenu = true,
		eval = function()
			return active_display().selected.coreopt ~= nil;
		end,
		handler = function()
			list_coreopts(active_display().selected, set_temporary);
		end
	},
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
		handler = input_menu
	},
	{
		name = "shared_state",
		label = "State",
		submenu = true,
		kind = "ation",
		handler = state_menu,
		eval = function()
			local wnd = active_display().selected;
			return wnd.stateinf ~= nil;
		end
	},
	{
		name = "shared_clipboard",
		label = "Clipboard",
		submenu = true,
		kind = "action",
		eval = function()
			return active_display().selected and
				active_display().selected.clipboard_block == nil;
		end,
		handler = clipboard_menu
	},
	{
		name = "shared_audio",
		label = "Audio",
		submenu = true,
		kind = "action",
		handler = audio_menu,
		eval = function(ctx)
			return active_display().selected and active_display().selected.source_audio
		end
	},
	{
		name = "shared_video",
		label = "Video",
		kind = "action",
		submenu = true,
		handler = video_menu,
		hint = "Video:"
	},
	{
		name = "shared_window",
		label = "Window",
		kind = "action",
		submenu = true,
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
local show_shmenu;
show_shmenu = function(wnd)
	wnd = wnd and wnd or active_display().selected;

	if (wnd == nil) then
		return;
	end

	LAST_ACTIVE_MENU = show_shmenu;

	local ctx = {
		list = merge_menu(wnd.no_shared and {} or shared_actions, wnd.actions),
		handler = wnd
	};

	return launch_menu(active_display(), ctx, true, "Action:");
end

register_shared("paste_global", clipboard_paste);
register_shared("target_actions", show_shmenu);

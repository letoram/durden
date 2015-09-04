--
-- Globally available menus, settings and functions. All code here is just
-- boiler-plate mapping to engine- or support script functions.
--

local function global_valid01_uri(str)
	return true;
end

local function query_synch()
	local lst = video_synchronization();
	if (lst) then
		local res = {};
-- dynamically populated so we don't expose this globally at the moment
		for k,v in ipairs(lst) do
			res[k] = {
				name = "set_synch_" .. tostring(k),
				label = v,
				kind = "action",
				handler = function(ctx)
					video_synchronization(v);
				end
			};
		end
		return res;
	end
end

local dbg_dsp = {
	{
		name = "display_add_debug",
		eval = function() return gconfig_get("display_simple") == false; end,
		label = "Add Display",
		kind = "value",
		hint = "(name)",
		validator = function() return true; end,
		handler = function(ctx, val)
			display_simulate_add(val,
				200 + math.random(100), 200 + math.random(600));
		end
	},
	{
		name = "display_remove_debug",
		eval = function() return gconfig_get("display_simple") == false; end,
		label = "Remove Display",
		kind = "value",
		hint = "(name)",
		validator = function() return true; end,
		handler = function(ctx, val)
			display_simulate_remove(val);
		end
	}
};

-- DPMS toggle (force-on, force-off, toggle) / all or individual
-- ICC Profile (one, all)
local display_menu = {
	{
		name = "display_rescan",
		label = "Rescan",
		kind = "action",
		handler = function() video_displaymodes(); end
	},
	{
		name = "synchronization_strategies",
		label = "Synchronization",
		kind = "action",
		hint = "Synchronization:",
		submenu = true,
		force = true,
		handler = function() return query_synch(); end
	},
	{
		name = "display_cycle",
		label = "Cycle Active",
		kind = "action",
		eval = function() return gconfig_get("display_simple") == false; end,
		handler = grab_global_function("display_cycle")
	},
	{
		name = "display_debug",
		label = "Debug",
		kind = "action",
		eval = function() return DEBUGLEVEL > 0; end,
		submenu = true,
		force = true,
		handler = dbg_dsp
	},
};

local exit_query = {
{
	name = "shutdown_no",
	label = "No",
	kind = "action",
	handler = function() end
},
{
	name = "shutdown_yes",
	label = "Yes",
	kind = "action",
	dangerous = true,
		handler = function() shutdown(); end
	}
};

local reset_query = {
	{
		name = "reset_no",
		label = "No",
		kind = "action",
		handler = function() end
	},
	{
		name = "reset_yes",
		label = "Yes",
		kind = "action",
		dangerous = true,
		handler = function() system_collapse(APPLID); end
	},
};

local function query_dump()
	local bar = tiler_lbar(active_display(), function(ctx, msg, done, set)
		if (done) then
			zap_resource("debug/" .. msg);
			system_snapshot("debug/" .. msg);
		end
		return {};
	end);
	bar:set_label("filename (debug/):");
end

local debug_menu = {
	{
		name = "query_dump",
		label = "Dump",
		kind = "action",
		handler = query_dump
	},
	{
		name = "debug_console",
		label = "Console",
		kind = "action",
		handler = grab_global_function("debug_debugwnd")
	}
};

local system_menu = {
	{
		name = "shutdown",
		label = "Shutdown",
		kind = "action",
		submenu = true,
		force = true,
		hint = "Shutdown?",
		handler = exit_query
	},
	{
		name = "reset",
		label = "Reset",
		kind = "action",
		submenu = true,
		force = true,
		hint = "Reset?",
		handler = reset_query
	}
};

if (DEBUGLEVEL > 0) then
	table.insert(system_menu,{
		name = "debug",
		label = "Debug",
		kind = "action",
		submenu = true,
		force = true,
		hint = "Debug:",
		handler = debug_menu,
	});
end

local audio_menu = {
	{
		name = "toggle_audio",
		label = "Toggle On/Off",
		kind = "action",
		handler = grab_global_function("toggle_audio")
	},
	{
		name = "global_gain",
		label = "Global Gain",
		kind = "action",
		handler = grab_global_function("query_global_gain")
	},
	{
		name = "gain_pos10",
		label = "+10%",
		kind = "action",
		handler = function()
			grab_global_function("gain_stepv")(0.1);
		end
	},
	{
		name = "gain_neg10",
		label = "-10%",
		kind = "action",
		handler = function()
			grab_global_function("gain_stepv")(-0.1);
		end
	}
};

-- mouse_remember_position = true,

local mouse_menu = {
	{
		name = "mouse_sensitivity",
		kind = "value",
		label = "Sensitivity",
		force = true,
		hint = function() return "(0.01..10)"; end,
		validator = function(val)
			return gen_valid_num(0, 10)(val);
		end,
		initial = function()
			return tostring(gconfig_get("mouse_factor"));
		end,
		handler = function(ctx, val)
			val = tonumber(val);
			val = val < 0.01 and 0.01 or val;
			gconfig_set("mouse_factor", val);
			mouse_acceleration(val, val);
		end
	},
	{
		name = "mouse_hover_delay",
		kind = "value",
		label = "Hover Delay",
		force = true,
		hint = function() return "10..80"; end,
		validator = function(val)
			return gen_valid_num(0, 80)(val);
		end,
		initial = function()
			return tostring(gconfig_get("mouse_hovertime"));
		end,
		handler = function(ctx, val)
			val = math.ceil(tonumber(val));
			val = val < 10 and 10 or val;
			gconfig_set("mouse_hovertime", val);
			mouse_state().hover_ticks = val;
		end
	},
	{
		name = "mouse_remember_position",
		kind = "value",
		label = "Remember Position",
		set = {LBL_YES, LBL_NO},
		initial = function()
			return gconfig_get("mouse_remember_position") and LBL_YES or LBL_NO;
		end,
		handler = function(ctx, val)
			gconfig_set("mouse_remember_position", val == LBL_YES);
			mouse_state().autohide = val == LBL_YES;
		end
	},
	{
		name = "mouse_autohide",
		kind = "value",
		label = "Autohide",
		set = {LBL_YES, LBL_NO},
		initial = function()
			return gconfig_get("mouse_autohide") and LBL_YES or LBL_NO;
		end,
		handler = function(ctx, val)
			gconfig_set("mouse_autohide", val == LBL_YES);
			mouse_state().autohide = val == LBL_YES;
		end
	},
	{
		name = "mouse_hide_delay",
		kind = "value",
		label = "Autohide Delay",
		force = true,
		hint = function() return "40..400"; end,
		validator = function(val)
			return gen_valid_num(0, 400)(val);
		end,
		initial = function()
			return tostring(gconfig_get("mouse_hidetime"));
		end,
		handler = function(ctx, val)
			val = math.ceil(tonumber(val));
			val = val < 40 and 40 or val;
			gconfig_set("mouse_hidetime", val);
			mouse_state().hide_base = val;
		end
	},
	{
		name = "mouse_focus",
		kind = "value",
		label = "Focus Event",
		force = true,
		set = {"click", "motion", "hover", "none"},
		initial = function()
			return gconfig_get("mouse_focus_event");
		end,
		handler = function(ctx, val)
			gconfig_set("mouse_focus_event", val);
		end
	},
};

local input_menu = {
	{
		name = "input_rebind_basic",
		kind = "action",
		label = "Rebind Basic",
		handler = grab_global_function("rebind_basic")
	},
	{
		name = "input_rebind_custom",
		kind = "action",
		label = "Bind Custom",
		handler = grab_global_function("bind_custom")
	},
	{
		name = "input_rebind_meta",
		kind = "action",
		label = "Bind Meta",
		handler = grab_global_function("rebind_meta")
	},
	{
		name = "input_mouse_menu",
		kind = "action",
		label = "Mouse",
		submenu = true,
		force = true,
		handler = mouse_menu
	}
};

-- workspace actions:
-- 	layout (save [shallow, deep], load), display affinity,
-- 	reassign (if multiple displays), layout, shared

local function switch_ws_menu()
	local spaces = {};
	for i=1,10 do
		spaces[i] = {
			name = "switch_ws" .. tostring(i),
			kind = "action",
			label = tostring(i),
			handler = grab_global_function("switch_ws" .. tostring(i)),
		};
	end

	return spaces;
end

local workspace_layout_menu = {
	{
		name = "layout_float",
		kind = "action",
		label = "Float",
		handler = function()
			local space = active_display().spaces[active_display().space_ind];
			space = space and space:float() or nil;
		end
	},
	{
		name = "layout_tile",
		kind = "action",
		label = "Tile",
		handler = function()
			local space = active_display().spaces[active_display().space_ind];
			space = space and space:tile() or nil;
		end
	},
	{
		name = "layout_tab",
		kind = "action",
		label = "Tabbed",
		handler = function()
			local space = active_display().spaces[active_display().space_ind];
			space = space and space:tab() or nil;
		end
	},
	{
		name = "layout_vtab",
		kind = "action",
		label = "Tabbed Vertical",
		handler = function()
			local space = active_display().spaces[active_display().space_ind];
			space = space and space:vtab() or nil;
		end
	}
};

local function load_bg(fn)
	local space = active_display().spaces[active_display().space_ind];
	if (not space) then
		return;
	end

	load_image_asynch(fn, function(src, stat)
		if (stat.kind == "loaded") then
			if (valid_vid(space.background)) then
				delete_image(space.background);
			end
			space.background = src;
			space.background_name = fn;
			resize_image(src, space.wm.width, space.wm.client_height);
			link_image(src, space.anchor);
			show_image(src);
		else
			delete_image(src);
		end
	end);
end

local save_ws = {
	{
		name = "workspace_save_shallow",
		label = "Shallow",
		kind = "action",
		handler = grab_global_function("save_space_shallow")
	},
	{
		name = "workspace_save_deep",
		label = "Complete",
		kind = "action",
		handler = grab_global_function("save_space_deep")
	},
	{
		name = "workspace_save_drop",
		label = "Drop",
		kind = "action",
		eval = function()	return true; end,
		handler = grab_global_function("save_space_drop")
	}
};

local function set_ws_background()
	local imgfiles = {
	png = load_bg,
	jpg = load_bg,
	bmp = load_bg};
	browse_file({}, imgfiles, SHARED_RESOURCE, nil);
end

local function swap_ws_menu()
	local res = {};
	local wspace = active_display().spaces[active_display().space_ind];
	for i=1,10 do
		if (active_display().space_ind ~= i and active_display().spaces[i] ~= nil) then
			table.insert(res, {
				name = "workspace_swap",
				label = tostring(i),
				kind = "action",
				handler = function()
					grab_global_function("swap_ws" .. tostring(i))();
				end
			});
		end
	end
	return res;
end

local workspace_menu = {
	{
		name = "workspace_swap",
		label = "Swap",
		kind = "action",
		eval = function() return active_display():active_spaces() > 1; end,
		submenu = true,
		force = true,
		hint = "Swap:",
		handler = swap_ws_menu
	},
	{
		name = "workspace_layout",
		label = "Layout",
		kind = "action",
		submenu = true,
		force = true,
		hint = "Layout:",
		handler = workspace_layout_menu
	},
	{
		name = "workspace_rename",
		label = "Rename",
		kind = "action",
		handler = grab_global_function("rename_space")
	},
	{
		name = "workspace_background",
		label = "Background",
		kind = "action",
		handler = set_ws_background,
	},
	{
		name = "workspace_save",
		label = "Save",
		kind = "action",
		submenu = true,
		force = true,
		hint = "Save Workspace:",
		handler = save_ws
	},
	{
		name = "workspace_switch",
		label = "Switch",
		kind = "action",
		submenu = true,
		force = true,
		hint = "Switch To:",
		handler = switch_ws_menu
	},
	{
		name = "workspace_name",
		label = "Find Workspace",
		kind = "action",
		handler = function() grab_global_function("switch_ws_byname")(); end
	},
	{
		name = "workspace_wnd",
		label = "Find Tagged Window",
		kind = "action",
		handler = function() grab_global_function("switch_wnd_bytag")(); end
	},
	{
		name = "workspace_migrate",
		label = "Migrate Display",
		kind = "action",
		handler = grab_global_function("migrate_ws_bydspname"),
		eval = function() return gconfig_get("display_simple") == false; end
	}
};

local durden_visual = {
-- thickness is dependent on area, make sure the labels and
-- constraints update dynamically
	{
		name = "border_thickness",
		label = "Border Thickness",
		kind = "value",
		hint = function() return
			string.format("(0..%d)", gconfig_get("borderw")) end,
		validator = function(val)
			return gen_valid_num(0, gconfig_get("borderw"))(val);
		end,
		initial = function() return tostring(gconfig_get("bordert")); end,
		handler = function(ctx, val)
			local num = tonumber(val);
			gconfig_set("bordert", tonumber(val));
			active_display().rebuild_border();
			for k,v in pairs(active_display().spaces) do
				v:resize();
			end
		end
	},
	{
		name = "border_area",
		label = "Border Area",
		kind = "value",
		hint = "(0..20)",
		inital = function() return tostring(gconfig_get("borderw")); end,
		validator = gen_valid_num(0, 20),
		handler = function(ctx, val)
			gconfig_set("borderw", tonumber(val));
			active_display().rebuild_border();
			for k,v in pairs(active_display().spaces) do
				v:resize();
			end
		end
	},
	{
		name = "transition_speed",
		label = "Animation Speed",
		kind = "value",
		hint = "(1..100)",
		validator = gen_valid_num(1, 100),
		initial = function() return tostring(gconfig_get("transition")); end,
		handler = function(ctx, val)
			gconfig_set("transition", tonumber(val));
		end
	},
	{
		name = "transition_in",
		label = "In-Animation",
		kind = "value",
		set = {"none", "fade", "move-h", "move-v"},
		initial = function() return tostring(gconfig_get("ws_transition_in")); end,
		handler = function(ctx, val)
			gconfig_set("ws_transition_in", val);
		end
	},
	{
		name = "transition_out",
		label = "Out-Animation",
		kind = "value",
		set = {"none", "fade", "move-h", "move-v"},
		initial = function() return tostring(gconfig_get("ws_transition_out")); end,
		handler = function(ctx, val)
			gconfig_set("ws_transition_out", val);
		end
	},
};

local durden_workspace = {
	{
		name = "durden_ws_autodel",
		label = "Autodelete",
		kind = "value",
		set = {LBL_YES, LBL_NO},
		initial = function() return tostring(gconfig_get("ws_autodestroy")); end,
		handler = function(ctx, val)
			gconfig_set("ws_autodestroy", val == LBL_YES);
		end
	}
};

local durden_menu = {
	{
		name = "durden_visual",
		label = "Visual",
		kind = "action",
		submenu = true,
		force = true,
		hint = "Visual:",
		handler = durden_visual
	},
	{
		name = "durden_workspace",
		label = "Workspaces",
		kind = "action",
		submenu = true,
		force = true,
		hint = "Config Workspaces:",
		handler = durden_workspace
	}
};

local function imgwnd(fn)
	load_image_asynch(fn, function(src, stat)
		if (stat.kind == "loaded") then
			local wnd = active_display():add_window(src, {scalemode = "stretch"});
			string.gsub(fn, "\\", "\\\\");
			wnd:set_title("image:" .. fn);
		elseif (valid_vid(src)) then
			delete_image(src);
		end
	end);
end

local function dechnd(source, status)
	print("status.kind:", status.kind);
end

local function decwnd(fn)
	launch_decode(fn, function(source, status)
		if (status.kind == "terminated") then
			delete_image(source);
		elseif (status.kind == "connected") then
			local wnd = active_display():add_window(source);
			wnd.external = source;
			wnd:add_handler("resize", tile_changed);
			target_updatehandler(source, dechnd);
			tile_changed(wnd);
		end
	end);
end

local function browse_internal()
	local ffmts = {
	jpg = imgwnd,
	png = imgwnd,
	bmp = imgwnd};
-- Don't have a good way to query decode for extensions at the moment,
-- would be really useful in cases like this (might just add an info arg and
-- then export through message, coreopt or similar).
	for i,v in ipairs({"mp3", "flac", "wmv", "mkv", "avi", "asf", "flv",
		"mpeg", "mov", "mp4", "ogg"}) do
		ffmts[v] = decwnd;
	end

	browse_file({}, ffmts, SHARED_RESOURCE, nil);
end

local toplevel = {
	{
		name = "open",
		label = "Open",
		kind = "action",
		handler = query_uriopen
	},
	{
		name = "browse",
		label = "Browse",
		kind = "action",
		handler = browse_internal
	},
	{
		name = "launch",
		label = "Launch",
		kind = "action",
		eval = function() return #(list_targets()) > 0; end,
		handler = grab_global_function("query_launch")
	},
	{
		name = "global_menu",
		label = "Global Menu",
		kind = "action",
		invisible = true,
		handler = function()
			grab_global_function("global_actions")();
		end,
	},
	{
		name = "target_menu",
		label = "Window Menu",
		kind = "action",
		invisible = true,
		handler = function()
			grab_global_function("target_actions")
		end
	},
	{
		name = "workspace",
		label = "Workspace",
		kind = "action",
		submenu = true,
		force = true,
		hint = "Workspace:",
		handler = workspace_menu
	},
	{
		name = "display",
		label = "Display",
		kind = "action",
		submenu = true,
		force = true,
		hint = "Displays:",
		handler = display_menu
	},
	{
		name = "settings",
		label = "Config",
		kind = "action",
		submenu = true,
		force = true,
		hint = "settings:",
		handler = durden_menu
	},
	{
		name = "audio",
		label = "Audio",
		kind = "action",
		submenu = true,
		force = true,
		hint = "Audio:",
		handler = audio_menu
	},
	{
		name = "input",
		label = "Input",
		kind = "action",
		submenu = true,
		force = true,
		hint = "Input:",
		handler = input_menu
	},
	{
		name = "system",
		label = "System",
		kind = "action",
		submenu = true,
		force = true,
		hint = "System:",
		handler = system_menu
	},
};

global_actions = function(trigger_function)
	if (IN_CUSTOM_BIND) then
		return launch_menu(active_display(), {
			list = toplevel,
			trigger = trigger_function,
			show_invisible = true
		}, true, "Bind:");
	else
		return launch_menu(active_display(), {list = toplevel,
			trigger = trigger_function}, true, "Action:");
	end
end

register_global("global_actions", global_actions);

-- audio
register_global("audio_mute_all", audio_mute);

--display
register_global("display_rescan", display_rescan);
register_global("query_synch", display_synch);

--system
register_global("query_exit", query_exit);
register_global("exit", shutdown);
register_global("query_reset", query_reset);
register_global("reset", function() system_collapse(APPLID); end);

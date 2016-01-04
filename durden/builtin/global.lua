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
		name = "display_dump",
		eval = function() return gconfig_get("display_simple") == false; end,
		label = "Dump",
		kind = "action",
		handler = function() display_manager_dump(); end
	},
	{
		name = "display_add_debug",
		eval = function() return gconfig_get("display_simple") == false; end,
		label = "Add Display",
		kind = "value",
		hint = "(name)",
		validator = function() return true; end,
		handler = function(ctx, val)
			display_simulate();
			display_add(val,
				200 + math.random(100), 200 + math.random(600), true);
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
			display_remove(val, true);
		end
	}
};

local function query_dispmenu(ind)
	local modes = video_displaymodes(ind);
	if (modes and #modes > 0) then
		local mtbl = {};
		local got_dynamic = true;
		for k,v in ipairs(modes) do
			if (v.dynamic) then
				got_dynamic = true;
			else
				table.insert(mtbl, {
					name = "set_res_" .. tostring(k),
					label = string.format("%d*%d, %d bits @%d Hz",
						v.width, v.height, v.depth, v.refresh),
					kind = "action",
					handler = function() display_ressw(ind, v); end
				});
			end
		end
		return mtbl;
	end
end

local function gen_disp_menu(disp)
	return {
		{
		name = "disp_menu_" .. tostring(disp.name) .. "state",
		eval = function() return disp.primary ~= true; end,
		label = "Toggle On/Off",
		kind = "action",
		handler = function() warning("toggle display"); end
		},
		{
		name = "disp_menu_" .. tostring(disp.name) .. "state",
		label = "Resolution",
		kind = "action",
		submenu = true,
		force = true,
		handler = function() return query_dispmenu(disp.id); end
		}
	};
end

local function query_displays()
	local res = {};
	for k,v in pairs(all_displays()) do
		if (string.len(v.name) > 0) then
			table.insert(res, {
				name = "disp_menu_" .. tostring(k),
				label = v.name,
				kind = "action",
				submenu = true,
				force = true,
				handler = function() return gen_disp_menu(v); end
			});
		end
	end
	return res;
end

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
		name = "display_list",
		label = "Displays",
		kind = "action",
		submenu = true,
		force = true,
		handler = function() return query_displays(); end
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
		name = "display_share",
		label = "Share",
		kind = "value",
		hint = "Arguments (host=ip:port=5900:password=xxx)",
		validator = function() return true; end,
		eval = function()
			return gconfig_get("display_simple") == false and
				string.find(FRAMESERVER_MODES, "encode") ~= nil;
		end,
		handler = function(ctx, args)
			display_share("protocol=vnc:" .. (args and args or ""), "");
-- FIXME: meta_1 and query for individual values instead (host,
-- password, samplerate etc. then just push as table to display_share
		end
	},
	{
		name = "display_record",
		label = "Record",
		kind = "value",
		hint = "arguments",
		validator = function() return true; end,
		eval = function()
			return gconfig_get("display_simple") == false and
				string.find(FRAMESERVER_MODES, "encode") ~= nil;
		end,
		handler = function(ctx, args)
			display_share("", args);
-- FIXME: meta_1 and query for options instead (need a generic
-- function for that really)
		end
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
		handler = function() system_collapse(); end
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
	},
-- for testing fallback application handover
	{
		name = "debug_broken",
		label = "Broken Call (Crash)",
		kind = "action",
		handler = function() does_not_exist(); end
	},
	{
		name = "debug_stall",
		label = "Frameserver Debugstall",
		kind = "value",
		eval = function() return frameserver_debugstall ~= nil; end,
		validator = gen_valid_num(0, 100),
		handler = function(ctx,val) frameserver_debugstall(tonumber(val)); end
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
		name = "mouse_hardlock",
		kind = "value",
		label = "Hard Lock",
		set = {LBL_YES, LBL_NO},
		initial = function()
			return gconfig_get("mouse_hardlock") and LBL_YES or LBL_NO;
		end,
		handler = function(ctx, val)
			gconfig_set("mouse_hardlock", val == LBL_YES);
			toggle_mouse_grab(val == LBL_YES and MOUSE_GRABON or MOUSE_GRABOFF);
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

local function list_keymaps()
	local km = SYMTABLE:list_keymaps();
	local kmm = {};
	for k,v in ipairs(km) do
		table.insert(kmm, {
			name = "keymap_" .. tostring(k),
			kind = "action",
			label = v,
			handler = function() SYMTABLE:load_keymap(v); end
		});
	end
	return kmm;
end

local keyb_menu = {
	{
		name = "keyboard_repeat",
		label = "Repeat Period",
		kind = "value",
		initial = function() return tostring(gconfig_get("kbd_period")); end,
		hint = "cps (0:disabled - 100)",
		validator = gen_valid_num(0, 100);
		handler = function(ctx, val)
			val = tonumber(val);
			gconfig_set("kbd_period", val);
			iostatem_repeat(val, nil);
		end
	},
	{
		name = "keyboard_delay",
		label = "Initial Delay",
		kind = "value",
		initial = function() return tostring(gconfig_get("kbd_delay")); end,
		hint = "ms (0:disable - 1000)",
		handler = function(ctx, val)
			val = tonumber(val);
			gconfig_set("kbd_delay", val);
			iostatem_repeat(nil, val);
		end
	},
	{
		name = "keyboard_maps",
		label = "Map",
		kind = "action",
		submenu = true,
		eval = function() return #(SYMTABLE:list_keymaps()) > 0; end,
		handler = list_keymaps
	},
	{
		name = "keyboard_reset",
		label = "Reset",
		kind = "action",
		handler = function() SYMTABLE:reset(); end
	}
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
		name = "input_unbind",
		kind = "action",
		label = "Unbind",
		handler = grab_global_function("unbind_combo")
	},
	{
		name = "input_bind_utf8",
		kind = "action",
		label = "Bind UTF-8",
		handler = grab_global_function("bind_utf8")
	},
	{
		name = "input_keyboard_menu",
		kind = "action",
		label = "Keyboard",
		submenu = true,
		force = true,
		handler = keyb_menu
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
	local m1, m2 = dispatch_meta();
	space:set_background(fn, m1);
end

local save_ws = {
	{
		name = "workspace_save_shallow",
		label = "Shallow",
		kind = "action",
		handler = grab_global_function("save_space_shallow")
	},
--	{
--		name = "workspace_save_deep",
--		label = "Complete",
--		kind = "action",
--		handler = grab_global_function("save_space_deep")
--	},
--	{
--		name = "workspace_save_drop",
--		label = "Drop",
--		kind = "action",
--		eval = function()	return true; end,
--		handler = grab_global_function("save_space_drop")
--	}
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
		label = "Tagged Window",
		kind = "action",
		handler = function() grab_global_function("switch_wnd_bytag")(); end
	},
	{
		name = "workspace_migrate",
		label = "Migrate Display",
		kind = "action",
		handler = grab_global_function("migrate_ws_bydspname"),
		eval = function()
			return gconfig_get("display_simple") == false and #(displays_alive()) > 1;
		end
	}
};

local durden_font = {
	{
		name = "durden_font_sz",
		label = "Size",
		kind = "value";
		validator = gen_valid_num(1, 100),
		initial = function() return tostring(gconfig_get("font_sz")); end,
		handler = function(ctx, val)
			gconfig_set("font_sz", tonumber(val));
		end
	},
	{
		name = "durden_font_hinting",
		label = "Hinting",
		kind = "value",
		validator = gen_valid_num(0, 3);
		initial = function() return gconfig_get("font_hint"); end,
		handler = function(ctx, val)
			gconfig_set("font_hint", tonumber(val));
		end
	},
	{
		name = "durden_font_name",
		label = "Font",
		kind = "value",
		set = function()
			local set = glob_resource("*", SYS_FONT_RESOURCE);
			set = set ~= nil and set or {};
			return set;
		end,
		initial = function() return gconfig_get("font_def"); end,
		handler = function(ctx, val)
			gconfig_set("font_def", val);
		end
	}
};

local durden_visual = {
-- thickness is dependent on area, make sure the labels and
-- constraints update dynamically
	{
		name = "default_font",
		label = "Font",
		kind = "action",
		submenu = true,
		handler = durden_font
	},
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
	},
	{
		name = "durden_ws_defmode",
		label = "Default Mode",
		kind = "value",
		set = {"tile", "tab", "vtab", "float"},
		initial = function() return tostring(gconfig_get("ws_default")); end,
		handler = function(ctx, val)
			gconfig_set("ws_default", val);
		end
	},
	{
		name = "durden_ws_autoadopt",
		label = "Autoadopt",
		kind = "value",
		set = {LBL_YES, LBL_NO},
		eval = function() return gconfig_get("display_simple") == false; end,
		initial = function() return tostring(gconfig_get("ws_autoadopt")); end,
		handler = function(ctx, val)
			gconfig_set("ws_autoadopt", val == LBL_YES);
		end
	}
};

local durden_system = {
	{
		name = "system_connpath",
		label = "Connection Path",
		kind = "value",
		validator = function(num) return true; end,
		initial = function() local path = gconfig_get("extcon_path");
			return path == "" and "[disabled]" or path;
		end,
		handler = function(ctx, val)
			if (valid_vid(INCOMING_ENDPOINT)) then
				delete_image(INCOMING_ENDPOINT);
				INCOMING_ENDPOINT = nil;
			end
			gconfig_set("extcon_path", val);
			new_connection();
		end
	}
};

local config_terminal = {
	{
		name = "terminal_font_sz",
		label = "Font Size",
		kind = "value",
		validator = gen_valid_num(1, 100),
		initial = function() return tostring(gconfig_get("term_font_sz")); end,
		handler = function(ctx, val)
			gconfig_set("term_font_sz", tonumber(val));
		end
	},
	{
		name = "terminal_bgalpha",
		label = "Background Alpha",
		kind = "value",
		hint = "(0..1)",
		validator = gen_valid_float(0, 1),
		initial = function() return tostring(gconfig_get("term_opa")); end,
		handler = function(ctx, val)
			gconfig_set("term_opa", tonumber(val));
		end
	},
	{
		name = "terminal_hinting",
		label = "Font Hinting",
		kind = "value",
		set = {"light", "mono", "none"},
		initial = function() return gconfig_get("term_font_hint"); end,
		handler = function(ctx, val)
			gconfig_set("term_hint", tonumber(val));
		end
	},
-- should replace with "font browser"
	{
		name = "terminal_font",
		label = "Font Name",
		kind = "value",
		set = function()
			local set = glob_resource("*", SYS_FONT_RESOURCE);
			set = set ~= nil and set or {};
			table.insert(set, "BUILTIN");
			return set;
		end,
		initial = function() return gconfig_get("term_font"); end,
		handler = function(ctx, val)
			gconfig_set("term_font", val == "BUILTIN" and "" or val);
		end
	}
};

local config_menu = {
	{
		name = "config_visual",
		label = "Visual",
		kind = "action",
		submenu = true,
		force = true,
		hint = "Visual:",
		handler = durden_visual
	},
	{
		name = "config_workspaces",
		label = "Workspaces",
		kind = "action",
		submenu = true,
		force = true,
		hint = "Config Workspaces:",
		handler = durden_workspace
	},
	{
		name = "config_system",
		label = "System",
		kind = "action",
		submenu = true,
		force = true,
		hint = "Config System:",
		handler = durden_system
	},
	{
		name = "config_terminal",
		label = "Terminal",
		kind = "action",
		submenu = true,
		force = true,
		eval = function()
			return string.match(FRAMESERVER_MODES, "terminal") ~= nil;
		end,
		handler = config_terminal
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
	local vid = launch_decode(fn, function() end);
	if (valid_vid(vid)) then
		durden_launch(vid, fn, "decode");
	end
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

local function run_uri(val, feedmode)
	local vid = launch_avfeed(val, feedmode);
	if (valid_vid(vid)) then
		durden_launch(vid, "", feedmode);
	end
end

local function get_remstr(val)
	local sp = string.split(val, "@");
	if (sp == nil or #sp == 1) then
		return "host=" .. val;
	end

	local base = "";
	local cred = string.split(sp[1], ":");
	if (cred and #cred == 2) then
		base = string.format("user=%s:password=%s:", cred[1], cred[2]);
	else
		base = string.format("password=%s:", sp[1]);
	end

	local disp = string.split(sp[2], "+");
	if (disp and #disp == 2 and tonumber(disp[2])) then
		local num = tonumber(disp[2]);
		base = string.format("%shost=%s:port=%d", base, disp[1], num);
	else
		base = string.format("%shost=%s", base, disp[1]);
	end

	return base;
end

function spawn_terminal()
	local bc = gconfig_get("term_bgcol");
	local fc = gconfig_get("term_fgcol");
	local cp = gconfig_get("extcon_path");

	local lstr = string.format(
		"font_hint=%s:font=[ARCAN_FONTPATH]/%s:"..
		"font_sz=%d:bgalpha=%d:bgr=%d:bgg=%d:bgb=%d:fgr=%d:fgg=%d:fgb=%d:%s",
		gconfig_get("term_font_hint"), gconfig_get("term_font"),
		gconfig_get("term_font_sz"),
		gconfig_get("term_opa") * 255.0 , bc[1], bc[2], bc[3],
		fc[1], fc[2],fc[3], (cp and string.len(cp) > 0) and
			("env=ARCAN_CONNPATH="..cp) or ""
	);

	if (not gconfig_get("term_autosz")) then
		lstr = lstr .. string.format(":cell_w=%d:cell_h=%d",
			gconfig_get("term_cellw"), gconfig_get("term_cellh"));
	end

	local vid = launch_avfeed(lstr, "terminal");
	if (valid_vid(vid)) then
		local wnd = durden_launch(vid, "", "terminal");
		extevh_default(vid, {
			kind = "registered", segkind = "terminal", title = "", guid = 1});
		wnd.space:resize();
	else
		active_display():message( "Builtin- terminal support broken" );
	end
end

local uriopen_menu = {
{
	name = "uriopen_terminal",
	label = "Terminal",
	kind = "action",
	hint = "(m1_accept for args)",
	eval = function()
		return string.match(FRAMESERVER_MODES, "terminal") ~= nil;
	end,
	handler = spawn_terminal
},
{
	name = "uriopen_remote",
	label = "Remote Desktop",
	kind = "value",
	hint = "(user:pass@host+port)",
	validator = function() return true; end,
	eval = function()
		return string.match(FRAMESERVER_MODES, "remoting") ~= nil;
	end,
	handler = function(ctx, val)
		local vid = launch_avfeed(get_remstr(val), "remoting");
		durden_launch(vid, "", "remoting");
	end;
},
{
	name = "uriopen_decode",
	label = "Media URL",
	kind = "value",
	hint = "(protocol://user:pass@host:port)",
	validator = function() return true; end,
	eval = function()
		return string.match(FRAMESERVER_MODES, "decode") ~= nil;
	end,
	handler = function(ctx, val)
		run_uri(val, "decode");
	end
},
{
	name = "uriopen_avfeed",
	label = "AV Feed",
	kind = "action",
	hint = "(m1_accept for args)",
	eval = function()
		return string.match(FRAMESERVER_MODES, "avfeed") ~= nil;
	end,
	handler = function(ctx, val)
		local m1, m2 = dispatch_meta();
		if (m1) then
			query_args( function(argstr)
			local vid = launch_avfeed(argstr, "avfeed");
			durden_launch(vid, "", "avfeed");
			end);
		else
			local vid = launch_avfeed("", "avfeed");
			durden_launch(vid, "", "avfeed");
		end
	end
}
};

local toplevel = {
	{
		name = "open",
		label = "Open",
		kind = "action",
		submenu = true,
		force = true,
		eval = function() return #uriopen_menu; end,
		handler = uriopen_menu
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
		hint = "Config:",
		handler = config_menu
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

function get_global_menu()
	return toplevel;
end

local global_actions = nil;
global_actions = function(trigger_function)
	LAST_ACTIVE_MENU = global_actions;

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
register_global("spawn_terminal", spawn_terminal);

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

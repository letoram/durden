-- Copyright: 2015, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: Main setup for the Arcan/Durden desktop environment

-- Global used to track input events that should be aligned to clock
-- tick for rate-limit and timing purposes
EVENT_SYNCH = {};

function durden(argv)
	system_load("mouse.lua")(); -- mouse gestures
	system_load("gconf.lua")(); -- configuration management
	system_load("suppl.lua")(); -- convenience functions
	system_load("bbar.lua")(); -- input binding
	system_load("keybindings.lua")(); -- static key configuration
	system_load("tiler.lua")(); -- window management
	system_load("browser.lua")(); -- quick file-browser
	system_load("iostatem.lua")(); -- input repeat delay/period
	system_load("display.lua")(); -- multidisplay management
	system_load("extevh.lua")(); -- handlers for external events
	system_load("shdrmgmt.lua")(); -- shader format parser, builder
	CLIPBOARD = system_load("clipboard.lua")(); -- clipboard filtering / mgmt

-- functions exposed to user through menus, binding and scripting
	system_load("fglobal.lua")(); -- tiler- related global
	system_load("builtin/debug.lua")(); -- global event viewer
	system_load("builtin/global.lua")(); -- desktop related global
	system_load("builtin/shared.lua")(); -- shared window related global

-- can't work without a detected keyboard
	if (not input_capabilities().translated) then
		warning("arcan reported no available translation capable devices "
			.. "(keyboard), cannot continue without one.\n");
		return shutdown("", EXIT_FAILURE);
	end

	SYMTABLE = system_load("symtable.lua")();
	SYMTABLE:load_translation();

	if (gconfig_get("mouse_hardlock")) then
		toggle_mouse_grab(MOUSE_GRABON);
	end

	if (gconfig_get("mouse_mode") == "native") then
		mouse_setup_native(load_image("cursor/default.png"), 0, 0);
	else
-- 65535 is special in that it will never be returned as 'max current image order'
		mouse_setup(load_image("cursor/default.png"), 65535, 1, true, false);
	end
	display_manager_init();

-- this opens up the 'durden' external listening point, removing it means
-- only user-input controlled execution through configured database and open/browse
	local cp = gconfig_get("extcon_path");
	if (cp ~= nil and string.len(cp) > 0) then
		new_connection();
	end

-- unsetting these values will prevent all external communication that is not
-- using the nonauth- connection or regular input devices
	local sbar_fn = gconfig_get("status_path");
	if (sbar_fn ~= nil and string.len(sbar_fn) > 0) then
		zap_resource(sbar_fn);
		STATUS_CHANNEL = open_nonblock(sbar_fn);
	end

	local cchan_fn = gconfig_get("control_path");
	if (cchan_fn ~= nil and string.len(cchan_fn) > 0) then
		zap_resource(cchan_fn);
		CONTROL_CHANNEL = open_nonblock(cchan_fn);
	end

-- preload cursor states
	mouse_add_cursor("drag", load_image("cursor/drag.png"), 0, 0); -- 7, 5);
	mouse_add_cursor("grabhint", load_image("cursor/grabhint.png"), 0, 0); --, 7, 10);
	mouse_add_cursor("rz_diag_l", load_image("cursor/rz_diag_l.png"), 0, 0); --, 6, 5);
	mouse_add_cursor("rz_diag_r", load_image("cursor/rz_diag_r.png"), 0, 0); -- , 6, 6);
	mouse_add_cursor("rz_down", load_image("cursor/rz_down.png"), 0, 0); -- 5, 13);
	mouse_add_cursor("rz_left", load_image("cursor/rz_left.png"), 0, 0); -- 0, 5);
	mouse_add_cursor("rz_right", load_image("cursor/rz_right.png"), 0, 0); -- 13, 5);
	mouse_add_cursor("rz_up", load_image("cursor/rz_up.png"), 0, 0); -- 5, 0);

-- load saved keybindings
	dispatch_load();
	iostatem_init();

-- hook some API functions for debugging purposes
	if (DEBUGLEVEL > 0) then
		local oti = target_input;
		target_input = function(dst, tbl)
			if (active_display().debug_console) then
				active_display().debug_console:add_input(tbl, dst);
			end
			oti(dst, tbl);
		end
	end

-- just used for quick documentation work, traverses the menu tree and writes
-- to stdout, does not yet handle shared or archetype- specific menus
	if (argv[1] == "dump_menus") then
		for k,v in ipairs(get_menu_tree(get_global_menu())) do
			print(v);
		end
		return shutdown();
	end
end

-- need these event handlers here since it ties together modules that should
-- be separated code-wise, as we want tiler- and other modules to be reusable
-- in less complex projects
local function tile_changed(wnd, neww, newh, efw, efh)
	if (not neww or not newh) then
		return;
	end

	if (neww > 0 and newh > 0) then
		target_displayhint(wnd.external, neww, newh);
		if (valid_vid(wnd.titlebar_id)) then
			target_displayhint(wnd.titlebar_id,
				wnd.width - wnd.border_w * 2, gconfig_get("tbar_sz"));
		end
	end
end

-- there is a ton of "per window" input state when it comes to everything from
-- active translation tables, to diacretic traversals, to repeat-rate and
-- active analog/digital devices.
local function sel_input(wnd)
	local cnt = 0;
	SYMTABLE:translation_overlay(wnd.u8_translation);
	iostatem_repeat(
		wnd.kbd_period and wnd.kbd_period or
		gconfig_get("kbd_period"), wnd.kbd_delay and wnd.kbd_delay or
		gconfig_get("kbd_delay")
	);
end

local function desel_input(wnd)
	SYMTABLE:translation_overlay({});
	iostatem_repeat(gconfig_get("kbd_period"), gconfig_get("kbd_delay"));
	mouse_switch_cursor("default");
end

function durden_launch(vid, title, prefix)
	if (not valid_vid(vid)) then
		return;
	end
	local wnd = active_display():add_window(vid);

-- local keybinding->utf8 overrides, we map this to SYMTABLE
	wnd.u8_translation = {};

-- window aesthetics
	wnd:set_title(title and title or "?");
	wnd:set_prefix(prefix);
	wnd:add_handler("resize", tile_changed);
	wnd:add_handler("select", sel_input);
	wnd:add_handler("deselect", desel_input);
	shader_setup(wnd, wnd.shkey and wnd.shkey or "DEFAULT");
	show_image(vid);

-- may use this function to launch / create some internal window that don't
-- need all the external dispatch stuff, so make sure
	if (valid_vid(vid, TYPE_FRAMESERVER)) then
		wnd.dispatch = shared_dispatch();
		wnd.external = vid;
		extevh_register_window(vid, wnd);
		EVENT_SYNCH[wnd.canvas] = {
			queue = {},
			target = vid
		};
	end

	return wnd;
end

-- recovery from crash is handled just like newly launched windows, one
-- big caveat though, these are attached to WORLDID but in the multidisplay
-- setup we have another attachment.
function durden_adopt(vid, kind, title, parent)
	local ap = display_attachment();
	if (ap ~= nil) then
		rendertarget_attach(ap, vid, RENDERTARGET_DETACH);
	end

	if (valid_vid(parent)) then
		if (kind == "clipboard") then
			if (swm[parent] ~= nil) then
				swm[parent].clipboard = vid;
				target_updatehandler(vid, function(source, status)
					clipboard_event(swm[parent], source, status);
				end);
			else
				delete_image(vid);
			end
		else
			durden_launch(vid, title);
		end
	else
		durden_launch(vid, title);
	end
end

-- global scope here as we refer to it in builtin/global.lua
function new_connection(source, status)
	if (status == nil or status.kind == "connected") then
		INCOMING_ENDPOINT = target_alloc(
			gconfig_get("extcon_path"), new_connection);
		image_tracetag(INCOMING_ENDPOINT, "nonauth_connection");
		if (status) then
			durden_launch(source, "external", "");
		end
	end
end

--
-- text/line command protocol for doing status bar updates, etc.
-- as this grows, move into its own separate module.
--
function poll_status_channel()
	local line = STATUS_CHANNEL:read();
	if (line == nil or string.len(line) == 0) then
		return;
	end

	local cmd = string.split(line, ":");
	cmd = cmd == nil and {} or cmd;
	local fmt = string.format("%s \\#ffffff", gconfig_get("font_str"));

	if (cmd[1] == "status_1") then
-- escape control characters so we don't get nasty \f etc. commands
		local vid = render_text({fmt, msg});
		if (valid_vid(vid)) then
			active_display():update_statusbar({}, vid);
		end
	else
		dispatch_symbol(cmd[1]);
	end
end

function poll_control_channel()
	local line = CONTROL_CHANNEL:read();
	if (line == nil or string.len(line) == 0) then
		return;
	end

	local elem = string.split(line, ":");

-- hotplug event
	if (elem[1] == "rescan_displays") then
		video_displaymodes();

	elseif (elem[1] == "screenshot") then
		local rt = active_display(true);
		if (valid_vid(rt) and elem[2]) then
			save_screenshot(elem[2], FORMAT_PNG, rt);
		end
	end
end

local mid_c = 0;
local mid_v = {0, 0};
function durden_input(iotbl, fromim)
	if (DEBUGLEVEL > 2 and active_display().debug_console) then
		active_display().debug_console:add_input(iotbl);
	end

	if (not fromim) then
		local it = iostatem_input(iotbl);
		if (it) then
			for k,v in ipairs(it) do
				durden_input(v, true);
			end
		end
	end

	if (iotbl.source == "mouse") then
		if (iotbl.kind == "digital") then
			mouse_button_input(iotbl.subid, iotbl.active);
		else
			mid_v[iotbl.subid+1] = iotbl.samples[1];
			mid_c = mid_c + 1;

			if (mid_c == 2) then
				mouse_absinput(mid_v[1], mid_v[2]);
				mid_c = 0;
			end
		end

	elseif (iotbl.translated) then
		local sym, lutsym = SYMTABLE:patch(iotbl);
		local sel = active_display().selected;
-- all input and symbol lookup paths go through this routine (in fglobal.lua)
		local ok, lutsym = dispatch_lookup(iotbl, sym , active_display().input_lock);
		if (ok or not sel) then
			return;
		end

		if (sel.bindings and sel.bindings[sym]) then
			sel.bindings[sym](sel);

		elseif (sel.key_input) then
			sel:key_input(sym, iotbl);

		elseif (valid_vid(sel.external, TYPE_FRAMESERVER)) then
			iotbl.label = sel.labels[lutsym];
			target_input(sel.external, iotbl);
		end
	end
end

function durden_shutdown()
	SYMTABLE:store_translation();
	gconfig_shutdown();
	if (STATUS_CHANNEL) then
		zap_resource(gconfig_get("status_path"));
	end
	if (CONTROL_CHANNEL) then
		zap_resource(gconfig_get("control_path"));
	end
end

local function flush_pending()
	for k,v in pairs(EVENT_SYNCH) do
		if (valid_vid(v.target)) then
			if (v.queue) then
				for i,j in ipairs(v.queue) do
					target_input(v.target, j);
				end
				v.queue = {};
			end
			if (v.pending and #v.pending > 0) then
				for i,j in ipairs(v.pending) do
					target_input(v.target, j);
				end
				v.pending = nil;
			end
		end
	end
end

function durden_clock_pulse(n)
	local tt = iostatem_tick();
	if (tt) then
		for k,v in ipairs(tt) do
			durden_input(v, true);
		end
	end

--	if (CLOCK % 100) then (quick and dirty leak check)
--		print(current_context_usage());
--	end

	flush_pending();
	mouse_tick(1);
	display_tick();

-- don't do this too often, no reason to..
	if (CLOCK % 4 == 0) then
		if (STATUS_CHANNEL) then
			poll_status_channel();
		end

		if (CONTROL_CHANNEL) then
			poll_control_channel();
		end
	end
end

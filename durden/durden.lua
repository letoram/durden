-- Copyright: 2015, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: Main setup for the Arcan/Durden desktop environment

-- Every connection can get a set of additional commands and configurations
-- based on what type it has. Supported ones are registered into this table.
-- init, bindings, settings, commands
--
archetypes = {};

function durden()
	system_load("mouse.lua")(); -- mouse gestures
	system_load("gconf.lua")(); -- configuration management
	system_load("suppl.lua")(); -- convenience functions
	system_load("bbar.lua")(); -- input binding
	system_load("keybindings.lua")(); -- static key configuration
	system_load("tiler.lua")(); -- window management
	system_load("browser.lua")(); -- quick file-browser
	system_load("iostatem.lua")(); -- input repeat delay/period
	system_load("display.lua")(); -- multidisplay management
	system_load("shdrmgmt.lua")(); -- shader format parser, builder

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

-- load custom special subwindow handlers
	local res = glob_resource("atypes/*.lua", APPL_RESOURCE);
	if (res ~= nil) then
		for k,v in ipairs(res) do
			local tbl = system_load("atypes/" .. v, false);
			tbl = tbl and tbl() or nil;
			if (tbl and tbl.atype) then
				archetypes[tbl.atype] = tbl;
			end
		end
	end

	display_manager_init();
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

-- this opens up the 'durden' external listening point, removing it means
-- only user-input controlled execution
	local cp = gconfig_get("extcon_path");
	if (cp ~= nil and string.len(cp) > 0) then
		new_connection();
	end

-- unsetting these values will prevent all external communication that is not
-- via the nonauth- connection or regular input devices
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

	register_global("spawn_terminal", spawn_terminal);
	register_global("launch_bar", query_launch);

-- load saved keybindings
	dispatch_load();
	iostatem_init();
end

local function tile_changed(wnd, neww, newh, efw, efh)
	if (not neww or not newh) then
		return;
	end

	if (neww > 0 and newh > 0) then
		target_displayhint(wnd.external, neww, newh);
	end
end

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
end

function durden_launch(vid, title, prefix)
	if (not valid_vid(vid)) then
		return;
	end
	local wnd = active_display():add_window(vid);
	wnd.external = vid;
	wnd.u8_translation = {};
	wnd:set_title(title and title or "?");
	wnd:set_prefix(prefix);
	wnd:add_handler("resize", tile_changed);
	wnd:add_handler("select", sel_input);
	wnd:add_handler("deselect", desel_input);
	show_image(vid);
	wnd.dispatch = shared_dispatch();
	reg_window(wnd, vid);
	shader_setup(wnd, wnd.shkey and wnd.shkey or "noalpha");
end

-- recovery from crash is handled just like newly launched windows
function durden_adopt(vid, kind, title)
	durden_launch(vid, title);
end

function spawn_terminal()
	local bc = gconfig_get("term_bgcol");
	local fc = gconfig_get("term_fgcol");
	local cp = gconfig_get("extcon_path");

	local lstr = string.format(
		"font_hint=%s:font=[ARCAN_APPLPATH]/fonts/%s:"..
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
		durden_launch(vid, "", "terminal");
		def_handler(vid, {kind = "registered", segkind = "terminal"});
	else
		active_display():message( "Builtin- terminal support broken" );
	end
end

local swm = {};
function def_handler(source, stat)
	local wnd = swm[source];

	if (DEBUGLEVEL > 0 and active_display().debug_console) then
		active_display().debug_console:target_event(wnd, source, stat);
	end

-- registered subtype handler may say that this event should not
-- propagate to the default implementation (below)
	if (wnd.dispatch[stat.kind]) then
		if (DEBUGLEVEL > 0 and active_display().debug_console) then
			active_display().debug_console:event_dispatch(wnd, stat.kind, stat);
		end

		if (wnd.dispatch[stat.kind](wnd, source, stat)) then
			return;
		end
	end

	if (stat.kind == "framestatus") then
	elseif (stat.kind == "resized") then
		wnd.space:resize();
		wnd.source_audio = stat.source_audio;
		audio_gain(stat.source_audio,
			gconfig_get("global_mute") and 0.0 or (gconfig_get("global_gain") *
			(wnd.source_gain and wnd.source_gain or 1.0))
		);
		if (wnd.space.mode == "float") then
			wnd:resize_effective(stat.width, stat.height);
		end
		image_set_txcos_default(wnd.canvas, stat.origo_ll == true);
	elseif (stat.kind == "message") then
		wnd:set_message(stat.v, gconfig_get("msg_timeout"));

	elseif (stat.kind == "terminated") then
-- if an lbar is active that requires this target window, that should be
-- dropped as well to avoid a race
		wnd:destroy();
	elseif (stat.kind == "ident") then
-- this can come multiple times if the title of the window is changed,
-- (whih happens a lot with some types)
	elseif (stat.kind == "registered") then
		local atbl = archetypes[stat.segkind];
		if (atbl == nil or wnd.atype ~= nil) then
			return;
		end
		wnd.actions = atbl.actions;
		if (atbl.props) then
			for k,v in pairs(atbl.props) do
				wnd[k] = v;
			end
		end
-- FIXME: Not working
		wnd.dispatch = merge_dispatch(shared_dispatch(), atbl.dispatch);
		wnd.labels = atbl.labels and atbl.labels or {};
		wnd.source_audio = stat.source_audio;
	elseif (stat.kind == "segment_request") then
-- eval based on requested subtype etc. if needed
		local id = accept_target();
		durden_launch(id, "subseg", "subseg");
	end
end
-- switch handler, register on-destroy handler and a source-wnd map
function reg_window(wnd, source)
	swm[source] = wnd;
	if (valid_vid(source, TYPE_FRAMESERVER)) then
		target_updatehandler(source, def_handler);
	end
	wnd:add_handler("destroy", function() swm[source] = nil; end);
end

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
--
function poll_status_channel()
	local line = STATUS_CHANNEL:read();
	if (line == nil or string.len(line) == 0) then
		return;
	end

	local cmd = string.split(line, ":");
	cmd = cmd == nil and {} or cmd;

	if (cmd[1] == "status_1") then
-- escape control characters so we don't get nasty \f etc. commands
		local msg = string.gsub(string.sub(line, 6), "\\", "\\\\");
		local vid = render_text(
			string.format("%s \\#ffffff %s", gconfig_get("font_str"), msg));
		if (valid_vid(vid)) then
			active_display():update_statusbar(vid);
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

-- hotplug event
	if (line == "rescan_displays") then
		video_displaymodes();
	end
end

local mid_c = 0;
local mid_v = {0, 0};
function durden_input(iotbl, fromim)
	if (DEBUGLEVEL > 0 and active_display().debug_console) then
		active_display().debug_console:add_input(iotbl, fromim);
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
-- all input and symbol lookup paths go through this routine (in fglobal.lua)
		if (not dispatch_lookup(iotbl, sym, active_display().input_lock)) then
			local sel = active_display().selected;
			if (not sel) then
				return;
			end
			if (valid_vid(sel.external, TYPE_FRAMESERVER)) then
				iotbl.label = sel.labels[lutsym];
				target_input(sel.external, iotbl);
			elseif (sel.key_input) then
				sel:key_input(sym, iotbl);
			end
		end
	end
end

function durden_shutdown()
	SYMTABLE:store_translation();
	gconfig_shutdown();
end

function durden_clock_pulse()
	local tt = iostatem_tick();
	if (tt) then
		for k,v in ipairs(tt) do
			durden_input(v, true);
		end
	end

--	if (CLOCK % 100) then (quick and dirty leak check)
--		print(current_context_usage());
--	end

	mouse_tick(1);
	display_tick();
	if (CLOCK % 4 == 0) then
		if (STATUS_CHANNEL) then
			poll_status_channel();
		end

		if (CONTROL_CHANNEL) then
			poll_control_channel();
		end
	end
end

-- Copyright: 2015, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: Durden is a simple tiling window manager for Arcan that
-- re-uses much of the same support scripts as the Senseye project. This
-- code module covers basic I/O and event routing, and basic setup.
--

local connection_path = "durden";

-- we run a separate tiler instance for each display, dynamic plugging /
-- hotplugging events can be configured to destroy, or "background" the
-- associated tiler (and switch between foreground / background sets of tiled
-- workspaces).
displays = {};

--
-- Every connection can get a set of additional commands and configurations
-- based on what type it has. Supported ones are registered into this table.
-- init, bindings, settings, commands
--
archtypes = {};

function durden()
-- usual configuration management, gestures, mini UI components etc.
-- will get BINDINGS, SYMTABLE as global lookup tables
	system_load("gconf.lua")();
	system_load("mouse.lua")();
	system_load("suppl.lua")();
	system_load("bbar.lua")();
	system_load("keybindings.lua")();
	system_load("tiler.lua")();
	system_load("browser.lua")();

	system_load("fglobal.lua")();
	system_load("builtin/global.lua")();
	system_load("builtin/shared.lua")();

	local res = glob_resource("atypes/*.lua", APPL_RESOURCE);
	if (res ~= nil) then
		for k,v in ipairs(res) do
			local tbl = system_load("atypes/" .. v, false);
			tbl = tbl and tbl() or nil;
			if (tbl and tbl.atype) then
				archtypes[tbl.atype] = tbl;
			end
		end
	end

	displays.main = tiler_create(VRESW, VRESH, {});
	SYMTABLE = system_load("symtable.lua")();
	mouse_setup_native(load_image("cursor/default.png"), 0, 0);

-- dropping this call means that only controlled invocation is possible
-- (i.e. no non-authoritative connections)
	new_connection();

-- dropping this call means that the only input / output available is
-- through keybindings/mice/joysticks
	control_channel = open_nonblock("durden_cmd");
	if (control_channel == nil) then
		warning("no control channel found, use: (mkfifo c durden/durden_cmd)");
	else
		warning("control channel active (durden_cmd)");
	end

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
end

local function tile_changed(wnd)
	if (wnd.effective_w > 1 and wnd.effective_h > 1) then
		target_displayhint(wnd.external, wnd.effective_w, wnd.effective_h);
	end
end

function durden_launch(vid, ptitle)
	local wnd = displays.main:add_window(vid);
	wnd.external = vid;
	wnd:set_title(ptitle and ptitle or "unknown");
	wnd.resize_hook = tile_changed;
	tile_changed(wnd);
	show_image(vid);
	target_updatehandler(vid, def_handler);
end

function durden_adopt(vid, kind, title)
	durden_launch(vid, title);
end

function spawn_terminal()
	local vid = launch_avfeed(
		"env=ARCAN_CONNPATH=" .. connection_path, "terminal");
	if (valid_vid(vid)) then
		durden_launch(vid, "terminal");
		def_handler(vid, {kind = "registered", segkind = "terminal"});
	else
		displays.main:message( "Builtin- terminal support broken" );
	end
end

function def_handler(source, stat)
	local wnd = displays.main:find_window(source);
	assert(wnd ~= nil);

-- registered subtype handler may say that this event should not
-- propagate to the default implementation (below)
	if (wnd.dispatch[stat.kind]) then
		if (wnd.dispatch[stat.kind](source, stat)) then
			return;
		end
	end

	if (stat.kind == "resized") then
		wnd.space:resize();
		if (wnd.space.mode == "float") then
			wnd:resize_effective(stat.width, stat.height);
		end
		image_set_txcos_default(wnd.canvas, stat.origo_ll == true);
	elseif (stat.kind == "message") then
		wnd:set_message(stat.v, gconfig_get("msg_timeout"));

	elseif (stat.kind == "terminated") then
		wnd:destroy();

	elseif (stat.kind == "ident") then

-- this can come multiple times if the title of the window is changed,
-- (whih happens a lot with some types)
	elseif (stat.kind == "registered") then
		local atbl = archtypes[stat.segkind];
		if (atbl == nil or wnd.atype == stat.segkind) then
			return;
		end
		wnd.atype = stat.segkind;
		register_shared_atype(wnd, atbl.actions, atbl.settings, atbl.labels);
	end
end

function new_connection(source, status)
	if (status == nil or status.kind == "connected") then
		local vid = target_alloc(connection_path, new_connection);
		image_tracetag(vid, "nonauth_connection");

	elseif (status.kind == "resized") then
		resize_image(source, status.width, status.height);
		local wnd = displays.main:add_window(source);
		wnd.external = source;
		wnd.resize_hook = tile_changed;
		target_updatehandler(source, def_handler);
		tile_changed(wnd);
	end
end

--
-- line over fifo API for doing status bar updates, etc.
--
function poll_control_channel()
	local line = control_channel:read();
	if (line == nil or string.len(line) == 0) then
		return;
	end

	local cmd = string.split(line, ":");
	cmd = cmd == nil and {} or cmd;

	if (cmd[1] == "status") then
 -- unkown command, just draw (allows us to just pipe i3status)
		local msg = string.gsub(string.sub(line, 6), "\\", "\\\\");
		local vid = render_text(
			string.format("%s \\#ffffff %s", gconfig_get("font_str"), msg));
		if (valid_vid(vid)) then
			displays.main:update_statusbar(vid);
		end
	else
		dispatch_symbol(cmd[1]);
	end
end

local mid_c = 0;
local mid_v = {0, 0};
function durden_input(iotbl)
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
		local sym = SYMTABLE[ iotbl.keysym ];

-- all input and symbol lookup paths go through this routine (in fglobal.lua)
		if (not dispatch_lookup(iotbl, sym, displays.main.input_lock)) then
			local sel = displays.main.selected;
			if (sel and valid_vid(sel.external, TYPE_FRAMESERVER)) then
-- possible injection site for higher level inputs
				target_input(sel.external, iotbl);
			end
		end
	end
end

function durden_display_state(action, id)
	if (action == "added") then
		if (displays[id] == nil) then
			displays[id] = {};
-- find out if there is a known profile for this display, activate
-- corresponding desired resolution, set mapping, create tiler
		end
	elseif (action == "removed") then
		if (displays[id] == nil) then
			warning("lost unknown display: " .. tostring(id));
			return;
		end

-- sweep workspaces and migrate back to previous display (and toggle
-- rendertarget output on/off), destroy tiler, save settings,
-- if workspace slot is occupied, add to "orphan-" list.
	end
end

function durden_clock_pulse()
	displays.main:tick();
	if (CLOCK % 4 == 0 and control_channel ~= nil) then
		poll_control_channel();
	end
end

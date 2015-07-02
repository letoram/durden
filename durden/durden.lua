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
	system_load("lbar.lua")();
	system_load("bbar.lua")();
	system_load("popup_menu.lua")();
	system_load("keybindings.lua")();
	system_load("tiler.lua")();

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
	mouse_setup_native(load_image("cursor.png"), 1, 1);

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

	register_global("spawn_terminal", spawn_terminal);
	register_global("launch_bar", query_launch);
end

--
-- create both an external single-shot connection and a reference color
-- the connection is needed for frameserver- specific operations to work
--
test_gc = 0;
function spawn_test(bar)
	local img = fill_surface(math.random(200, 600), math.random(200, 600),
		math.random(64, 255), math.random(64, 255), math.random(64, 255));
	show_image(img);

	local wnd = displays.main:add_window(img, {scalemode = "stretch"});

	if (bar) then
		wnd:set_title("test window_" .. tostring(test_gc));
		test_gc = test_gc + 1;
	end
end

local function tile_changed(wnd)
	if (wnd.effective_w > 1 and wnd.effective_h > 1) then
		target_displayhint(wnd.external, wnd.effective_w, wnd.effective_h);
	end
end

function durden_adopt(vid, kind, title)
	local wnd = displays.main:add_window(vid);
	if (title) then
		wnd:set_title(title);
	else
		wnd:set_title(string.format("adopted:%s", lbl));
	end

	wnd.resize_hook = tile_changed;
	wnd.external = vid;
	tile_changed(wnd);
	show_image(vid);
end

function spawn_terminal()
	local vid = launch_avfeed(
		"env=ARCAN_CONNPATH=" .. connection_path, "terminal");
	image_tracetag(vid, "terminal");

	if (valid_vid(vid)) then
		local wnd = displays.main:add_window(vid);
		wnd.external = vid;
		wnd:set_title("terminal");
		wnd.resize_hook = tile_changed;
		tile_changed(wnd);
		show_image(vid);
		target_updatehandler(vid, def_handler);
	else
		displays.main:message( "Builtin- terminal support broken" );
	end
end

local function lbar_launch(tgt, cfg)
	local lbl = string.format("%s:%s", tgt, cfg);
	local vid, aid = launch_target(tgt, cfg, LAUNCH_INTERNAL, def_handler);
	image_tracetag(vid, label);
	local wnd = displays.main:add_window(vid);
	wnd:set_title(lbl);
	wnd.resize_hook = tile_changed;
	wnd.external = vid;
	tile_changed(wnd);
	show_image(vid);
end

local function lbar_subsel(instr, tbl, last)
	if (instr == nil or string.len(instr) == 0) then
		return {set = tbl, valid = true};
	end

	local res = {};
	for i,v in ipairs(tbl) do
		if (string.sub(v,1,string.len(instr)) == instr) then
			table.insert(res, v);
		end
	end

-- want to return last result table so cursor isn't reset
	if (last and #res == #last) then
		return {set = last};
	end

	return {set = res, valid = true};
end

local function lbar_configsel(ctx, instr, done, lastv)
	if (done) then
		return lbar_launch(ctx.target, instr);
	end

	return lbar_subsel(instr ~= nil and instr or "", ctx.configs, lastv);
end

--
-- called whenever launch-bar gets a key input, done is set when
-- the current line should be activated and otherwise return a list
-- of possible future characters.
--
local function lbar_targetsel(ctx, instr, done, lastv)
	if (done) then
		local cfgs = target_configurations(instr);
		if (cfgs == nil or #cfgs == 0) then
			return;
		end

		if (#cfgs > 1) then
			local cbctx = {
				target = instr,
				configs = cfgs
			};
			displays.main:lbar(lbar_configsel, cbctx, {force_completion = true});
			return;
		end

		lbar_launch(instr, "default");
		return;
	end

	return lbar_subsel(instr ~= nil and instr or "", ctx.targets, lastv);
end

function query_launch()
	local cbctx = {
		targets = list_targets()
	};

	displays.main:lbar(lbar_targetsel, cbctx, {force_completion = true}, "Launch:");
end

function query_open()
-- meta menu for selecting remoting, decode (local or url)
end

function def_handler(source, stat)
	local wnd = displays.main:find_window(source);
	assert(wnd ~= nil);

	if (stat.kind == "resized") then
		wnd.space:resize();
		image_set_txcos_default(wnd.canvas, stat.origo_ll == true);
	elseif (stat.kind == "message") then
		wnd:set_message(stat.v, gconfig_get("msg_timeout"));
	elseif (stat.kind == "terminated") then
		wnd:destroy();
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
-- sweet spot for adding type- specific handlers
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

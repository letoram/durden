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

function durden()
-- usual configuration management, gestures, mini UI components etc.
-- will get BINDINGS, ERRNO, SYMTABLE as global lookup tables
	system_load("gconf.lua")();
	system_load("mouse.lua")();
	system_load("suppl.lua")();
	system_load("popup_menu.lua")();
	system_load("keybindings.lua")();
	system_load("fglobal.lua")();
	system_load("tiler.lua")();

	displays.main = tiler_create(VRESW, VRESH, {});
	ERRNO = system_load("errc.lua")();
	SYMTABLE = system_load("symtable.lua")();
	mouse_setup_native(load_image("cursor.png"), 1, 1);

-- dropping this call means that only controlled invocation is possible
-- (i.e. no non-authoritative connections)
	new_connection();
	control_channel = open_nonblock("durden_cmd");
	if (control_channel == nil) then
		warning("no control channel found, use: (mkfifo c durden/durden_cmd)");
	else
		warning("control channel active (durden_cmd)");
	end
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
	target_displayhint(wnd.source, wnd.effective_w, wnd.effective_h);
end

function spawn_terminal()
	local vid = launch_avfeed(
		"env=ARCAN_CONNPATH=" .. connection_path, "terminal");

	if (valid_vid(vid)) then
		local wnd = displays.main:add_window(vid);
		wnd:set_title("terminal");
		wnd.resize_hook = tile_changed;
		tile_changed(wnd);
		show_image(vid);
		target_updatehandler(vid, def_handler);
	else
		displays.main:error_message( ERRNO["BROKEN_TERMINAL"] );
	end
end

function query_exit()
	return shutdown();
end

--
-- called whenever launch-bar gets a key input, done is set when
-- the current line should be activated and otherwise return a list
-- of possible future characters.
--
local function launch_complete(ctx, instr, done)
	local sp = string.find(instr, ":");
	local res = {};

	if (done) then
		ctx.config = ctx.config ~= nil and ctx.config or "default";
		warning("validate config and target");
		local vid, aid = launch_target(ctx.target, ctx.config,
			LAUNCH_INTERNAL, def_handler);
		local wnd = displays.main:add_window(vid);
		wnd:set_title(ctx.target .. ":" .. ctx.config);
		wnd.resize_hook = trile_changed;
		tile_changed(wnd);
		show_image(vid);
		return;
	end

	if (sp) then
		ctx.target = string.sub(instr, 1, sp-1);
		if (string.length(ctx.target) == 0) then
			return res;
		end

-- got cached list of configurations
		res = target_configurations(ctx.target);
		warning("cache target configurations");
	else
		local tgts = list_targets();
		for k,v in ipairs(tgts) do
			if (string.sub(v, 1, string.len(instr)) == instr) then
				table.insert(res, v);
			end
		end
	end

	return res;
end

function query_launch()
	local cbctx = {
		targets = list_targets()
	};

	displays.main:lbar(launch_complete, cbctx,
		gconfig_get("ok_sym"), gconfig_get("cancel_sym"));
end

function def_handler(source, stat)
	local wnd = displays.main:find_window(source);
	assert(wnd ~= nil);

	if (stat.kind == "resized") then
		wnd.space:resize();

	elseif (stat.kind == "terminated") then
		if (wnd.autoclose) then
			wnd:destroy();
		end
	end
end

function new_connection(source, status)
	if (status == nil or status.kind == "connected") then
		local vid = target_alloc(connection_path, new_connection);

	elseif (status.kind == "resized") then
		resize_image(source, status.width, status.height);
		local wnd = displays.main:add_window(source);
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

	if (cmd[1] == "rescan-display") then
		video_displaymodes();

	elseif (cmd[1] == "status") then
 -- unkown command, just draw (allows us to just pipe i3status)
		local msg = string.gsub(string.sub(line, 6), "\\", "\\\\");
		local vid = render_text(
			string.format("%s \\#ffffff %s", gconfig_get("font_str"), msg));
		if (valid_vid(vid)) then
			displays.main:update_statusbar(vid);
		end
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

		if (not dispatch_lookup(iotbl, sym, displays.main.input_lock)) then
			local sel = displays.main.selected;
			if (sel and valid_vid(sel.source, TYPE_FRAMESERVER)) then
-- possible injection site for higher level inputs
				target_input(sel.source, iotbl);
			end
		end
	end
end

function durden_clock_pulse()
	displays.main:tick();
	if (CLOCK % 4 == 0 and control_channel ~= nil) then
		poll_control_channel();
	end
end

-- Copyright: 2015, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: Main setup for the Arcan/Durden desktop environment

-- Global used to track input events that should be aligned to clock
-- tick for rate-limit and timing purposes
EVENT_SYNCH = {};

local update_default_font;

function durden(argv)
	system_load("mouse.lua")(); -- mouse gestures
	system_load("gconf.lua")(); -- configuration management
	system_load("lbar.lua")();
	system_load("bbar.lua")(); -- input binding
	system_load("shdrmgmt.lua")(); -- shader format parser, builder
	system_load("suppl.lua")(); -- convenience functions

	update_default_font();

	system_load("keybindings.lua")(); -- static key configuration
	system_load("tiler.lua")(); -- window management
	system_load("browser.lua")(); -- quick file-browser
	system_load("iostatem.lua")(); -- input repeat delay/period
	system_load("display.lua")(); -- multidisplay management
	system_load("extevh.lua")(); -- handlers for external events
	CLIPBOARD = system_load("clipboard.lua")(); -- clipboard filtering / mgmt

-- functions exposed to user through menus, binding and scripting

	system_load("fglobal.lua")(); -- tiler- related global functions
	system_load("menus/global/global.lua")(); -- desktop related global
	system_load("menus/target/target.lua")(); -- shared window related global

-- load builtin features and 'extensions'
	local res = glob_resource("builtin/*.lua", APPL_RESOURCE);
	for k,v in ipairs(res) do
		local res = system_load("builtin/" .. v, false);
		if (res) then
			res();
		else
			warning(string.format("couldn't load builtin (%s)", v));
		end
	end

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
-- 65531..5 is a hidden max_image_order range (for cursors, overlays..)
		mouse_setup(load_image("cursor/default.png"), 65535, 1, true, false);
	end
	display_manager_init();

-- this opens up the 'durden' external listening point, removing it means
-- only user-input controlled execution through configured database and browse
	local cp = gconfig_get("extcon_path");
	if (cp ~= nil and string.len(cp) > 0) then
		durden_new_connection();
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

-- add hooks for changes to all default  font properties
	gconfig_listen("font_def", "deffonth", update_default_font);
	gconfig_listen("font_sz", "deffonth", update_default_font);
	gconfig_listen("font_hint", "font_hint", update_default_font);

-- preload cursor states
	mouse_add_cursor("drag", load_image("cursor/drag.png"), 0, 0); -- 7, 5);
	mouse_add_cursor("grabhint", load_image("cursor/grabhint.png"), 0, 0); --, 7, 10);
	mouse_add_cursor("rz_diag_l", load_image("cursor/rz_diag_l.png"), 0, 0); --, 6, 5);
	mouse_add_cursor("rz_diag_r", load_image("cursor/rz_diag_r.png"), 0, 0); -- , 6, 6);
	mouse_add_cursor("rz_down", load_image("cursor/rz_down.png"), 0, 0); -- 5, 13);
	mouse_add_cursor("rz_left", load_image("cursor/rz_left.png"), 0, 0); -- 0, 5);
	mouse_add_cursor("rz_right", load_image("cursor/rz_right.png"), 0, 0); -- 13, 5);
	mouse_add_cursor("rz_up", load_image("cursor/rz_up.png"), 0, 0); -- 5, 0);

	audio_gain(BADID, gconfig_get("global_gain"));

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

-- for one or more parallel instances sharing input devices, it helps if
-- we can start in a locked state and then use toggle keybinding (if only 2)
-- or command_channel to switch
	elseif (argv[1] == "input_lock") then
		dispatch_symbol("input_lock_on");
	end
end

update_default_font = function(key, val)
	local newfont=(key and key == "font_def" and val ~= gconfig_get("font_def"));
	local font = (key and key == "font_def") and val or gconfig_get("font_def");
	local sz = (key and key == "font_sz") and val or gconfig_get("font_sz");
	local hint = (key and key == "font_hint") and val or gconfig_get("font_hint");
	system_defaultfont(font, sz, hint);

-- centering vertically on fonth will look poor on fonts that has a
-- pronounced ascent / descent and we have no exposed function to get access
-- to more detailed font metrics, so lets go rough..
	local vid, lines, w, fonth = render_text("\\f,0 gijy1!`");
	local rfh = fonth;

	image_access_storage(vid, function(tbl, w, h)
		for y=h-1,0,-1 do
			local rowv = 0;
			for x=0,w-1 do
				rowv = rowv + tbl:get(x, y, 1);
			end
			if (rowv ~= 0) then
				break;
			else
				rfh = y;
			end
		end
	end);
	delete_image(vid);
-- and not to break on mixed DPI multidisplay, we go with factors
	local rfhf = rfh / fonth;

	gconfig_set("sbar_sz", fonth + gconfig_get("sbar_pad") * 2);
	gconfig_set("tbar_sz", fonth + gconfig_get("tbar_pad") * 2);
	gconfig_set("lbar_sz", fonth + gconfig_get("lbar_pad") * 2);
	gconfig_set("lbar_caret_h", fonth);
	gconfig_set("font_defsf", rfhf);

	if (not all_displays_iter) then
		return;
	end

	for disp in all_displays_iter() do
		disp.font_sf = rfhf;
		disp:resize(disp.width, disp.height, sz);
		disp:rebuild_border();
		disp:invalidate_statusbar();
	end

-- also propagate to each window so that it may push descriptors and
-- size information to any external connections
	for wnd in all_windows() do
		wnd:set_title(wnd.title_text and wnd.title_text or "");
		wnd:resize(wnd.width, wnd.height);
		wnd:update_font(sz, hint, font);
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
		if (valid_vid(wnd.external, TYPE_FRAMESERVER)) then
			local props = image_storage_properties(wnd.external);
			if (not wnd.sz_delta or
				(math.abs(props.width - neww) > wnd.sz_delta.width or
			   math.abs(props.height - newh) > wnd.sz_delta.height)) then
				target_displayhint(wnd.external, neww, newh, wnd.dispmask);
			end
		end

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

-- useful for terminal where we can possibly avoid a resize and
-- the added initial delay by setting the size in beforehand
function durden_prelaunch()
	local nsurf = null_surface(32, 32);
	return active_display:add_window(nsurf);
end

function durden_launch(vid, title, prefix, wnd)
	if (not valid_vid(vid)) then
		return;
	end
	if (not wnd) then
		wnd = active_display():add_window(vid);
	end

-- local keybinding->utf8 overrides, we map this to SYMTABLE
	wnd.u8_translation = {};

-- window aesthetics
	wnd:set_title(title and title or "?");
	wnd:set_prefix(prefix);
	wnd:add_handler("resize", tile_changed);
	wnd:add_handler("select", sel_input);
	wnd:add_handler("deselect", desel_input);
	show_image(wnd.canvas);

-- may use this function to launch / create some internal window
-- that don't need all the external dispatch stuff, so make sure
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
			local wnd = extevh_get_window(parent);
			if (wnd ~= nil) then
				wnd.clipboard = vid;
				target_updatehandler(vid, function(source, status)
					extevh_clipboard(wnd, source, status);
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

function durden_new_connection(source, status)
	if (status == nil or status.kind == "connected") then
		INCOMING_ENDPOINT = target_alloc(
			gconfig_get("extcon_path"), durden_new_connection);
		if (valid_vid(INCOMING_ENDPOINT)) then
			image_tracetag(INCOMING_ENDPOINT, "nonauth_connection");
		end
		if (status) then
			durden_launch(source, "external", "");
		end
	end
end

--
-- text/line command protocol for doing status bar updates, etc.
-- as this grows, move into its own separate module.
--
local function poll_status_channel()
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

local allowed_global = {
	input_lock_on = true,
	input_lock_off = true,
	input_lock_toggle = true
};

local function poll_control_channel()
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

	elseif (allowed_global[elem[1]]) then
		dispatch_symbol(elem[1]);
	end
end

local mid_c = 0;
local mid_v = {0, 0};

local function mousemotion(iotbl)
-- we prefer relative mouse coordinates for proper warping etc.
-- but not all platforms can deliver on that promise and these are
-- split BY AXIS but delivered in pairs (stupid legacy) so we have to
-- merge.
	if (iotbl.relative) then
		if (iotbl.subid == 0) then
			mouse_input(iotbl.samples[2], 0);
		else
			mouse_input(0, iotbl.samples[2]);
		end
	else
		mid_v[iotbl.subid+1] = iotbl.samples[sofs];
		mid_c = mid_c + 1;

		if (mid_c == 2) then
			inp_fun(mid_v[1], mid_v[2]);
			mid_c = 0;
		end
	end
end

function durden_normal_input(iotbl, fromim)
-- we track all iotbl events in full debug mode
	if (DEBUGLEVEL > 2 and active_display().debug_console) then
		active_display().debug_console:add_input(iotbl);
	end

-- first we feed into the simulated repeat state manager, this will
-- invoke the callback handler and set fromim if it is a repeated/held
-- input.
	if (not fromim) then
		iostatem_input(iotbl);
	end

-- then we forward keyboard events into the dispatch function, this applies
-- translations, bindings and symtable mapping. Returns information if the
-- event was consumed by some UI features (ok true) or what the internal string
-- representation is (m1_m2_LEFT) and the patched iotbl. It will also apply any
-- per-display hook active at the moment (lbar, bbar uses those). It also runs
-- the meta-guard evaluation to try and figure out if the user seems unaware of
-- his keybindings.
	local ok, outsym, iotbl = dispatch_translate(iotbl);
	if (iotbl.digital) then
		if (ok) then
			return;
		end
	end

-- after that we have special handling for mouse motion and presses,
-- any forwarded input there is based on event reception in listeners
-- attached to mouse motion or presses.
	if (iotbl.mouse) then
		if (iotbl.digital) then
			mouse_button_input(iotbl.subid, iotbl.active);
		else
			mousemotion(iotbl);
		end
		return;
	end

-- still a window alived but no input has consumed it? then we forward
-- to the external- handler
	local sel = active_display().selected;
	if (not sel or not valid_vid(sel.external, TYPE_FRAMESERVER)) then
		return;
	end

-- there may be per-window label tabel for custom input labels,
-- those need to be applied still.
	target_input(sel.external, iotbl);
end

-- special case: (UP, DOWN, LEFT, RIGHT + mouse motion is mapped to
-- manipulate the mouse_select_begin() mouse_select_end() region,
-- ESCAPE cancels the mode, end runs whatever trigger we set (global).
-- see 'select_region_*' global functions + some button to align
-- with selected window (if any, like m1 and m2)
function durden_regionsel_input(iotbl)
	if (iotbl.translated and iotbl.active) then
		local sym, lutsym = SYMTABLE:patch(iotbl);

		if (SYSTEM_KEYS["cancel"] == sym) then
			mouse_select_end();
			durden_input = durden_normal_input;
		elseif (SYSTEM_KEYS["accept"] == sym) then
			mouse_select_end(DURDEN_REGIONSEL_TRIGGER);
			durden_input = durden_normal_input;
		end

	elseif (iotbl.mouse) then
		if (iotbl.digital) then
			mouse_select_end(DURDEN_REGIONSEL_TRIGGER);
			durden_input = durden_normal_input;
		else
			mousemotion(iotbl);
		end
	end
end

durden_input = durden_normal_input;

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

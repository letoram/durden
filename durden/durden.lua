-- Copyright: 2015-2018, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: Main setup for the Arcan/Durden desktop environment

-- Global used to track input events that should be aligned to clock
-- tick for rate-limit and timing purposes
EVENT_SYNCH = {};

local update_default_font, update_connection_path;
local eval_respawn, load_configure_mouse;

local argv_cmds = {};

-- track custom buttons that should be added to each window
local tbar_btns = {
};

-- count initial delay before idle shutdown
local ievcount = 0;

-- replace the normal assert function one that can provide a traceback
local oldass = assert;
function assert(...)
	oldass(..., debug.traceback("assertion failed", 2));
end

function durden(argv)
	system_load("builtin/mouse.lua")(); -- mouse gestures (in distribution)

	system_load("suppl.lua")(); -- convenience functions
	system_load("gconf.lua")(); -- configuration management
	system_load("shdrmgmt.lua")(); -- shader format parser, builder
	system_load("uiprim.lua")(); -- ui primitives (buttons!)
	system_load("lbar.lua")(); -- used to navigate menus
	system_load("bbar.lua")(); -- input binding
	system_load("menu.lua")(); -- menu subsystem
	system_load("timer.lua")(); -- timers, will hook clock_pulse
	system_load("notification.lua")(); -- queue of message+descriptions

	CLIPBOARD = system_load("clipboard.lua")(); -- clipboard filtering / mgmt
	CLIPBOARD:load("clipboard_data.lua");

	update_default_font();

	system_load("dispatch.lua")(); -- UI keyboard routing / management
	system_load("tiler.lua")(); -- window management
	system_load("iostatem.lua")(); -- input repeat delay/period
	system_load("ledm.lua")(); -- led controllers
	system_load("display.lua")(); -- multidisplay management
	system_load("ipc.lua")(); -- status and command channels
	system_load("menus/menus.lua")(); -- root of menu virtual filesystem

	system_load("extevh.lua")(); -- handlers for external events

	kbd_repeat(0, 0);

-- can't work without a detected keyboard
	if (not input_capabilities().translated) then
		warning("arcan reported no available translation capable devices "
			.. "(keyboard), cannot continue without one.\n");
		return shutdown("", EXIT_FAILURE);
	end

	SYMTABLE = system_load("builtin/keyboard.lua")();
	SYMTABLE:load_translation();
	SYMTABLE:load_keymap("default.lua");

	load_configure_mouse();

-- this creates our first tiler, and switch out its default titlebar buttons
-- with the set that is loaded / stored in gconf.lua
	local nt = display_manager_init();
	nt.buttons = gconfig_buttons;

-- tools are quick 'drop-ins' to get additional features like modelviewer
	suppl_scan_tools();
	suppl_scan_widgets();

-- this opens up the 'durden' external listening point, removing it means
-- only user-input controlled execution through configured database and browse
	local cp = gconfig_get("extcon_path");
	if (cp ~= nil and string.len(cp) > 0 and cp ~= ":disabled") then
		eval_respawn(true, cp);
	end

-- add hooks for changes to all default font properties
	gconfig_listen("font_def", "deffonth", update_default_font);
	gconfig_listen("font_sz", "deffonth", update_default_font);
	gconfig_listen("font_hint", "font_hint", update_default_font);
	gconfig_listen("font_fb", "font_fb", update_default_font);
	gconfig_listen("lbar_tpad", "padupd", update_default_font);
	gconfig_listen("lbar_bpad", "padupd", update_default_font);
	gconfig_listen("extcon_path", "pathupd", update_connection_path);

	audio_gain(BADID, gconfig_get("global_gain"));

-- load saved keybindings
	dispatch_load(durden_lock_toggle);
	iostatem_init();

	for i,v in ipairs(argv) do
		if (argv_cmds[v]) then
			argv_cmds[v]();
		end
	end

-- process user- configuration commands
	local cmd = system_load("autorun.lua", 0);
	if (type(cmd) == "function") then
		cmd();
	end

	if (gconfig_get("mouse_block")) then
		mouse_block();
	end

	if (gconfig_get("first_run")) then
		gconfig_set("first_run", false);
		meta_guard_reset(true);
	end

-- for dealing wtih crash recovery windows or saved layout/role-
	timer_add_periodic("recover_layout_save", 100, false,
	function()
		for wnd in all_windows(nil, true) do
			if (wnd.config_dirty) then
				wnd.config_dirty = nil;
				store_key("durden_temp_" .. wnd.config_tgt, image_tracetag(wnd.external));
			end
		end
	end, true);

	if (CRASH_SOURCE and string.len(CRASH_SOURCE) > 0) then
		notification_add(
			"Durden", nil, "Crash", CRASH_SOURCE, 4);
	end
end

argv_cmds["input_lock"] = function()
	dispatch_symbol("input_lock_on");
end

argv_cmds["safety_timer"] = function()
	timer_add_idle("Safety Shutdown",
		1000, true, function()
			if (ievcount < 1) then
				return shutdown("no device input");
			end
		end
	);
end

update_connection_path = function(key, val)
	if (val == ":disabled") then
		val = "";
	end
	for tiler in all_tilers_iter() do
		for i, wnd in ipairs(tiler.windows) do
			durden_devicehint(wnd.external);
		end
	end
end

load_configure_mouse = function()
-- needed when we run in nested settings as mouse scale won't match
-- device input from external window manager
	if (gconfig_get("mouse_hardlock")) then
		toggle_mouse_grab(MOUSE_GRABON);
	end

-- safe-load that first uses configured set, fallback to default,
-- and fail-safe with a green box cursor
	local load_cursor;
	load_cursor = function(name, set)
		local vid = load_image(string.format("cursor/%s/%s.png", set, name));
		if (not valid_vid(vid)) then
			if (set ~= "default") then
				return load_cursor(name, "default", 0, 0);
			else
				warning("cursor set broken, couldn't load " .. name);
				vid = fill_surface(8, 8, 0, 255, 0);
			end
		end
		return vid;
	end

	local set = gconfig_get("mouse_cursorset");
	if (gconfig_get("mouse_mode") == "native") then
		mouse_setup_native(load_cursor("default", set), 0, 0);
	else
-- 65531..5 is a hidden max_image_order range (for cursors, overlays..)
		mouse_setup(load_cursor("default", set), 65535, 1, true, false);
	end

-- preload cursor states
	mouse_add_cursor("drag", load_cursor("drag", set), 0, 0); -- 7, 5
	mouse_add_cursor("grabhint", load_cursor("grabhint", set), 0, 0); --, 7, 10);
	mouse_add_cursor("rz_diag_l", load_cursor("rz_diag_l", set), 0, 0); --, 6, 5);
	mouse_add_cursor("rz_diag_r", load_cursor("rz_diag_r", set), 0, 0); -- , 6, 6);
	mouse_add_cursor("rz_down", load_cursor("rz_down", set), 0, 0); -- 5, 13);
	mouse_add_cursor("rz_left", load_cursor("rz_left", set), 0, 0); -- 0, 5);
	mouse_add_cursor("rz_right", load_cursor("rz_right", set), 0, 0); -- 13, 5);
	mouse_add_cursor("rz_up", load_cursor("rz_up", set), 0, 0); -- 5, 0);
	switch_default_texfilter(FILTER_NONE);

	if (gconfig_get("mouse_block")) then
		mouse_block();
	end

	mouse_reveal_hook(gconfig_get("mouse_reveal"));
end

update_default_font = function(key, val)
	local font = (key and key == "font_def") and val or gconfig_get("font_def");
	local sz = (key and key == "font_sz") and val or gconfig_get("font_sz");
	local hint = (key and key == "font_hint") and val or gconfig_get("font_hint");
	local fbf = (key and key == "font_fb") and val or gconfig_get("font_fb");

	system_defaultfont(font, sz, hint);

-- with the default font reset, also load a fallback one
	if (fbf and resource(fbf, SYS_FONT_RESOURCE)) then
		system_defaultfont(fbf, sz, hint, 1);
	end

-- centering vertically on fonth will look poor on fonts that has a
-- pronounced ascent / descent and with scale factors etc. it is a lot of tedium
-- to try and probe the metrics. Go with user-definable top and bottom padding.
	local vid, lines, w, fonth, asc = render_text("\\f,0\\#ffffff gijy1!`");
	local rfh = fonth;
	local props = image_surface_properties(vid);
	delete_image(vid);

	gconfig_set("sbar_sz", fonth + gconfig_get("sbar_tpad") + gconfig_get("sbar_bpad"));
	gconfig_set("tbar_sz", fonth + gconfig_get("tbar_tpad") + gconfig_get("tbar_bpad"));
	gconfig_set("lbar_sz", fonth + gconfig_get("lbar_tpad") + gconfig_get("lbar_bpad"));
	gconfig_set("lbar_caret_h", fonth);

	if (not all_tilers_iter) then
		return;
	end

	for disp in all_tilers_iter() do
		disp:update_scalef(disp.scalef);
	end

-- also propagate to each window so that it may push descriptors and
-- size information to any external connections
	for wnd in all_windows() do
		wnd:update_font(sz, hint, font);
		wnd:set_title();
		wnd:resize(wnd.width, wnd.height);
	end
end

-- need these event handlers here since it ties together modules that should
-- be separated code-wise, as we want tiler- and other modules to be reusable
-- in less complex projects
local function tile_changed(wnd, neww, newh, efw, efh)
	if (not neww or not newh or wnd.block_rz_hint) then
		return;
	end

	if (neww <= 0 or newh <= 0) then
		return;
	end

	if (not valid_vid(wnd.external, TYPE_FRAMESERVER)) then
		return;
	end

	local props = image_storage_properties(wnd.external);

-- edge cases where we want the client to ignore actual sizing
	if (wnd.displayhint_block_wh) then
		efw = props.width;
		efh = props.height;
	end

-- in this mode, just tell the client what the size of the area actually is
-- we really want different behavior for drag here as well, but that's
-- something to fix in the float-mode enhancement stage
	if (wnd.scalemode == "client") then
		efw = wnd.max_w - wnd.pad_left - wnd.pad_right;
		efh = wnd.max_h - wnd.pad_top - wnd.pad_bottom;
	end

	if (wnd.block_rz_hint) then
		return;
	end

-- ignore resize- step limit (terminal) if we are not in drag resize
	if (not mouse_state().drag or not wnd.sz_delta or
		(math.abs(props.width - efw) > wnd.sz_delta[1] or
	   math.abs(props.height - efh) > wnd.sz_delta[2])) then

-- cache what we actually send
		wnd:displayhint(efw+wnd.dh_pad_w, efh+wnd.dh_pad_h, wnd.dispmask);
	end
end

--
-- triggered by meta- state tracker, we need the hook here to also trigger
-- mouse locking and update border states
--
function durden_lock_toggle(newst, state)
	if ((not active_display().selected and
		not active_display().lock_override) and newst) then
		dispatch_toggle(false);
		return;
	end

	for i in all_tilers_iter() do
		i.sbar_ws["msg"]:switch_state(newst and "locked" or "active");
	end
end

-- there is a ton of "per window" input state when it comes to everything from
-- active translation tables, to diacretic traversals, to repeat-rate and
-- active analog/digital devices.
local function sel_input(wnd)
	local cnt = 0;
	SYMTABLE:translation_overlay(wnd.u8_translation);
	iostatem_restore(wnd.iostatem);
end

local function desel_input(wnd)
	SYMTABLE:translation_overlay({});
	wnd.iostatem = iostatem_save();
	mouse_switch_cursor("default");
end

-- separated from launch etc. as we don't want it for subwindows,
-- and later this provides a decent entrypoint for load-balancing
function durden_devicehint(vid)
	if (valid_vid(vid, TYPE_FRAMESERVER) and
		gconfig_get("extcon_path") ~= ":disabled") then
		target_devicehint(vid, gconfig_get("extcon_path"));
	end
end

function durden_launch(vid, prefix, title, wnd, wargs)
	if (not valid_vid(vid)) then
		warning("launch failed, invalid vid provided");
		return;
	end
	if (not wnd) then
		wnd = active_display():add_hidden_window(vid, wargs);
		if (not wnd) then
			warning("add_hidden_window on vid failed");
		end
	end

-- hidden window creation failed or event during creation
-- triggered destruction immediately, hence the table will be empty
	if (not wnd.set_prefix) then
		delete_image(vid);
		return;
	end

-- window aesthetics
	wnd:set_prefix(prefix);
	wnd:set_title(title, true);
	wnd:add_handler("resize", tile_changed);
	wnd:add_handler("select", sel_input);
	wnd:add_handler("deselect", desel_input);
	show_image(wnd.canvas);

-- may use this function to launch / create some internal window
-- that don't need all the external dispatch stuff, so make sure
	if (valid_vid(vid, TYPE_FRAMESERVER)) then
		wnd.external = vid;
		extevh_register_window(vid, wnd);
		EVENT_SYNCH[wnd.external] = {
			queue = {},
			target = vid
		};
		if (wnd.wm.selected ~= wnd) then
			wnd:set_dispmask(TD_HINT_UNFOCUSED);
		end
	end
	return wnd;
end

--
-- adopted windows has a few edge cases,
-- 1. saved metadata from earlier
-- 2. attached to a display that doesn't necessarily exist
-- 3. complex allocation hierarchy (wayland)
--
local adopt_new = {};
function durden_adopt(vid, kind, title, parent, last)
-- always ignore unknown ones as they are likely pending or external listening
	if (kind == "unknown") then
		return false;
	end

-- need to re-attach so they don't end up racing to the wrong display
	local ap = display_attachment();
	if (ap ~= nil) then
		rendertarget_attach(ap, vid, RENDERTARGET_DETACH);
	end

-- otherwise, ignore subsegments - let the client re-request them as needed
	if (valid_vid(parent)) then
		return;
	end

-- build a new window with the old title etc.
	local wnd = durden_launch(vid, title);
	if (not wnd) then
		return;
	end

-- and fake a registered event to make the archetype apply
	extevh_default(vid, {
		kind = "registered",
		segkind = kind,
		title = string.len(title) > 0 and title or tostring(kind),
		source_audio = BADID
	});

-- some atypes may still have 'attach_block' where this becomes a noop
	if (wnd.ws_attach) then
		wnd:ws_attach();
		table.insert(adopt_new, wnd);
	end

	if (not last) then
		return true;
	end

-- sweep the list of newly added windows and reparent if needed
	local ds = {};
	for i,v in ipairs(adopt_new) do
		if (v.desired_parent) then

			local lst = v.space:linearize();
			for i,j in ipairs(lst) do
				if (j.name == v.desired_parent) then
					v:reparent(j);
					ds[v.space] = true;
					break;
				end
			end
		end
	end

-- and relayout the dirty spaces
	for space in all_spaces_iter() do
		if (ds[space]) then
			space:resize();
		end
	end

-- the statusbar and other dependents are not necessarily synched on
-- ws_attach operations, so need to do this manually
	for disp in all_tilers_iter() do
		disp:tile_update();
-- an ugly hack to reset selection state
		disp:switch_ws(2);
		disp:switch_ws(1);
	end

	adopt_new = {};
	return true;
end

if (not target_devicehint) then
	local warned;
	function target_devicehint()
		if (not warned) then
			warning("missing target_devicehint call, upgrade arcan build");
		end
	end
end

local extcon_wndcnt = 0;
function durden_new_connection(source, status, norespawn)
	print("new connection", source, status);

	if (not status or status.kind ~= "connected") then
-- misplaced event, should really happen
		return;
	end

-- allocate a new endpoint? or wait?
	if (gconfig_get("extcon_rlimit") > 0 and CLOCK >
		gconfig_get("extcon_startdelay")) then
		timer_add_periodic("extcon_activation",
			gconfig_get("extcon_rlimit"), true,
			function() eval_respawn(false, status.key); end, true);
	else
		eval_respawn(true, gconfig_get("extcon_path"));
	end

-- invocation from config change, anything after this isn't relevant
	if (not valid_vid(source)) then
		return;
	end

-- switch attachment immediately to new display
	local ap = active_display(true);
	if (ap ~= nil) then
		rendertarget_attach(ap, source, RENDERTARGET_DETACH);
	end

-- exceeding limits, ignore for now
	if (extcon_wndcnt >= gconfig_get("extcon_wndlimit") and
		gconfig_get("extcon_wndlimit") > 0) then
		delete_image(source);
	else
		extcon_wndcnt = extcon_wndcnt + 1;
-- allow 'per connpath' connection interception to modify wnd post creation
-- but pre-attachment
		local wargs = extevh_run_intercept(status.key);
		local wnd = durden_launch(source, "", "external", nil, wargs);
-- tell the new connection where to go in the event of a crash
		durden_devicehint(source);
		if (wnd) then
			wnd:add_handler("destroy",
				function()
					extcon_wndcnt = extcon_wndcnt - 1;
				end
			);
		end
		wnd.external_connection = true;
		local neww, newh = wnd.wm:suggest_size();
		wnd:displayhint(neww, newh, wnd.dispmask, wnd.wm.disptbl);
	end
end

eval_respawn = function(manual, path)
	local lim = gconfig_get("extcon_wndlimit");
	local period = gconfig_get("extcon_rlimit");
	local count = 0;

	for disp in all_tilers_iter() do
		count = count + #disp.windows;
	end

-- if it's not the time to allow more connection, schedule a hidden
-- one-fire timer that re-runs this function
	if ((lim > 0 and count > lim) and not manual) then
		timer_add_periodic("extcon_activation", period, true,
			function() eval_respawn(false, path); end, true);
		return;
	end

	INCOMING_ENDPOINT = target_alloc(path, durden_new_connection);

	if (valid_vid(INCOMING_ENDPOINT)) then
		image_tracetag(INCOMING_ENDPOINT, "nonauth_connection");
		if (gconfig_get("gamma_access") == "all") then
			target_flags(INCOMING_ENDPOINT, TARGET_ALLOWCM, true);
		end
	else
		timer_add_periodic("excon_reset", 100, true,
			function() eval_respawn(true, path); end, true);
	end
end

--
-- This will likely burst device events in the beginning that we
-- don't really care to show, so wait a few hundred ticks before
-- adding notifications
--
function durden_iostatus_handler(iotbl)
	local cutoff = gconfig_get("device_notification");
	local dev = iotbl.devkind and iotbl.devkind or "unknown";
	local label = iotbl.label and iotbl.label or "unknown";

	if (iotbl.action == "added") then
		if cutoff >= 0 and CLOCK > cutoff then
			notification_add("Device", nil, "Added", iotbl.label, 1);
		end

		if (dev == "led") then
			ledm_added(iotbl);
		else
		end
	elseif (iotbl.action == "removed") then
		if cutoff >= 0 and CLOCK > cutoff then
			notification_add("Device", nil, "Removed", iotbl.label, 1);
		end

		if (iotbl.devkind == "led") then
			ledm_added(iotbl);
		else
			iostatem_removed(iotbl);
		end
	end
end

function durden_display_state(action, id, state)
	local new_wm = display_event_handler(action, id);
	if (new_wm) then
		table.insert(new_wm, wnd_create_handler);
	end

	if (state and state.ledctrl) then
		display_set_backlight(id, state.ledctrl, state.ledind);
	end
end

local input_devhs = {};
-- for some complex or hybrid devices, we want the option of
-- being able to take priority in manipulating or mutating iotbl state
function durden_register_devhandler(devid, func, ctx)
	input_devhs[devid] = {func, ctx};
end

function durden_normal_input(iotbl, fromim)
-- we track all iotbl events in full debug mode
	if (iotbl.kind == "status") then
		durden_iostatus_handler(iotbl);
		return;
	end

	ievcount = ievcount + 1;
	local devh = input_devhs[iotbl.devid];
	if (devh) then
		if (not devh[1](devh[2], iotbl)) then
			return;
		end
	end

-- iostate manager takes care of mapping or translating 'game' devices,
-- device added/removed events, stateful "per window" tracking and
-- "autofire" or "repeat" injections but ignores mice and keyboard devices.
	if (not fromim) then
		if (iostatem_input(iotbl)) then
			return;
		end
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

-- there is a dark side here in that the idle timers are not considered for
-- touch events that do not present a digital ('press') output, only ranges
-- of analog. This means that gesture analysis need to feed back for these
-- kinds of devices, particularly when their noise-floor/ceiling is moving
-- with the environment.
		timer_reset_idle();
	end

-- after that we have special handling for mouse motion and presses,
-- any forwarded input there is based on event reception in listeners
-- attached to mouse motion or presses.
	if (iotbl.mouse) then
		if (mouse_blocked()) then
			return;
		end

		mouse_iotbl_input(iotbl);
		return;
	end

-- try the input_table function, if it consumes the input, ok - otherwise
-- try and forward to the display fallback input handler (like the wallpaper)
local sel = active_display().selected;
	if (not sel or not sel:input_table(iotbl)) then
		if (active_display().fallthrough_ioh) then
			active_display():fallthrough_ioh(iotbl);
			return;
		end
	end

--	if (iotbl.digital) then
--	active_display():message(string.format("sym: %s, label: %s %s",
--		SYMTABLE[iotbl.keysym] and SYMTABLE[iotbl.keysym] or "none",
--		iotbl.label and iotbl.label or "none", iotbl.active and "pressed" or
--		"released"));
--	elseif (iotbl.touch) then
--		active_display():message(string.format("touch: %d, %d, %s",
--			iotbl.devid, iotbl.subid, iotbl.active and "press" or "release"));
--	end
end

-- special case: (UP, DOWN, LEFT, RIGHT + mouse motion is mapped to
-- manipulate the mouse_select_begin() mouse_select_end() region,
-- ESCAPE cancels the mode, end runs whatever trigger we set (global).
-- see 'select_region_*' global functions + some button to align
-- with selected window (if any, like m1 and m2)
function durden_regionsel_input(iotbl, fromim)
	if (iotbl.kind == "status") then
		durden_iostatus_handler(iotbl);
		return;
	end

-- feed iostatem so that we get repeats
	if (not fromim) then
		if (iostatem_input(iotbl)) then
			return;
		end
	end

	if (iotbl.translated and iotbl.active) then
		local sym, lutsym = SYMTABLE:patch(iotbl);

		if (SYSTEM_KEYS["cancel"] == sym) then
			suppl_region_stop(DURDEN_REGIONFAIL_TRIGGER);
		elseif (SYSTEM_KEYS["accept"] == sym) then
			suppl_region_stop(DURDEN_REGIONSEL_TRIGGER);
		elseif (SYSTEM_KEYS["meta_1"] == sym) then
			mouse_select_set();
		elseif (SYSTEM_KEYS["meta_2"] == sym) then
			local rt = active_display(true);
			local mx, my = mouse_xy();
			local items = pick_items(mx, my, 1, true, rt);
			if (#items > 0) then
				mouse_select_set(items[1]);
			end
-- keyboard mouse navigation, could probably be moved to some
		elseif (SYSTEM_KEYS["left"] == sym) then
			local mx, my = mouse_xy();
			mouse_absinput(mx-8, my);
		elseif (SYSTEM_KEYS["right"] == sym) then
			local mx, my = mouse_xy();
			mouse_absinput(mx+8, my);
		elseif (SYSTEM_KEYS["next"] == sym) then
			local mx, my = mouse_xy();
			mouse_absinput(mx, my-8);
		elseif (SYSTEM_KEYS["previous"] == sym) then
			local mx, my = mouse_xy();
			mouse_absinput(mx, my+8);
		end

	elseif (iotbl.mouse and not mouse_blocked()) then
		if (iotbl.digital) then
			suppl_region_stop(DURDEN_REGIONSEL_TRIGGER);
		else
			mouse_iotbl_input(iotbl);
		end
	end
end

-- no keyrepeat, only forward to timer and wm, used for the
-- system/lock=key state.
function durden_locked_input(iotbl)
	if (iotbl.kind == "status") then
		durden_iostatus_handler(iotbl);
		return;
	end

	if (not iotbl.translated) then
		return;
	end

	timer_reset_idle();

-- notranslate option will still forward to WM and allows meta- guard to work,
-- but nothing else. So it should not be possible to set lock, plug/unplug
-- keyboard, hammer for meta-state and then get rid if locked state.
	local ok, outsym, iotbl = dispatch_translate(iotbl, true);
end

durden_input = durden_normal_input;

function durden_shutdown()
	SYMTABLE:store_translation();
	CLIPBOARD:save("clipboard_data.lua");
	display_manager_shutdown();
	gconfig_shutdown();
end

-- we ignore multicast for mouse, so target_input rather than input_table
-- works fine here and elsewhere
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

function durden_clock_pulse(n, nt)
-- if we experience stalls that give us multiple batched ticks
-- we don't want to forward this to the iostatem_ as that can
-- generate storms of repeats
	if (nt == 1) then
		local tt = iostatem_tick();
		if (tt) then
			for k,v in ipairs(tt) do
				durden_input(v, true);
			end
		end
	end

-- and mouse may populate the target-pending queue,
	mouse_tick(1);

-- anything periodically attached to a single tiler should be done now
	display_tick();

-- led devices can have custom or periodic effect, so also need clock
	ledm_tick();

-- forward to third parties
	flush_pending();

-- this should only be for tracking, so order-independent
	dispatch_tick();
end

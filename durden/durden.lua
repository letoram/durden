-- Copyright: 2015-2020, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: Main setup for the Arcan/Durden desktop environment

-- Global used to track input events that should be aligned to clock
-- tick for rate-limit and timing purposes
EVENT_SYNCH = {};

local update_default_font, update_connection_path;
local load_configure_mouse;
local setup_external_connection;
local conn_log, conn_fmt;

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
	rendertarget_reconfigure(WORLDID, 38.4, 38.4);

	system_load("builtin/mouse.lua")(); -- mouse gestures (in distribution)
	system_load("builtin/string.lua")();
	system_load("builtin/table.lua")();
	system_load("suppl.lua")(); -- convenience functions
	system_load("gconf.lua")(); -- configuration management
	system_load("listen.lua")(); -- rate-limiting for external connection points
	system_load("icon.lua")(); -- generate and manage user icons
	system_load("shdrmgmt.lua")(); -- shader format parser, builder
	system_load("uiprim/uiprim.lua")(); -- ui primitives
	system_load("menu.lua")(); -- menu subsystem
	system_load("timer.lua")(); -- timers, will hook clock_pulse
	system_load("notification.lua")(); -- queue of message+descriptions

	CLIPBOARD = system_load("clipboard.lua")(); -- clipboard filtering / mgmt
	CLIPBOARD:load("clipboard_data.lua");

	update_default_font();

	system_load("dispatch.lua")(); -- UI keyboard routing / management
	system_load("tiler.lua")(); -- window management
	system_load("uimap.lua")(); -- map uiprim/* to tiler etc.
	system_load("menus/menus.lua")(); -- root of menu virtual filesystem

	system_load("input/devstate.lua")(); -- device detection, repeat rate, ..

	system_load("ledm.lua")(); -- led controllers
	system_load("display.lua")(); -- multidisplay management
	system_load("ipc.lua")(); -- status and command channels

	system_load("extevh.lua")(); -- handlers for external events

	kbd_repeat(0, 0);

-- if we don't have a keyboard or any other input devices available here
-- there should be some kind of user interface to indicate that

	SYMTABLE = system_load("builtin/keyboard.lua")();
	SYMTABLE:load_translation();
	SYMTABLE:load_keymap("default.lua");

	load_configure_mouse();

-- display manager will invoke the callback (tiler_create from tiler.lua)
-- expected methods in the returned structure:
--  set_rendertarget(on or off)
--  activate(), deactivate()
--  tick()
--  resize(w, h, force)
--
-- (currently expected but to be refactored)
--  empty_space(ind)
--  update_scalef(factor, disptbl)
--  set_background()

	local nt = display_manager_init(
	function(ddisp)
		local res = tiler_create(ddisp.w, ddisp.h,
			{
				name = string.hexenc(ddisp.name),
				scalef = ddisp.ppcm / 38.4,
				disptbl = {ppcm = ddisp.ppcm, width = ddisp.w, h = ddisp.h},
				sbar_custom = gconfig_statusbar_buttons
			}
		);

-- default click actions
		res.buttons = gconfig_buttons;
		res.status_lclick = function() dispatch_symbol("/global"); end
		res.status_rclick = function() dispatch_symbol("/target"); end
		return res;
	end);

-- buttons with the set that is loaded / stored in gconf.lua
	nt.buttons = gconfig_buttons;
	conn_log, conn_fmt = suppl_add_logfn("connection");

-- tools are quick 'drop-ins' to get additional features like modelviewer
	suppl_scan_tools();
	suppl_scan_widgets();

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

-- init script, force-write to db
	if (gconfig_get("first_run")) then
		gconfig_set("first_run", false, true);
		system_load("firstrun.lua")();
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

-- this is forwarded as a global between executions if the crash recovery is
-- made, and contains a user contribution through the fatal handler, as well as
-- a backtrace
	if (CRASH_SOURCE and string.len(CRASH_SOURCE) > 0) then
		notification_add(
			"Durden", nil, "Crash", CRASH_SOURCE, 4);
	end

	setup_external_connection();
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
	else
		setup_external_connection()
	end

	for tiler in all_tilers_iter() do
		for i, wnd in ipairs(tiler.windows) do
			durden_devicehint(wnd.external);
		end
	end
end

local last_extcon;
setup_external_connection = function()
-- can happen if the connection point config entry is changed
	if last_extcon then
		listen_cancel(last_extcon);
		last_extcon = nil;
	end

-- no-op
	local path = gconfig_get("extcon_path");
	if (path == ":disabled") then
		return;
	end
	last_extcon = path;

	listen_ratelimit(path,
-- eval
	function()
		local count = 0;
		local wnd_lim = gconfig_get("extcon_wndlimit")
		if wnd_lim <= 0 then
			conn_log("eval=ok:no_limit");
			return true;
		end

-- count all externally tagged windows, this does not cover subsegments,
-- though most implementations impose other limits (e.g. only one popup)
		for wnd in all_windows(nil, true) do
			if wnd.external_connection then
				count = count + 1;
			end
		end

		if count < wnd_lim then
			conn_log(conn_fmt("eval=ok:wnd_count=%d:total=%d", count, wnd_lim));
			return true;
		else
			conn_log(conn_fmt("eval=fail:wnd_count=%d:total=%d", count, wnd_lim));
			return false;
		end
	end,
-- handler
	function(source, status, ...)
		local ap = active_display(true);
		if ap ~= nil then
			rendertarget_attach(ap, source, RENDERTARGET_DETACH);
		end

-- this will update the event handler to wait for the register event
-- and switch to the proper type and handler when that is known
		local wnd = durden_launch(source, "", "external", nil, wargs);
		wnd.external_connection = true;

		if not wnd then
			delete_image(source)
			return
		end

-- tell the client to just reconnect on crash to the last one we knew
		durden_devicehint(source);

-- enable external- connection specific flags, others have a path on
-- launch (e.g. menus/global/open.lua)
		if gconfig_get("gamma_access") == "all" then
			target_flags(source, TARGET_ALLOWCM, true)
		end
	end,
-- grace period
	gconfig_get("extcon_startdelay"),
	gconfig_get("extcon_rlimit")
	);
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

-- ideally we should switch this over to use the same icon setup and configuration
-- as the normal icon controls now that they exist, should give SDF resampling etc.
-- for a cheaper price and not use terrible scaling in mixed-DPI
	local set = gconfig_get("mouse_cursorset");
-- 65531..5 is a hidden max_image_order range (for cursors, overlays..)
	mouse_setup(load_cursor("default", set), 65535, 1, true, false);

-- preload cursor states
	mouse_add_cursor("drag", load_cursor("drag", set), 0, 0); -- 7, 5
	mouse_add_cursor("wait", load_cursor("wait", set), 0, 0);
	mouse_add_cursor("forbidden", load_cursor("forbidden", set), 0, 0);
	mouse_add_cursor("help", load_cursor("help", set), 0, 0);
	mouse_add_cursor("hand", load_cursor("pointer", set), 0, 0);
	mouse_add_cursor("cell", load_cursor("cell", set), 0, 0);
	mouse_add_cursor("alias", load_cursor("alias", set), 0, 0);
	mouse_add_cursor("col-resize", load_cursor("rz_col", set), 0, 0);
	mouse_add_cursor("sizeall", load_cursor("rz_all", set), 0, 0);
	mouse_add_cursor("typefield", load_cursor("typefield", set), 0, 0);
	mouse_add_cursor("grabhint", load_cursor("grabhint", set), 0, 0);
	mouse_add_cursor("rz_diag_l", load_cursor("rz_diag_l", set), 0, 0);
	mouse_add_cursor("rz_diag_r", load_cursor("rz_diag_r", set), 0, 0);
	mouse_add_cursor("rz_down", load_cursor("rz_down", set), 0, 0);
	mouse_add_cursor("rz_left", load_cursor("rz_left", set), 0, 0);
	mouse_add_cursor("rz_right", load_cursor("rz_right", set), 0, 0);
	mouse_add_cursor("rz_up", load_cursor("rz_up", set), 0, 0);
	mouse_add_cursor("zoom-in", load_cursor("zoom-in.png", set), 0, 0);
	mouse_add_cursor("zoom-out", load_cursor("zoom-out.png", set), 0, 0);

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
-- mouse locking and update border states. This is setup through the dispatch
-- initialisation and can be reached through a number of paths and gestures.
--
function durden_lock_toggle(newst, state)
	if ((not active_display().selected and
		not active_display().lock_override) and newst) then
		dispatch_toggle(false);
		return;
	end

-- in some patterns the default 'disable' can only be reached through a keyboard
-- device, which means some might not know / understand the effect or reason.
	for i in all_tilers_iter() do
		i.sbar_ws["msg"]:switch_state(newst and "locked" or "active");
	end

--reflect the lock state in the statusbar for the input-grab display
	active_display():tile_update();
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
		conn_log("broken_launch:reason=invalid_vid");
		return;
	end

	if (not wnd) then
		wnd = active_display():add_hidden_window(vid, wargs);
		if (not wnd) then
			delete_image(vid);
			return;
		end
	end

-- hidden window creation failed or event during creation triggered
-- destruction immediately, hence the table will be empty
	if (not wnd.set_prefix) then
		conn_log("broken_launch:reason=wnd_creation");
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
		conn_log(conn_fmt("adopt=%d:kind=unknown:reject_wnd", vid));
		return false;
	end

-- fake trigger the meta guard as we likely come from a working reset/
-- silent restart where the feature is just an annoyance
	meta_guard(true, true);

-- need to re-attach so they don't end up racing to the wrong display
	local ap = display_attachment();
	if (ap ~= nil) then
		rendertarget_attach(ap, vid, RENDERTARGET_DETACH);
	end

-- otherwise, ignore subsegments - let the client re-request them as needed
	if (valid_vid(parent)) then
		conn_log(conn_fmt("adopt=%d:kind=%s:reject_subsegment", vid, kind));
		return;
	end

-- build a new window with the old title etc.
	local wnd = durden_launch(vid, title);
	if (not wnd) then
		conn_log(conn_fmt("adopt=%d:kind=%s:reject_wnd", vid, kind));
		return;
	end

-- and fake a registered event to make the archetype apply
	extevh_default(vid, {
		kind = "registered",
		segkind = kind,
		title = string.len(title) > 0 and title or tostring(kind),
		source_audio = BADID
	});
	conn_log(conn_fmt("adopt=%d:kind=%s:parent=%d", vid, kind, parent));

-- some atypes may still have 'attach_block' where this becomes a noop
	if (wnd.ws_attach) then
		wnd:ws_attach();
		table.insert(adopt_new, wnd);
	end

-- wait until last adoption call before doing relayout etc.
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
		space:resize();
	end

-- the statusbar and other dependents are not necessarily synched on
-- ws_attach operations, so need to do this manually
	for disp in all_tilers_iter() do
		disp:tile_update();
-- an ugly hack to reset selection state
		disp:switch_ws(2);
		disp:switch_ws(1);

		local key = get_key("tiler_" .. disp.name .. "_sel");

		if key and tonumber(key) then
			disp:switch_ws(tonumber(key));
		end
	end

	adopt_new = {};
	return true;
end

-- This will likely burst device events in the beginning that we
-- don't really care to show, so wait a few hundred ticks before
-- adding notifications
--
function durden_iostatus_handler(iotbl)
	local dev = iotbl.devkind and iotbl.devkind or "unknown";

	if (iotbl.action == "added") then
		if (dev == "led") then
			ledm_added(iotbl);
		else
			iostatem_added(iotbl);
		end

	elseif (iotbl.action == "removed") then
		if (iotbl.devkind == "led") then
			ledm_added(iotbl);
		else
			iostatem_removed(iotbl);
		end
	end

end

function durden_display_state(action, id, state)
	display_event_handler(action, id);

	if (state and state.ledctrl) then
		display_set_backlight(id, state.ledctrl, state.ledind);
	end
end

function durden_normal_input(iotbl, fromim)
-- we track all iotbl events in full debug mode
	if (iotbl.kind == "status") then
		durden_iostatus_handler(iotbl);
		return;
	end

	ievcount = ievcount + 1;

-- iostate manager takes care of mapping or translating 'game' devices,
-- device added/removed events, stateful "per window" tracking and
-- "autofire" or "repeat" injections. It may also route to registered
-- input tools. Any processed results might injected back, and that's
-- the 'fromim' tag.
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
		timer_reset_idle();
		return;
	end

-- try the input_table function, if it consumes the input, ok - otherwise
-- try and forward to the display fallback input handler (like the wallpaper)
	local sel = active_display().selected;
	if (not sel or not sel.input_table or not sel:input_table(iotbl)) then
		if (active_display().fallthrough_ioh) then
			active_display():fallthrough_ioh(iotbl);
			return;
		end
	end
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

	local m2_set = function()
		local rt = active_display(true);
		local mx, my = mouse_xy();
		local items = pick_items(mx, my, 1, true, rt);
		if (#items > 0) then
			mouse_select_set(items[1]);
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
-- keyboard mouse navigation, could probably be moved to some
			m2_set();
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
			if iotbl.subid == MOUSE_RBUTTON then
				mouse_select_set();
			elseif iotbl.subid == MOUSE_MBUTTON then
				m2_set();
-- possible uniform-extend on wheel?
			else
				suppl_region_stop(DURDEN_REGIONSEL_TRIGGER);
			end
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

-- we don't want to mutate the entry-point as that would interfere with
-- user provided hookscripts from woring properly, provide an indirection
-- and a logging interface for switching
local current_input = durden_normal_input;
function durden_input(...)
	return current_input(...)
end

local ilog;
function durden_input_sethandler(handler, name)
	if not ilog then
		ilog = suppl_add_logfn("idevice");
	end

	if not handler then
		ilog("new input handler: default/normal");
		current_input = durden_normal_input;
	else
		if handler == current_input then
			return false
		end
		ilog("new input handler: " .. name);
		current_input = handler;
	end
	return true
end

function durden_shutdown()
	SYMTABLE:store_translation();
	CLIPBOARD:save("clipboard_data.lua");
	display_manager_shutdown();
	iostatem_shutdown();
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

-- some code need to be run in contexts where timer based processing won't
-- accidentally trigger another path, allow the clock-pulse to be masked out
local clock_blocked;
function durden_clock_block(cb)
	if clock_blocked then
		cb();
		return;
	end
	clock_blocked = durden_clock_pulse;
	durden_clock_pulse = function() end;
	cb();
	durden_clock_pulse = clock_blocked;
	clock_blocked = nil;
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

-- open question is if we should burn this hook to store state and
-- changes to keybinding etc. for better recovery, downside is that
-- there is the possiblity we save a 'guaranteed broken' state.
function durden_fatal(msg)
	local lsym = dispatch_last_symbol and dispatch_last_symbol() or "pre-init"
	local msg = string.format(
		"error: %s\nlast path: %s\ntrace:\n%s",
		msg, lsym, debug.traceback()
	);
	return msg;
end

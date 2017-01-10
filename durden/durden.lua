-- Copyright: 2015-2016, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: Main setup for the Arcan/Durden desktop environment

-- Global used to track input events that should be aligned to clock
-- tick for rate-limit and timing purposes
EVENT_SYNCH = {};

local wnd_create_handler, update_default_font, update_connection_path;
local eval_respawn;

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
	system_load("mouse.lua")(); -- mouse gestures
	system_load("gconf.lua")(); -- configuration management
	system_load("shdrmgmt.lua")(); -- shader format parser, builder
	system_load("uiprim.lua")(); -- ui primitives (buttons!)
	system_load("lbar.lua")(); -- used to navigate menus
	system_load("bbar.lua")(); -- input binding
	system_load("suppl.lua")(); -- convenience functions
	system_load("timer.lua")(); -- timers, will hook clock_pulse

	update_default_font();

	system_load("keybindings.lua")(); -- static key configuration
	system_load("tiler.lua")(); -- window management
	system_load("browser.lua")(); -- quick file-browser
	system_load("iostatem.lua")(); -- input repeat delay/period
	system_load("display.lua")(); -- multidisplay management
	system_load("extevh.lua")(); -- handlers for external events
	system_load("iopipes.lua")(); -- status and command channels
	CLIPBOARD = system_load("clipboard.lua")(); -- clipboard filtering / mgmt
	CLIPBOARD:load("clipboard_data.lua");

-- functions exposed to user through menus, binding and scripting
	system_load("fglobal.lua")(); -- tiler- related global functions
	system_load("menus/global/global.lua")(); -- desktop related global
	system_load("menus/target/target.lua")(); -- shared window related global

	kbd_repeat(0, 0);

-- tools are quick 'drop-ins' to get additional features like modelviewer
	local list = glob_resource("tools/*.lua", APPL_RESOURCE);
	for k,v in ipairs(list) do
		local res = system_load("tools/" .. v, 0);
		if (not res) then
			warning(string.format("couldn't parse tool: %s", v));
		else
			local okstate, msg = pcall(res);
			if (not okstate) then
				warning(string.format("runtime error loading tool: %s - %s", v, msg));
				print(msg);
			end
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
	SYMTABLE:load_keymap("default.lua");

	if (gconfig_get("mouse_hardlock")) then
		toggle_mouse_grab(MOUSE_GRABON);
	end

	if (gconfig_get("mouse_mode") == "native") then
		mouse_setup_native(load_image("cursor/default.png"), 0, 0);
	else
-- 65531..5 is a hidden max_image_order range (for cursors, overlays..)
		mouse_setup(load_image("cursor/default.png"), 65535, 1, true, false);
	end

	local nt = display_manager_init();
	nt.on_wnd_create = wnd_create_handler;

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

-- preload cursor states
	mouse_add_cursor("drag", load_image("cursor/drag.png"), 0, 0); -- 7, 5);
	mouse_add_cursor("grabhint", load_image("cursor/grabhint.png"), 0, 0); --, 7, 10);
	mouse_add_cursor("rz_diag_l", load_image("cursor/rz_diag_l.png"), 0, 0); --, 6, 5);
	mouse_add_cursor("rz_diag_r", load_image("cursor/rz_diag_r.png"), 0, 0); -- , 6, 6);
	mouse_add_cursor("rz_down", load_image("cursor/rz_down.png"), 0, 0); -- 5, 13);
	mouse_add_cursor("rz_left", load_image("cursor/rz_left.png"), 0, 0); -- 0, 5);
	mouse_add_cursor("rz_right", load_image("cursor/rz_right.png"), 0, 0); -- 13, 5);
	mouse_add_cursor("rz_up", load_image("cursor/rz_up.png"), 0, 0); -- 5, 0);
	switch_default_texfilter(FILTER_NONE);

	audio_gain(BADID, gconfig_get("global_gain"));

-- load saved keybindings
	dispatch_load(durden_lock_toggle);
	iostatem_init();

	mouse_reveal_hook(gconfig_get("mouse_reveal"));

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

	if (gconfig_get("first_run")) then
		gconfig_set("first_run", false);
		meta_guard_reset(true);
	end
end

argv_cmds["dump_menus"] = function()
	for k,v in ipairs(get_menu_tree(get_global_menu(), '!')) do
		print(v);
	end

	local nsurf = null_surface(32, 32);
	local wnd = active_display():add_window(nsurf);

	for k,v in ipairs(get_menu_tree(get_shared_menu(), '#')) do
		print(v);
	end

	return shutdown();
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
		disp.font_sf = rfhf;
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
	if (not neww or not newh or wnd.block_resize) then
		return;
	end

	if (neww > 0 and newh > 0) then
		if (valid_vid(wnd.external, TYPE_FRAMESERVER)) then
			local props = image_storage_properties(wnd.external);

-- ignore resize- step limit (terminal) if we are not in drag resize
			if (not mouse_state().drag or not wnd.sz_delta or
				(math.abs(props.width - efw) > wnd.sz_delta[1] or
			   math.abs(props.height - efh) > wnd.sz_delta[2])) then
				target_displayhint(wnd.external, efw, efh, wnd.dispmask);
			end
		end

		if (valid_vid(wnd.titlebar_id)) then
			target_displayhint(wnd.titlebar_id,
				wnd.width - wnd.border_w * 2, gconfig_get("tbar_sz"));
		end
	end
end

function durden_tbar_buttons(dir, cmd, lbl)
	if (not dir) then
		tbar_btns = {};
	else
		table.insert(tbar_btns, {
			dir = dir, cmd = cmd, lbl = lbl
		});
	end
end

-- tiler does not automatically add any buttons to the statusbar, or take
-- other tracking actions based on window creation so we do that here
wnd_create_handler = function(wm, wnd)
	for k,v in ipairs(tbar_btns) do
		wnd.titlebar:add_button(v.dir, "titlebar_iconbg",
			"titlebar_icon", v.lbl, gconfig_get("sbar_tpad") * wm.scalef,
			wm.font_resfn, nil, nil, {
-- many complications hidden here as tons of properties can be changed between
-- dispatch_symbol and "restore old state"
				click = function(btn)
					local old_sel = wm.selected;
					wnd:select();
					dispatch_symbol(v.cmd);
					if (old_sel and old_sel.select) then
						old_sel:select();
					end
				end,
				over = function(btn)
					btn:switch_state("alert");
				end,
				out = function(btn)
					btn:switch_state(wm.selected == wnd and "active" or "inactive");
				end
			}
		);
	end
end

--
-- triggered by meta- state tracker, we need the hook here to also trigger
-- mouse locking and update border states
--
function durden_lock_toggle(newst, state)
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

function durden_launch(vid, prefix, title, wnd, external)
	if (not valid_vid(vid)) then
		return;
	end
	if (not wnd) then
		wnd = active_display():add_hidden_window(vid);
	end

-- hidden window creation failed or event during creation
-- triggered destruction immediately, hence the table will be empty
	if (not wnd or not wnd.set_prefix) then
		delete_image(vid);
		return;
	end

-- local keybinding->utf8 overrides, we map this to SYMTABLE
	wnd.u8_translation = {};

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
		wnd.dispatch = shared_dispatch();
		wnd.external = vid;
		extevh_register_window(vid, wnd);
		EVENT_SYNCH[wnd.external and wnd.external or wnd.canvas] = {
			queue = {},
			target = vid
		};
		if (wnd.wm.selected ~= wnd) then
			wnd:set_dispmask(TD_HINT_UNFOCUSED);
		end
	end

	return wnd;
end

-- recovery from crash is handled just like newly launched windows, one
-- big caveat though, these are attached to WORLDID but in the multidisplay
-- setup we have another attachment.
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

	if (not valid_vid(parent)) then
		local wnd = durden_launch(vid, title);
		if (not wnd) then
			return;
		end

		extevh_default(vid, {
			kind = "registered",
			segkind = kind,
			title = string.len(title) > 0 and title or tostring(kind),
-- a real resized event with the source audio will come immediately
			source_audio = BADID
		});
		if (wnd.ws_attach) then
			wnd:ws_attach();
		end
		return true;
	end

-- we don't save any subsegments, the frameserver should re-request on reset
-- local wnd = extevh_get_window(parent);
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
function durden_new_connection(source, status)
	if (status.kind ~= "connected") then
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
		if (extevh_intercept(status.key, source)) then
			return;
		end
		local wnd = durden_launch(source, "", "external", nil, "external");
-- tell the new connection where to go in the event of a crash
		durden_devicehint(source);
		if (wnd) then
			wnd:add_handler("destroy",
				function()
					extcon_wndcnt = extcon_wndcnt - 1;
				end
			);
		end
		target_displayhint(source,
			wnd.max_w - wnd.pad_left - wnd.pad_right,
			wnd.max_h - wnd.pad_top - wnd.pad_bottom,
			wnd.dispmask, wnd.wm.disptbl);

		wnd.external_connection = true;
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
-- OOM, retry later
	else
		timer_add_periodic("excon_reset", 100, true,
			function() eval_respawn(true, path); end, true);
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
		mid_v[iotbl.subid+1] = iotbl.samples[1];
		mid_c = mid_c + 1;

		if (mid_c == 2) then
			mouse_absinput(mid_v[1], mid_v[2]);
			mid_c = 0;
		end
	end
end

-- shared between the other input forms (normal, locked, ...)
function durden_iostatus_handler(iotbl)
	if (iotbl.label and string.len(iotbl.label) > 0) then
		active_display():message(string.format("%s: %s",
			iotbl.action, iotbl.label));
	else
		active_display():message(string.format("%s %d",
			iotbl.action, iotbl.devid));
	end

	if (iotbl.action == "added") then
		iostatem_added(iotbl);

	elseif (iotbl.action == "removed") then
		iostatem_removed(iotbl);
	end
end

function durden_display_state(action, id, state)
	local new_wm = display_event_handler(action, id);
	if (new_wm) then
		new_wm.on_wnd_create = wnd_create_handler;
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
		timer_reset_idle();
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

--	if (iotbl.digital) then
--	active_display():message(string.format("sym: %s, label: %s %s",
--		SYMTABLE[iotbl.keysym] and SYMTABLE[iotbl.keysym] or "none",
--		iotbl.label and iotbl.label or "none", iotbl.active and "pressed" or
--		"released"));
--	elseif (iotbl.touch) then
--		active_display():message(string.format("touch: %d, %d, %s",
--			iotbl.devid, iotbl.subid, iotbl.active and "press" or "release"));
--	end

-- when in doubt, just forward to the window, it will take care of
-- multicast groups etc.
	sel:input_table(iotbl);
end

-- special case: (UP, DOWN, LEFT, RIGHT + mouse motion is mapped to
-- manipulate the mouse_select_begin() mouse_select_end() region,
-- ESCAPE cancels the mode, end runs whatever trigger we set (global).
-- see 'select_region_*' global functions + some button to align
-- with selected window (if any, like m1 and m2)
function durden_regionsel_input(iotbl)
	if (iotbl.kind == "status") then
		durden_iostatus_handler(iotbl);
		return;
	end

	if (iotbl.translated and iotbl.active) then
		local sym, lutsym = SYMTABLE:patch(iotbl);

		if (SYSTEM_KEYS["cancel"] == sym) then
			mouse_select_end();
			iostatem_restore();
			durden_input = durden_normal_input;
		elseif (SYSTEM_KEYS["accept"] == sym) then
			mouse_select_end(DURDEN_REGIONSEL_TRIGGER);
			iostatem_restore();
			durden_input = durden_normal_input;
		elseif (SYSTEM_KEYS["meta_1"] == sym) then
			mouse_select_set();
		elseif (SYSTEM_KEYS["meta_2"] == sym) then
			local rt = active_display(true);
			local mx, my = mouse_xy();
			local items = pick_items(mx, my, 1, true, rt);
			if (#items > 0) then
				mouse_select_set(items[1]);
			end
		end

	elseif (iotbl.mouse) then
		if (iotbl.digital) then
			mouse_select_end(DURDEN_REGIONSEL_TRIGGER);
			iostatem_restore();
			durden_input = durden_normal_input;
		else
			mousemotion(iotbl);
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

-- forward to third parties
	flush_pending();

-- this should only be for tracking, so order-independent
	dispatch_tick();
end

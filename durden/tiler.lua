-- Copyright: 2015-2020, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Depends: display, shdrmgmt, lbar, suppl, mouse
-- Description: Tiler comprise the main tiling window management, event
-- routing, key interpretation and other hooks. It returns a single
-- creation function (tiler_create(W, H)) that returns the usual table
-- of functions and members in pseudo-OO style.

-- number of Z values reserved for each window
local WND_RESERVED = 100;

local ent_count = 1;

mouse_handler_factory = system_load("tiler_mh.lua")();

local function wnd_size_decor(wnd, w, h, animate)
end

local create_workspace = function() end
local tiler_logfun, tiler_fmt = suppl_add_logfn("wm");

local function tiler_debug(wm, msg)
	msg = msg and msg or "bad message";
	tiler_logfun(wm.name .. ":" .. msg);
end

local function is_tab_mode(str)
	return str == "tab" or str == "vtab" or str == "htab";
end

-- shared between all tiler instances
local latest_wnd_name;
function tiler_latest_window_name(set)
	if set then
		latest_wnd_name = set;
	end
	return latest_wnd_name;
end

-- returns:
-- position,scale,interpolation_function
local function wnd_animation_time(wnd, source, decor, position)
	local _, lm, _, ls = reset_image_transform(source);

-- if the window is just attached, or being dragged around, then early out
	if (wnd.attach_time == CLOCK or wnd.in_drag_rz) then
		return 0, 0, INTERP_SMOOTHSTEP;
	end

-- if the action is normal motion, then let the global config apply
	local at = gconfig_get("wnd_animation");
	if (position) then
		return at - lm, at - ls, INTERP_SMOOTHSTEP;
	end

-- only float / tile modes work for animation, and autocropped windows don't
-- work with animation as we don't have a universal texture coordinate animation
-- system
	if (not wnd.autocrop and
		( wnd.space.mode == "tile" or (wnd.space.mode == "float"))) then
		return at - lm, at - ls, INTERP_SMOOTHSTEP;
	end

-- autocrop still doesn't support animation
	return 0, 0, INTERP_SMOOTHSTEP;
end

local function wnd_synch_mouse(wnd, x, y)
	local props = image_surface_resolve(wnd.canvas);
	if (x >= props.x and y >= props.y and
		x <= props.x + props.width and y <= props.y + props.height) then
		wnd.mouse = {
			(x - props.x) / props.width,
			(y - props.y) / props.height
		};
	elseif not wnd.mouse then
		wnd.mouse = {0, 0};
	end
end

local function linearize(wnd)
	local res = {};
	local dive =
	function(wnd, df)
		if (wnd == nil or wnd.children == nil) then
			return;
		end

		for i,v in ipairs(wnd.children) do
			table.insert(res, v);
			df(v, df);
		end
	end

	dive(wnd, dive);
	return res;
end

local function get_disptbl(wnd, tbl)
	if (tbl and wnd.density_override) then
		local cpy = {};
		for k,v in pairs(tbl) do
			cpy[k] = v;
		end
		cpy.ppcm = wnd.density_override;
		return cpy;
	else
		return tbl;
	end
end

local function tbar_mode(mode)
	return mode == "tile" or mode == "float";
end

-- wrapped so that we can easily add support for variable sized titlebars,
-- possibly useful when dealing with touch interfaces where the 'cursor'
-- tends to be fatter.
local function tbar_geth(wnd)
	assert(wnd ~= nil);
	if (not wnd.space) then
		return 0;
	end

	if (wnd.show_titlebar and tbar_mode(wnd.space.mode)) then
		return math.floor(wnd.wm.scalef * gconfig_get("tbar_sz"));
	end

	return 0;
end

local function sbar_geth(wm, ign)
	if (ign) then
		return math.clamp(
			math.ceil(gconfig_get("sbar_sz") * wm.scalef),
			math.ceil(gconfig_get("sbar_min_sz") * wm.scalef)
		)
	else

		if gconfig_get("sbar_visible") ~= "desktop" or
			((wm.spaces[wm.space_ind] and
				wm.spaces[wm.space_ind].mode == "fullscreen")) then
					wm.statusbar:hide();
					return 0;
		else
			return math.clamp(
				math.ceil(gconfig_get("sbar_sz") * wm.scalef),
				math.ceil(gconfig_get("sbar_min_sz") * wm.scalef)
			)
		end
	end
end

local function sbar_hide(wm)
	wm.statusbar:hide();
	wm.hidden_sb = true;
end

local function sbar_show(wm)
	wm.statusbar:show();
	wm.hidden_sb = false;
end

local function run_event(wnd, event, ...)
	if not wnd.handlers then
		tiler_logfun(event .. "on broken window");
		return
	end

	assert(wnd.handlers[event])
	for i,v in ipairs(wnd.handlers[event]) do
		v(wnd, unpack({...}));
	end
end

local function wnd_titlebar_to_statusbar(wnd)
	if (
		not wnd.titlebar or
		not wnd.titlebar.hidden or
		not gconfig_get("titlebar_statusbar") or
		not tbar_mode(wnd.space.mode)
	) then
		return;
	end

	wnd.wm.statusbar:set_nested(wnd.titlebar,
		function(destr)
			if (not wnd.titlebar) then
				return; -- already destroyed
			end

			local bw = wnd:border_width();
			wnd.titlebar:reanchor(wnd.anchor, 4, bw, bw);

			if (wnd.show_titlebar) then
				wnd.titlebar:show();
			else
				wnd.titlebar:hide();
			end
		end
	);

	wnd.space:resize();
end

local function moveup_children(wnd)
	if (not wnd.parent) then
		return;
	end

	local n = 0;
	local ind = table.find_i(wnd.parent.children, wnd);
	for i,v in ipairs(wnd.children) do
		table.insert(wnd.parent.children, ind+i, v);
		v.parent = wnd.parent;
	end
	table.remove(wnd.parent.children, ind);
end

local function wnd_border_width(wnd)
--
-- This is slightly incomplete as we failed to take into account the difference
-- between border presence (may be needed for drag-resize etc.) and visibility,
-- returning 0 would break 'gaps' in layouting
--
--	if (not wnd.show_border) then
--		return 0;
--	end

	if (wnd.space.mode == "float") then
		return gconfig_get("borderw_float");
	elseif wnd.fullscreen then
		return 0;
	else
		return gconfig_get("borderw");
	end
end

--
-- Build an icon representation of the window
--
-- The lifecycle of the returned surface belongs to the caller and it won't
-- be updated to reflect window 'liveness' or similar properties, for such
-- tracking the caller should also subscribe to the relevant events.
--
local function wnd_iconify(wnd, opts)
	local minh = opts.size and opts.size or 64;

	local nsrf = null_surface(minh, minh);
	if not valid_vid(nsrf) then
		return;
	end

-- prefer icon segment if provided, otherwise fallback to canvas/contents
	if valid_vid(wnd.icon) then
		image_sharestorage(wnd.icon, nsrf);
	else
		image_sharestorage(wnd.canvas, nsrf);
	end

-- add a color-surface with a shader for the state (to indicate selection)
	if opts.background then
	end

-- add a text-strip
	if opts.label then
	end

	return nsrf;
end

local function wnd_destroy(wnd, message)
	local wm = wnd.wm;
	if (wnd.delete_protect) then
		return;
	end

-- 'un-swallow' a previous one
	if wnd.swallow_window and wnd.swallow_window.show then
		wnd.swallow_window:show()
	end

-- and if we are swallowed, make sure the owner forgets us
	if wnd.swallow_master then
		wnd.swallow_master.swallow_window = nil
	end

-- wnd-create - wnd-destroy behavior
	if latest_wnd_name == wnd.name then
		latest_wnd_name = nil;
	end

	if (message and type(message) == "string" and #message > 0) then
		notification_add(wnd.title, wnd.icon, "Client died", message, 1);
	end

	if (wm.deactivated and wm.deactivated.wnd == wnd) then
		wm.deactivated.wnd = nil;
	end

-- doesn't always hit, we want to forward this information to any
-- event handler as well since it might affect next-selected heuristics
	local was_selected = wnd.wm.selected == wnd;
	local sel_target;

-- copy the last selected window, and try to restore to that one first
	if was_selected then
		sel_target = wnd.space.last_selected ~= wnd and wnd.space.last_selected;
		wnd:deselect();
	end

-- if the window is currently fullscreen, we should switch mode back
-- to whatever the space was before fullscreen
	local space = wnd.space;
	if (space) then
		if (wnd.fullscreen) then
			space[wnd.fullscreen](space);
		end
	end

-- since the handler is deregistered when the canvas is destroyed,
-- we need to reset the mouse state no matter what has been done in
-- the mouse handler but the cursor can be outside of a window in
-- which case we don't want to trigger the 'out' handler.
	local mx, my = mouse_xy();
	if (mouse_over(wnd.canvas)) then
		mouse_switch_cursor("default");
		if (wnd.cursor == "hidden") then
			mouse_hidemask(true);
			mouse_show();
			mouse_hidemask(false);
		end
	end

	if (wm.deactivated and wm.deactivated.wnd == wnd) then
		wm.deactivated.wnd = nil;
	end

	mouse_droplistener(wnd.handlers.mouse.border);
	mouse_droplistener(wnd.handlers.mouse.canvas);

-- mark a new node as selected
	if (wnd.wm.selected == nil or wnd.wm.selected == wnd) then
		if sel_target and sel_target.select then
			sel_target:select();
		elseif (#wnd.children > 0) then
			wnd.children[1]:select();
		elseif (wnd.parent and wnd.parent.parent) then
			wnd.parent:select();
		else
			wnd:prev();
		end
	end

-- couldn't do that, mark nothing as selected
	if (wnd.wm.selected == wnd) then
		wnd.wm.selected = nil;
-- force auto-lock off so destroy on a selected window that has raw input
-- dosn't stick, but only if the tiler is the active display
		if (active_display() == wnd.wm) then
			dispatch_toggle(false);
		end
	end

-- deregister from space tracking
	if (space and wnd.space.selected == wnd) then
		space.selected = nil;
	end

-- re-assign all children to parent
	moveup_children(wnd);

-- now we can run destroy hooks
	run_event(wnd, "destroy", was_selected);
	tiler_debug(wm, "destroy:name=" .. wnd.name);

	wnd:drop_popup(true);

-- assigned a shader hook?
	if (wnd.shader_hook) then
		wnd:shader_hook();
	end

-- last step before deletion, any per-tiler hook?
	if (space) then
		space.last_action = CLOCK;
		for i,v in ipairs(wm.on_wnd_destroy) do
			v(wm, wnd, space, space == wm:active_space());
		end
	end

-- drop references, cascade delete from anchor
	delete_image(wnd.anchor);

	for i=1,10 do
		if (wm.spaces[i] and wm.spaces[i].selected == wnd) then
			wm.spaces[i].selected = nil;
		end

		if (wm.spaces[i] and wm.spaces[i].previous == wnd) then
			wm.spaces[i].previous = nil;
		end
	end

-- prevent the 'titlebar to statusbar" closure from running
	local tb = wnd.titlebar;
	wnd.titlebar = nil;
	tb:destroy();

-- external references are tracked separate from the canvas
	if valid_vid(wnd.external) then
		if not wnd.external_prot then
			delete_image(wnd.external);
		end
		EVENT_SYNCH[wnd.external] = nil;
	end

-- destroy all keys so any dangling references can be detected as such
	for k,v in pairs(wnd) do
		wnd[k] = nil;
	end

-- drop global tracking
	table.remove_match(wm.windows, wnd);

-- rebuild layout
	if (space) then
		if (not (space.layouter and space.layouter.lost(space, wnd, true))) then
			space:resize();
		end

		for k,v in pairs(space.listeners) do
			v(space, k, "lost", wnd);
		end
	end

-- reactivate the statusbar merging
	if (wm.selected) then
		wnd_titlebar_to_statusbar(wm.selected);
	end
end

local function wnd_message(wnd, message, timeout)
	local long;
	if (not message or string.len(message) == 0) then
		return;
	end

	local short =
		string.len(message) < 40 and message or string.sub(message, 1, 40);
	if (string.len(message) > 40) then
		long = message;
	end

-- only use a client icon if one is present, going with external here is
-- too expensive as the notification rendering (render_text) will scale-
-- blit on CPU.
	local storage;
	if (valid_vid(wnd.icon)) then
		storage = null_surface(32, 32);
		if (valid_vid(storage)) then
			image_sharestorage(wnd.icon, storage);
			image_tracetag(storage, "notification_icon", "notification");
		end
	end

	notification_add(
		string.sub(string.format("%s : %s", wnd.title, wnd.ident), 1, 20),
		storage, short, long, 1
	);
end

local function wnd_deselect(wnd, nopick)
	if (not wnd.space) then
		return;
	end

	local mwm = wnd.space.mode;
	wnd.space.last_selected = wnd;

-- no pick argument only happens on deactivate
	if (is_tab_mode(mwm) or mwm == "fullscreen") then
		if (not nopick) then
			hide_image(wnd.anchor);
			hide_image(wnd.border);
			if (wnd.shadow) then
				hide_image(wnd.shadow);
			end
		end
	end

-- remove from the current selected, and detach from the statusbar if the
-- window has its titlebar being dynamically embedded there
	if (wnd.wm.selected == wnd) then
		wnd.wm.selected = nil;
		wnd.wm.statusbar:set_nested();
		if wnd.titlebar.hidden then
			wnd.titlebar:hide();
		end
	end

-- don't keep a lock to the window either
	if (wnd.mouse_lock) then
		mouse_lockto(BADID);
	end

-- remove any popup chains that might be locked
	wnd:drop_popup(true);

-- forward state to the client
	wnd:set_dispmask(bit.bor(wnd.dispmask, TD_HINT_UNFOCUSED));

-- hide if the cursor should be hidden and it is actually over the surface
-- (needed when the selection ischanged via keyboard)
	local x, y = mouse_xy();
	if (image_hit(wnd.canvas, x, y) and wnd.cursor == "hidden") then
		mouse_hidemask(true);
		mouse_show();
		mouse_hidemask(false);
	end

-- switch the 'visual' state
	local state = wnd.suspended and "suspended" or "inactive";
	shader_setup(wnd.border, "ui",
		wnd.space.mode == "float" and "border_float" or "border", state);
	wnd.titlebar:switch_state(state, true);

-- different decoration shadow weights based on selection state
	if (wnd.shadow) then
		local focus = gconfig_get("shadow_defocus");
		if is_tab_mode(wnd.space.mode) or wnd.space.mode == "fullscreen" then
			focus = 0;
		end
		blend_image(wnd.shadow, focus);
	end

-- save scaled coordinates so we can handle a resize
	if (gconfig_get("mouse_remember_position")) then
		wnd_synch_mouse(wnd, x, y);
	end

-- run any other chained handlers, typically from autolayouters
	tiler_debug(wnd.wm, "deselect:name=" .. wnd.name);
	run_event(wnd, "deselect");
end

local function output_mouse_devent(btl, wnd)
	if (not valid_vid(wnd.external, TYPE_FRAMESERVER)) then
		return;
	end

	btl.kind = "digital";
	btl.mouse = true;

-- rate limit is used to align input event storms (likely to cause visual
-- changes that need synchronization) with the logic ticks (where the engine
-- is typically not processing rendering), and to provent the horrible
-- spikes etc. that can come with high-samplerate.
	if (not wnd.rate_unlimited) then
		local wndq = EVENT_SYNCH[wnd.external];
		if (wndq and (wndq.pending and #wndq.pending > 0)) then
			table.insert(wndq.queue, wndq.pending[1]);
			table.insert(wndq.queue, wndq.pending[2]);
			table.insert(wndq.queue, btl);
			wndq.pending = nil;
			return;
		end
	end

	target_input(wnd.external, btl);
end

-- different shadow routine here for the color and padding
local function update_sbar_shadow(wm)
	local sb = wm.statusbar;
	local opts = {
		t = gconfig_get("sbar_tshadow"),
		l = gconfig_get("sbar_lshadow"),
		d = gconfig_get("sbar_dshadow"),
		r = gconfig_get("sbar_rshadow"),
		color = gconfig_get("sbar_shadow_color"),
		method = gconfig_get("sbar_shadow")
	};

	local props = image_surface_resolve(sb.anchor)
	suppl_region_shadow(sb, props.width, props.height, opts);
end

local function prune_missing_known(wm, list)
	local known =
	function(btn)
		for i, disp in ipairs(list) do
			if btn.display and disp[1] == btn.display[1] and disp[2] == btn.display[2] then
				return i
			end
		end
	end

-- delete all buttons not in the list
	for btn in wm.statusbar:all_buttons() do
		local i = known(btn)
		if not i and btn.display then
			btn:destroy();
		elseif i then
			table.remove(list, i)
		end
	end

	return list
end

local function resolve_vsymbol(wm, label, base)
	local state, outlbl = suppl_valid_vsymbol(label);
	if not base or base <= 0 then
		base = sbar_geth(wm, true);
	end

-- in order for the titlebar group management to work, we can't just
-- return the vid itself, but rather need to provide a factory function
	if state then
		if type(outlbl) == "function" then
			return function(w)
				local surf = outlbl((w and w > 0) and w or base);
				image_tracetag(surf, "bar_vsym_" .. label, "titlebar " .. label);
				return surf;
			end
		else
			return outlbl;
		end
	end

	return "[bad]";
end


local function tiler_statusbar_update(wm)
-- synch constraints, first get the statusbar height ignoring visibility
	local bar_base = sbar_geth(wm, true);
	local xpos = 0;
	local pad_l = 0;
	local pad_r = 0;
	local pad_t = 0;
	local pad_d = 0;
	local autohide = gconfig_get("sbar_autohide")

-- consider visibility (fullscreen, or HUD mode affects it)
	local space = wm:active_space();
	local sb_invisible = space.mode == "fullscreen"

	if (gconfig_get("sbar_visible") == "hud") then
		sb_invisible = not tiler_lbar_isactive();
	elseif (gconfig_get("sbar_visible") == "hidden") then
		bar_base = sbar_geth(wm);
		sb_invisible = true;
	else
		bar_base = sbar_geth(wm);
	end
	wm.statusbar[sb_invisible and "hide" or "show"](wm.statusbar);

	if not sb_invisible and autohide == 0 then
		pad_l = math.floor(gconfig_get("sbar_lspace") * wm.scalef);
		pad_r = math.floor(gconfig_get("sbar_rspace") * wm.scalef);
		pad_t = math.floor(gconfig_get("sbar_tspace") * wm.scalef);
		pad_d = math.floor(gconfig_get("sbar_dspace") * wm.scalef);
	end

	local pad_h = pad_l + pad_r;
	local pad_v = pad_t + pad_d;
	local hide_base = 0

-- on autohide, ignore the pad calculations so effective_size are full
	local bar_ofs = 0
	hide_base = bar_base

	if autohide > 0 then
		bar_base = 0
		bar_ofs = 2
	end

-- Update background color and alpha
	local r, g, b = unpack(gconfig_get("sbar_color"));
	local alpha = gconfig_get("sbar_alpha");
	shader_update_uniform(wm.statusbar.shader,
		"ui", "col", { r / 255, g / 255, b / 255, alpha});

-- positioning etc. still needs the current size of the statusbar
	local pos = gconfig_get("sbar_position");
	local size = gconfig_get("sbar_sizepct");
	local bar_hide_dx = 0
	local bar_hide_dy = 0

-- lots of metrics in this one,
--
-- the wm anchor concern where all normal windows etc. are created from
-- and excludes the region occupied by the statusbar. The statusbar region
-- is excluded from that calculation if it is set to autohide.
--
-- this is also tracked by yoffset and xoffset.
--
-- the statusbar has its size, but also an optional padding region in
-- tldr (and t+d = v, l+r = h) to add 'space' around it.
--
-- that padding region is ignored in autohide (as it wouldn't make sense there)
--
-- for autohad we also need a few pixels visible for mouse hit detection to
-- trigger its hide/unhide action (bar_ofs).
--
	if (pos == "top") then
		local pad_w = math.floor((wm.width - (wm.width * 0.01 * size)) * 0.5)
		if autohide > 0 then
			wm.yoffset = 0
			wm.effective_height = wm.height
			wm.statusbar:move(xpos + pad_w + pad_l, -hide_base + bar_ofs + pad_t);
			move_image(wm.anchor, 0, wm.yoffset)
		else
			wm.yoffset = hide_base + pad_v;
			wm.effective_height = wm.height - wm.yoffset;
			wm.statusbar:move(xpos + pad_w + pad_h, pad_t)
			move_image(wm.anchor, 0, wm.yoffset)
		end

		wm.xoffset = 0;
		wm.effective_width = wm.width;
		wm.ylimit = wm.height;
		wm.xlimit = wm.width;
		wm.statusbar:set_horizontal();
		wm.statusbar:resize(wm.width - 2 * pad_w, hide_base);
		bar_hide_dx = 0
		bar_hide_dy = -(hide_base - bar_ofs)

	elseif (pos == "left") then
		local cap_h = math.floor((wm.height - (wm.height * 0.01 * size)) * 0.5)
		if autohide > 0 then
			wm.xoffset = 0
			wm.effective_width = wm.width
			wm.statusbar:move(-hide_base + bar_ofs + pad_l, pad_t + cap_h);
		else
			wm.yoffset = 0;
			wm.xoffset = hide_base + pad_h;
			wm.statusbar:move(pad_l, pad_t + cap_h);
		end

		wm.xlimit = wm.width;
		wm.ylimit = wm.height;
		wm.effective_width = wm.width - wm.xoffset;
		wm.effective_height = wm.height;
		wm.statusbar:set_vertical();
		wm.statusbar:resize(hide_base, wm.height - 2 * cap_h - pad_v);
		move_image(wm.anchor, wm.xoffset, 0);
		bar_hide_dx = -(hide_base - bar_ofs)
		bar_hide_dy = 0

	elseif (pos == "right") then
		local cap_h = math.floor((wm.height - (wm.height * 0.01 * size)) * 0.5)
		wm.yoffset = 0;
		wm.xoffset = 0;
		wm.xlimit = wm.width - bar_base - pad_h;
		wm.effective_width = wm.xlimit;
		wm.effective_height = wm.height;
		wm.statusbar:set_vertical();
		wm.statusbar:move(wm.xlimit + pad_l - bar_ofs, pad_t + cap_h);
		move_image(wm.anchor, 0, 0);
		wm.statusbar:resize(hide_base, wm.height - 2 * cap_h - pad_v);
		bar_hide_dx = hide_base - bar_ofs
		bar_hide_dy = 0

	else -- "down"
		wm.yoffset = 0;
		wm.xoffset = 0;
		wm.effective_width = wm.width;
		wm.effective_height = wm.height - bar_base - pad_v;
		wm.ylimit = wm.effective_height;
		wm.xlimit = wm.width;
		wm.statusbar:set_horizontal();
		move_image(wm.anchor, 0, 0);
		local pad_w = math.floor((wm.width - (wm.width * 0.01 * size)) * 0.5)
		wm.statusbar:resize(wm.width - 2 * pad_w, hide_base);
		wm.statusbar:move(xpos + pad_w, wm.effective_height + pad_t - bar_ofs);
		bar_hide_dx = 0
		bar_hide_dy = (hide_base - bar_ofs)
	end

	wm.statusbar:autohide(autohide, bar_hide_dx, bar_hide_dy)

-- same tactic to hiding the ws buttons, this should probably be refactored
-- entirely to use the display-button tactic of iterating and removing the
-- ones that doesn't matter
	local hide_ws = not gconfig_get("sbar_wsbuttons");
	local prefcolor = gconfig_get("sbar_prefixcolor");
	local dyncolor = gconfig_get("sbar_prefixcolor") == "dynamic";
	local use_prefix = gconfig_get("sbar_numberprefix");
	local r, g, b = suppl_hexstr_to_rgb(prefcolor);

	local ws_count = 0;

	for i=1,10 do
-- change base color based on index?
		local hccolor = HC_PALETTE[((i-1) % #HC_PALETTE) + 1];
		if dyncolor then
			prefcolor = hccolor;
			r, g, b = suppl_hexstr_to_rgb(hccolor);
		end

-- buttons are always 'there' but can be hidden or not
		if (wm.spaces[i] ~= nil and not hide_ws) then
			wm.sbar_ws[i]:show();
			ws_count = 1;
			local lbltbl = use_prefix and {prefcolor, tostring(i)} or {};

-- shader defines what of the 'background' actually gets this color,
-- and this is used for underline or border
			image_color(wm.sbar_ws[i].bg, r, g, b);
			local label = wm.spaces[i].label;
			local fontstr, _ = wm:font_resfn()

-- is there a custom workspace tag to use?
			if (label and #label > 0) then
				if use_prefix then
					table.insert(lbltbl, "");
					table.insert(lbltbl, ":");
				end

-- differentiate the coloring between user and generated content
				local prefix = gconfig_get("sbar_lblcolor");
				table.insert(lbltbl, (prefix == "dynamic" and hccolor or prefix));
				table.insert(lbltbl, label);
			end

			wm.sbar_ws[i]:update(lbltbl, 0, true);

-- offset background to take size and position into account
			if (wm.spaces[i].background) then
				wm.spaces[i].background_y = -wm.yoffset;
				move_image(wm.spaces[i].background, -wm.xoffset, -wm.yoffset);
			end
		else
			wm.sbar_ws[i]:hide();
		end
		wm.sbar_ws[i]:switch_state(i == wm.space_ind and "active" or "inactive");
	end

-- the reserved slot for workspace create button
	if (ws_count < 10 and gconfig_get("sbar_wsmeta")) then
		wm.sbar_ws[11]:show();
	else
		wm.sbar_ws[11]:hide();
	end

-- now we have the dynamic list of 'display buttons',
-- time to see which ones should stay and which should go
		local pad = gconfig_get("sbar_tpad") * wm.scalef;
	if gconfig_get("sbar_dispbuttons") then
		local list = {}
		for _, disp in ipairs(all_displays_list()) do
			if disp.tiler ~= wm then
				table.insert(list, {disp.name, disp.id})
			end
		end

		list = prune_missing_known(wm, list)

		local dir = gconfig_get("sbar_dispbutton_dir");
		for i,v in ipairs(list) do
			local dn_hex = string.hexenc(v[1]);
			local dn_path = "/global/display/displays/disp_" .. dn_hex .. "/";

-- the icon-management needs to be a little bit better here so that we can
-- take a base icon and overlay a number or text on it
			local outlbl = resolve_vsymbol(wm,
				gconfig_get("sbar_dispbutton_prefix") .. v[2], sbsz);

			local btn = wm.statusbar:add_button(
				dir, "sbar_item_bg",
				"sbar_item", outlbl, pad, wm.font_resfn, sbsz, nil,
				mouse_handler_factory.statusbar_icon(wm, dn_path .. "focus", "")
			);
			btn.drag_command = "/target/window/migrate/migrate_" .. dn_hex;
			btn.display = v;
			btn:switch_state("inactive");
		end
	else
		prune_missing_known(wm, {})
	end

-- look for a tagged lockbutton
	local lockbtn;
	for btn in wm.statusbar:all_buttons() do
		if btn.lockstate then
			lockbtn = btn;
			break;
		end
	end

--update its state
	local want_lock = false;
	local lock_cfg = gconfig_get("sbar_lockbutton_visible");
	local want_lock =
		(lock_cfg ~= "never") and
		(lock_cfg == "always" or (dispatch_locked()));

-- create if it is desired, note that the default mouse handler for statusbar
-- will clear the alert on mouse over, interpreting it as if the user had ack:ed
-- and that is a behaviour to reconsider (patch over/out)
	if want_lock and not lockbtn then
		lockbtn = wm.statusbar:add_button(
			gconfig_get("sbar_lockbutton_dir"),
			"sbar_item_bg", "sbar_item",
			resolve_vsymbol(wm, gconfig_get("sbar_lockbutton_symbol"), sbsz),
			pad, wm.font_resfn, sbsz, nil,
			{
				click =
				function(btn)
					dispatch_toggle()
				end
			}
		)
		lockbtn:set_alt("input lock")
		lockbtn.lockstate = true;
	end

-- and update its state
	if lockbtn then
		if not want_lock then
			lockbtn:destroy();
		else
			lockbtn:switch_state(dispatch_locked() and "alert" or "inactive")
		end
	end

	update_sbar_shadow(wm);
end

local function tiler_statusbar_build(wm)
	local sbsz = sbar_geth(wm, true);
	if (wm.statusbar) then
		wm.statusbar:destroy();
	end

	wm.statusbar = uiprim_bar(wm.order_anchor,
		ANCHOR_UL, wm.width, sbsz, "statusbar", nil, "sbar");
	local pad = gconfig_get("sbar_tpad") * wm.scalef;
	wm.statusbar.owner = wm;
	wm.sbar_ws = {};

-- add the left / right buttons from the gconfig, an open question
-- here is how to approach the 'status indicator' for buttons that
-- act as minimization targets
	if (wm.sbar_custom) then
		wm.sbar_ws["custom"] = {};
		for i,v in ipairs(wm.sbar_custom) do
			local outlbl = resolve_vsymbol(wm, v.label, sbsz);
			local btn = wm.statusbar:add_button(
				v.direction, "sbar_item_bg",
				"sbar_item", outlbl, pad, wm.font_resfn, sbsz, nil,
				mouse_handler_factory.statusbar_icon(wm, v.command, v.alt_command)
			);
			btn:set_alt(v.label)
			btn:switch_state("inactive");
			btn.drag_command = v.drag_command;

-- unfortunately mouse "drop" doesn't trigger on the surface where
-- something is being dropped but rather from the context where the
-- drag was initiated
			btn.on_drop = v.on_drop;
			table.insert(wm.sbar_ws["custom"], btn);
		end
	end

-- pre-allocate buffer slots, but keep hidden
	for i=1,10 do
		wm.sbar_ws[i] = wm.statusbar:add_button("left", "sbar_item_bg",
			"sbar_item", tostring(i), pad, wm.font_resfn, sbsz, nil,
				mouse_handler_factory.statusbar_wsicon(wm, i)
		);
		wm.sbar_ws[i]:set_alt("workspace " .. tostring(i))
		wm.sbar_ws[i].drag_command =
			"/target/window/reassign/reassign_" .. tostring(i);
		wm.sbar_ws[i]:hide();
	end

	wm.sbar_ws[11] = wm.statusbar:add_button("left", "sbar_item_bg",
		"sbar_item", "+", pad, wm.font_resfn, sbsz, nil,
		mouse_handler_factory.statusbar_addicon(wm)
	);
	wm.sbar_ws[11]:set_alt("new workspace")

	wm.sbar_ws[11].drag_command = "/target/window/reassign/reassign_new";
	wm.sbar_ws[11]:switch_state("inactive");

	wm.sbar_ws["msg"] = wm.statusbar:add_button("center",
		"sbar_msg_bg", "sbar_msg_text", " ", pad, wm.font_resfn, nil, sbsz,
		{
			click = function(btn)
				btn:update("");
			end
		});
	wm.sbar_ws["msg"]:switch_state("inactive");
	wm.sbar_ws["msg"].drag_command = "/target/window/minimize";
	wm.sbar_ws["msg"].align_left = true;
end

local function tiler_statusbar_custom(wm, bar)
	wm.sbar_custom = bar;
	if (wm.statusbar) then
		tiler_statusbar_build(wm);
		tiler_statusbar_update(wm);
	end
end

local function wm_order(wm)
	return wm.order_anchor;
end

-- recursively resolve the relation hierarchy and return a list
-- of vids that are linked to a specific vid, this is similar to linearize()
-- but uses the image hierarchy rather than the logical one, so that popups,
-- etc. also come with.
local function get_hier(vid)
	local ht = {};

	local level =
	function(hf, vid)
		for i,v in ipairs(image_children(vid)) do
			table.insert(ht, v);
			hf(hf, v);
		end
	end

	level(level, vid);
	return ht;
end

local function wnd_mouseactivate(wnd)
-- reset hidden state without running a reveal animation
	local hidden = mouse_state().hidden;
	local wm = wnd.wm;

	mouse_hidemask(true);
	mouse_show();
	mouse_switch_cursor();
	mouse_hidemask(false);

-- switch to the desired mouse cursor
	if (wnd.custom_cursor and wnd.custom_cursor.active) then
		tiler_debug(wnd.wm,
			string.format("mouse_activate:wnd=%s:custom_cursor", wnd.name));

		if (valid_vid(wnd.custom_cursor.vid)) then
			mouse_custom_cursor(wnd.custom_cursor);
		else
			wnd.custom_cursor = nil;
		end

	elseif (type(wnd.cursor) == "string") then
		tiler_debug(wnd.wm,
			string.format("mouse_active:wnd=%s:cursor=%s", wnd.name, wnd.cursor));

		if (wnd.cursor ~= "hidden") then
			mouse_switch_cursor(wnd.cursor);
		end
	end

	if (hidden or wnd.cursor == "hidden") then
		mouse_hidemask(true);
		mouse_hide();
		mouse_hidemask(false);
	end
end

local function wnd_select(wnd, source, mouse)
	local wm = wnd.wm;

-- special cases, wm deactivated from being plugged out, or window
-- not attached or explicitly prohibited from being selected
	if (wm.deactivated or not wnd.space) then
		return;
	end

-- a window can forward selection to another, this does not protect
-- against circular dependencies and those would live lock
	if (wnd.select_redirect) then
		if wnd.select_redirect.select then
			return wnd.select_redirect:select(source, mouse);
		else
			wnd.select_redirect = nil;
		end
	end

-- may be used to reactivate locking after a lbar or similar action
-- has been performed.
	local same_select = false
	if (wm.selected == wnd) then
		wnd_titlebar_to_statusbar(wnd);
		if (wnd.mouse_lock) then
			mouse_lockto(wnd.canvas, type(wnd.mouse_lock) == "function" and
				wnd.mouse_lock or nil, wnd.mouse_lock_center);
		end
		same_select = true
	end

-- format focus state (unless that's blocked, set_dispmask handles that)
	wnd:set_dispmask(bit.band(wnd.dispmask,
		bit.bnot(wnd.dispmask, TD_HINT_UNFOCUSED)));

-- deselect the current one
	if (wm.selected and wm.selected.deselect and not same_select) then
		wm.selected:deselect();
	end

-- for tabbed modes, the titlebar and the 'tabs' are decoupled and
-- we hide/show the entire window based on active tab
	if (is_tab_mode(wnd.space.mode)) then
		show_image(wnd.canvas)
		show_image(wnd.anchor)
	end

-- update the shader state for the UI bar to reflect selection
	local state = wnd.suspended and "suspended" or "active";
	shader_setup(wnd.border, "ui",
		wnd.space.mode == "float" and "border_float" or "border", state);
	wnd.titlebar:switch_state(state, true);

	if (wnd.shadow) then
		local focus = gconfig_get("shadow_focus");
		if is_tab_mode(wnd.space.mode) or wnd.space.mode == "fullscreen" then
			focus = 0;
		end
		blend_image(wnd.shadow, focus);
	end

-- there's a local selection state per workspace, but also a
-- one for the wm itself (active_display().selected)
	wnd.space.previous = wnd.space.selected;
	if (wm:active_space() == wnd.space) then
		wm.selected = wnd;
		wnd_titlebar_to_statusbar(wnd);
	end

	wnd.space.selected = wnd;

-- activate all "on-trigger" mouse events, like warping and locking
	ms = mouse_state();
	ms.hover_ign = true;

-- warp to last known position, but disable if we just attached as there
-- won't be a reference coordinate saved yet and the warp coordinates will
-- resolve wrongly if the canvas is animated
	if (CLOCK ~= wnd.attach_time and
		not same_select and
		gconfig_get("mouse_remember_position") and not ms.in_handler) then
		local props = image_surface_resolve(wnd.canvas);
		local rx = wnd.x + wnd.mouse[1] * props.width;
		local ry = wnd.y + wnd.mouse[2] * props.height;
		tiler_debug(wm, string.format("select_warp:x=%f:y=%f", rx, ry));

		mouse_absinput_masked(rx, ry, true);
		wnd_mouseactivate(wnd);
		ms.hide_count = ms.hide_base;
-- won't generate normal over event
		if (wnd.cursor == "hidden") then
			mouse_hidemask(true);
			mouse_hide();
			mouse_hidemask(false);
		end
	end
	ms.last_hover = CLOCK;
	ms.hover_ign = false;

-- lock-state per window so that things like warping etc. works
	if (wnd.mouse_lock) then
		mouse_lockto(wnd.canvas, type(wnd.mouse_lock) == "function" and
				wnd.mouse_lock or nil, wnd.mouse_lock_center, wnd);
	end

	wnd:to_front();
	tiler_debug(wm, "select:name=" .. wnd.name);
	run_event(wnd, "select", mouse);

	for i,v in ipairs(wm.on_wnd_select) do
		v(wm, wnd, wnd.space, wnd.space == wm:active_space());
	end
end

--
-- This is _the_ operation when it comes to window management here, it resizes
-- the actual size of a tile (which may not necessarily match the size of the
-- underlying surface). Keep everything divisible by two for simplicity.
--
-- The overall structure in split mode is simply a tree, split resources fairly
-- divided between individuals (with an assignable weight) and recurse down to
-- children
--
local function visible_children(node, dst)
	for _, v in ipairs(node.children) do
		if not v.hidden then
			table.insert(dst, v);
		end
	end

-- if the entire set is invisible, remove the level and pick from grandchildren
	if #dst == 0 then
		for _, v in ipairs(node.children) do
			visible_children(v, dst);
		end
	end
end

local function level_resize(level, x, y, w, h, repos, fairh)

-- at the moment, hiding all nodes would block the children -
-- should we then merge upwards instead?
	local children = {};
	visible_children(level, children);
	if #children == 0 then
		return;
	end

	local fairw = math.ceil(w / #children);
	fairw = (fairw % 2) == 0 and fairw or fairw + 1;

	local tpad_w = gconfig_get("tile_gap_w");
	local tpad_h = gconfig_get("tile_gap_h");

	local process_node =
	function(node, last, fairh)
		node.x = x; node.y = y;
		node.max_h = h;

		if (last) then
			node.max_w = w;
		else
			node.max_w = node.max_w - tpad_w;
			node.max_w = math.floor(fairw * node.weight);
			node.max_w = (node.max_w % 2) == 0 and node.max_w or node.max_w + 1;
		end

-- recurse downwards
		node.max_h = math.floor(fairh * node.vweight);

		local children = {};
		visible_children(node, children);
		if #children == 0 then
			node.max_h = h;
		else
			level_resize(node, x,
				y + tpad_h + node.max_h,
				node.max_w, h - tpad_h - node.max_h,
				repos, fairh
			);
		end

		node:resize(node.max_w, node.max_h, true);

		x = x + node.max_w + tpad_w;
		w = w - node.max_w - tpad_w;
	end

-- recursively find the depth to know the fair division, (N) is not high
-- enough for this value to be worth tracking rather than just calculating
	local get_depth;
	get_depth = function(node, depth)
		local dchild = {};
		visible_children(node, dchild);
		if (#dchild == 0) then
			return depth;
		end

		local maxd = depth;
		for i=1,#dchild do
			local d = get_depth(dchild[i], depth + 1);
				maxd = d > maxd and d or maxd;
		end

		return maxd;
	end

	for i=1,#children-1 do
		process_node(children[i], false,
			fairh and fairh or math.floor(h / get_depth(children[i], 1)));
	end

-- allow the last node to "fill" to handle broken weights
	local last = children[#children];
	process_node(last, true, fairh and fairh or math.floor(h/get_depth(last, 1)));
end

local function workspace_activate(space, noanim, negdir, oldbg)
	local time = gconfig_get("transition");
	local method = gconfig_get("ws_transition_in");

-- wake any sleeping windows up and make sure it knows if it is selected or not
	for k,v in ipairs(space.wm.windows) do
		if (v.space == space) then
			v:set_dispmask(bit.band(v.dispmask, bit.bnot(TD_HINT_INVISIBLE)), true);
			if (space.selected ~= v) then
				v:set_dispmask(bit.bor(v.dispmask, TD_HINT_UNFOCUSED));
			else
				v:set_dispmask(bit.band(v.dispmask, bit.bnot(TD_HINT_UNFOCUSED)));
			end
		end
	end

-- flush out pending transforms
	instant_image_transform(space.anchor);
	if (valid_vid(space.background)) then
		instant_image_transform(space.background);
	end

	if (not noanim and time > 0 and method ~= "none") then
		if (method == "move-h") then
			move_image(space.anchor, (negdir and -1 or 1) * space.wm.width, 0);
			move_image(space.anchor, 0, 0, time);
			show_image(space.anchor);

		elseif (method == "move-v") then
			move_image(space.anchor, 0, (negdir and -1 or 1) * space.wm.height);
			move_image(space.anchor, 0, 0, time);
			show_image(space.anchor);

		elseif (method == "fade") then
			move_image(space.anchor, 0, 0);
			blend_image(space.anchor, 0.0);
-- stay at level zero for a little while so not to fight and crossfade
			blend_image(space.anchor, 0.0, time * 0.5);
			blend_image(space.anchor, 1.0, time * 0.5);
		else
			warning("broken method set for ws_transition_in: " ..method);
		end

-- slightly more complicated, we don't want transitions if the background is the
-- same between different workspaces as it is visually more distracting
		local bg = space.background;
		if (bg) then
			if (not valid_vid(oldbg) or not image_matchstorage(oldbg, bg)) then
				blend_image(bg, 0.0);
				blend_image(bg, 1.0, time * 0.5);
				image_mask_set(bg, MASK_POSITION);
				image_mask_set(bg, MASK_OPACITY);
			else
				show_image(bg);
				image_mask_clear(bg, MASK_POSITION);
				image_mask_clear(bg, MASK_OPACITY);
			end
		end
	else
		show_image(space.anchor);
		if (space.background) then
			show_image(space.background);
		end
	end

-- show all windows that are not marked as hidden, this skips the
-- wnd_hide/ wnd_show implementation
	local lst = linearize(space);
	for _,v in ipairs(lst) do
		if not v.hidden then
			show_image(v.anchor)
		end
	end

	local tgt = space.selected and space.selected or space.children[1];

-- reanchor to make sure hidden in ws 'works'
	if tgt then
		local bw = tgt:border_width();
		tgt.titlebar:reanchor(tgt.anchor, 4, bw, bw)
		wnd_titlebar_to_statusbar(tgt)
	end
end

local function workspace_deactivate(space, noanim, negdir, newbg)
	local time = gconfig_get("transition");
	local method = gconfig_get("ws_transition_out");

-- hack so that deselect event is sent but not all other state changes trigger
	if (space.selected and not noanim) then
		local sel = space.selected;
		wnd_deselect(space.selected);
		space.selected = sel;
		wnd_titlebar_to_statusbar(sel);
	end

-- notify windows that they can take things slow
	for k,v in ipairs(space.wm.windows) do
		if (v.space == space) then
			if (valid_vid(v.external, TYPE_FRAMESERVER)) then
				v:set_dispmask(bit.bor(v.dispmask, TD_HINT_INVISIBLE));
			end
		end
	end

	instant_image_transform(space.anchor);
	if (valid_vid(space.background)) then
		instant_image_transform(space.background);
	end

	if (not noanim and time > 0 and method ~= "none") then
		if (method == "move-h") then
			move_image(space.anchor, (negdir and -1 or 1) * space.wm.width, 0, time);
			blend_image(space.anchor, 1.0, time);
			blend_image(space.anchor, 0.0, 1);

		elseif (method == "move-v") then
			move_image(space.anchor, 0, (negdir and -1 or 1) * space.wm.height, time);
			blend_image(space.anchor, 1.0, time);
			blend_image(space.anchor, 0.0, 1);

		elseif (method == "fade") then
			blend_image(space.anchor, 0.0, 0.5 * time);
		else
			warning("broken method set for ws_transition_out: "..method);
		end
		local bg = space.background;
		if (bg) then
			if (not valid_vid(newbg) or not image_matchstorage(newbg, bg)) then
				blend_image(bg, 0.0, 0.5 * time);
				image_mask_set(bg, MASK_POSITION);
				image_mask_set(bg, MASK_OPACITY);
			else
				hide_image(bg);
				image_mask_clear(bg, MASK_POSITION);
				image_mask_clear(bg, MASK_OPACITY);
			end
		end
	else
		hide_image(space.anchor);
		if (valid_vid(space.background)) then
			hide_image(space.background);
		end
	end
end

-- migrate window means:
-- copy valuable properties, destroy then "add", including tiler.windows
--
local function workspace_migrate(ws, newt, disptbl)
	local oldt = ws.wm;
	if (oldt == newt) then
		return;
	end

-- find a free slot and locate the source slot
	local dsti;
	for i=1,10 do
		if (newt.spaces[i] == nil or (
			#newt.spaces[i].children == 0 and newt.spaces[i].label == nil)) then
			dsti = i;
			break;
		end
	end

	local srci;
	for i=1,10 do
		if (oldt.spaces[i] == ws) then
			srci = i;
			break;
		end
	end

	if (not dsti or not srci) then
		tiler_logfun(tiler_fmt("migrate_fail:missing:dst=%s:src=%s",
			dsti and "yes" or "no", srci and "yes" or "no"));
		return;
	end

-- add/remove from corresponding tilers, update status bars
	workspace_deactivate(ws, true);
	ws.wm = newt;
	rendertarget_attach(newt.rtgt_id, ws.anchor, RENDERTARGET_DETACH);
	link_image(ws.anchor, newt.anchor);

	local wnd = linearize(ws);
	for i,v in ipairs(wnd) do
		tiler_logfun(tiler_fmt("ws_migrate:wnd=%s:dst=%s", v.name, newt.name));
		v.wm = newt;
		table.insert(newt.windows, v);
		table.remove_match(oldt.windows, v);
-- send new display properties
		if (disptbl) then
			v:displayhint(0, 0, v.dispmask, get_disptbl(v, disptbl));
		end

-- special handling for titlebar
		for j in v.titlebar:all_buttons() do
			j.fontfn = newt.font_resfn;
		end
		v.titlebar:invalidate();
		v:set_title();
	end
	oldt.spaces[srci] = create_workspace(oldt, false);

-- switch rendertargets
	local list = get_hier(ws.anchor);
	for i,v in ipairs(list) do
		rendertarget_attach(newt.rtgt_id, v, RENDERTARGET_DETACH);
	end

	if (dsti == newt.space_ind) then
		workspace_activate(ws, true);
		newt.selected = oldt.selected;
	end

	oldt.selected = nil;

-- recalculate HUD order slot (based on # windows)
	order_image(oldt.order_anchor,
		2 + #oldt.windows * WND_RESERVED + 2 * WND_RESERVED);
	order_image(newt.order_anchor,
		2 + #newt.windows * WND_RESERVED + 2 * WND_RESERVED);

	newt.spaces[dsti] = ws;

	local olddisp = active_display();
	set_context_attachment(newt.rtgt_id);

-- enforce layout and dimension changes as needed
	ws:resize();
	if (valid_vid(ws.label_id)) then
		delete_image(ws.label_id);
		mouse_droplistener(ws.tile_ml);
		ws.label_id = nil;
	end

	set_context_attachment(olddisp.rtgt_id);
end

-- undo / redo the effect that deselect will hide the active window
local function switch_tab(space, to, ndir, newbg, oldbg)
	local wnds = linearize(space);
	if (to) then
		for k,v in ipairs(wnds) do
			hide_image(v.anchor);
		end
		workspace_activate(space, false, ndir, oldbg);
	else
		workspace_deactivate(space, false, ndir, newbg);
		if (space.selected) then
			show_image(space.selected.anchor);
		end
	end
end

local function switch_fullscreen(space, to, ndir, newbg, oldbg)
	if (space.selected == nil) then
		return;
	end

	if (to) then
		sbar_hide(space.wm);
		workspace_activate(space, false, ndir, oldbg);
		for _, v in ipairs(linearize(space)) do
			if v ~= space.selected then
				hide_image(v.anchor)
			end
		end
	else
		sbar_show(space.wm);
		workspace_deactivate(space, false, ndir, newbg);
	end
end

local function drop_fullscreen(space)
	if (space.hook_block) then
		return;
	end

-- safe-guard against bad code elsewhere
	if (not space.selected or not space.selected.fs_copy) then
		return;
	end

-- show all non-hidden windows within the space
	local wnds = linearize(space);
	for k,v in ipairs(wnds) do
		show_image(v.anchor);
	end

-- restore 'full-screen only' properties
	space.hook_block = "drop_fullscreen";
	local dw = space.selected;

	for k,v in pairs(dw.fs_copy) do
		dw[k] = v;
	end

-- reset decorations to match last mode
	dw.titlebar:show("fullscreen");
	dw:set_titlebar(dw.fs_copy.show_titlebar);
	dw:set_border(dw.fs_copy.show_border);

-- move the anchor to the last know position subtract decorations
-- so the window will animate better when returning
	local props = image_surface_resolve(dw.canvas)
	move_image(dw.anchor, props.x, props.y)

-- resize decor will re-insert shadow
-- dw:resize(dw.fs_copy.width, dw.fs_copy.height);

	dw.fs_copy = nil;
	dw.fullscreen = nil;
	space.switch_hook = nil;
	space.hook_block = nil;

	sbar_show(space.wm);


	workspace_activate(space, true);

-- re-send the original displayhint as fullscreen has different hint
-- behaviours than other modes when there is a relayout pending
	dw:displayhint(dw.width, dw.height, dw.dispmask);

-- interesting: doing this makes the window not appear, a reason may
-- be that we are formally not in the mode layout of the new mode yet,
-- one option is to throw a mode-hook that will trigger selection and
-- size hints
	return function()
		if space.selected == dw then
			dw:select()
			dw:resize(dw.width, dw.height, true, true)
			wnd_titlebar_to_statusbar(dw)
		else
			dw:deselect()
		end
	end
end

local function drop_tab(space)
	local res = linearize(space);

-- relink the titlebars so that they anchor their respective windows rather
-- than the client window itself.
	for k,v in ipairs(res) do
		local bw = v:border_width();
		v.titlebar:reanchor(v.anchor, 2, bw, bw);
		if (v.show_border) then
			show_image(v.border);
		end
		show_image(v.canvas);
		show_image(v.anchor);
	end

	space.mode_hook = nil;
	space.switch_hook = nil;
	space.reassign_hook = nil;
end

local function drop_float(space)
	space.in_float = false;

-- save positional information relative to the current WM dimensions so that
-- if the resolution would change between invocations, we can still position
-- and size proportionally
	local lst = linearize(space);
	for i,v in ipairs(lst) do
		local pos = image_surface_properties(v.anchor);
		shader_setup(v.border, "ui", "border", v.titlebar.state);
		v.last_float = {
			width = v.width / space.wm.effective_width,
			height = v.height / space.wm.effective_height,
			x = pos.x / space.wm.effective_width,
			y = pos.y / space.wm.effective_height
		};
	end
end

local function reassign_vtab(space, wnd)
	local bw = wnd:border_width();
	wnd.titlebar:reanchor(wnd.anchor, 2, 0, 0);
	show_image(wnd.anchor);
	show_image(wnd.border, wnd.show_border and 1 or 0);
end

local function reassign_tab(space, wnd)
	local bw = wnd:border_width();
	wnd.titlebar:reanchor(wnd.anchor, 2, wnd.border_w);
	show_image(wnd.anchor);
	show_image(wnd.border, wnd.show_border and 1 or 0);
end

local function set_htab(space, repos)
	local lst = linearize(space);
	if (#lst == 0) then
		return;
	end

	space.mode_hook = drop_tab;
	space.switch_hook = switch_tab;
	space.reassign_hook = reassign_tab;

	local wm = space.wm;
	local tbarw = math.ceil(
		wm.effective_width * gconfig_get("htab_barw") * wm.scalef);
	local tbar_sz = math.ceil(gconfig_get("tbar_sz") * wm.scalef);
	local bw = gconfig_get("borderw");
	local lpad = math.ceil(gconfig_get("htab_lpad") * wm.scalef);
	local rpad = math.ceil(gconfig_get("htab_rpad") * wm.scalef);
	local ofs = math.ceil(gconfig_get("htab_tpad") * wm.scalef);

	for i,v in ipairs(lst) do
		v.max_w = wm.effective_width - tbarw;
		v.max_h = wm.effective_height;
		if (not repos) then
			v:resize(v.max_w, v.max_h);
		end
		v.ofs_x = lpad + rpad + tbarw;
		v.ofs_y = 0;

-- titlebar gets separated from canvas
		move_image(v.anchor, 0, 0);
		move_image(v.canvas, v.ofs_x, v.ofs_y);
		hide_image(v.anchor);
		hide_image(v.border);

-- forces titlebar, sizes to the number of windows
		v.titlebar:switch_group("htab", true, true);
		v.titlebar:reanchor(space.anchor, 2, lpad, ofs);
		v.titlebar:resize(tbarw, tbar_sz);
		ofs = ofs + tbar_sz;
	end

	if (space.selected) then
		local wnd = space.selected;
		wnd:deselect();
		wnd:select();
	end
end

-- just unlink statusbar, resize all at the same time (also hides some
-- of the latency in clients producing new output buffers with the correct
-- dimensions etc). then line the statusbars at the top.
local function set_tab(space, repos)
	local lst = linearize(space);
	if (#lst == 0) then
		return;
	end

	if (space.layouter and space.layouter.resize(space, lst)) then
		return;
	end

	space.mode_hook = drop_tab;
	space.switch_hook = switch_tab;
	space.reassign_hook = reassign_tab;

	local wm = space.wm;
	local fairw = math.ceil(wm.effective_width / #lst);
	local tbar_sz = math.ceil(gconfig_get("tbar_sz") * wm.scalef);
	local bw = gconfig_get("borderw");
	local ofs = 0;

	for k,v in ipairs(lst) do
		v.max_w = wm.effective_width;
		v.max_h = wm.effective_height - tbar_sz;
		if (not repos) then
			v:resize(v.max_w, v.max_h);
		end
		move_image(v.anchor, 0, 0);
		move_image(v.canvas, 0, tbar_sz);
		hide_image(v.anchor);
		hide_image(v.border);
		v.titlebar:switch_group("tab", true, true);
		v.titlebar:reanchor(space.anchor, 2, ofs, 0);
		v.titlebar:resize(fairw, tbar_sz);
		ofs = ofs + fairw;
	end

	if (space.selected) then
		local wnd = space.selected;
		wnd:deselect();
		wnd:select();
	end
end

-- tab and vtab are similar in most aspects except for the axis used
-- and the re-ordering of the selected statusbar
local function set_vtab(space, repos)
	local lst = linearize(space);
	if (#lst == 0) then
		return;
	end

	if (space.layouter and space.layouter.resize(space, lst)) then
		return;
	end

	space.mode_hook = drop_tab;
	space.switch_hook = switch_tab;
	space.reassign_hook = reassign_vtab;

	local wm = space.wm;
	local tbar_sz = math.ceil(gconfig_get("tbar_sz") * wm.scalef);
	local sb_sz = sbar_geth(wm);

	local ypos = #lst * tbar_sz;
	local cl_area = wm.height - sb_sz - ypos;
	if (cl_area < 1) then
		return;
	end

	local ofs = 0;
	for k,v in ipairs(lst) do
		v.max_w = wm.effective_width;
		v.max_h = cl_area;
		if (not repos) then
			v:resize(v.max_w, v.max_h);
		end
		move_image(v.anchor, 0, ypos);
		move_image(v.canvas, 0, 0);
		hide_image(v.anchor);
		hide_image(v.border);
		v.titlebar:switch_group("vtab", true, true);
		v.titlebar:reanchor(space.anchor, 2, 0, (k-1) * tbar_sz);
		v.titlebar:resize(wm.effective_width, tbar_sz);
		ofs = ofs + tbar_sz;
	end

	if (space.selected) then
		local wnd = space.selected;
		wnd:deselect();
		wnd:select();
	end
end

local function set_fullscreen(space)
	local dw = space.selected;

	if not dw then
		return;
	end

	local in_space = dw.wm:active_space() == space;

	if space.hook_block then
		if in_space then
			show_image(dw.anchor);
		end
		return;
	end

-- keep a copy of properties we may want to change during fullscreen
	if (not dw.fs_copy) then
		dw.fs_copy = {
			centered = dw.centered,
			fullscreen = false,
			show_border = dw.show_border,
			show_titlebar = dw.show_titlebar,
			want_shadow = dw.want_shadow,
			width = dw.width,
			height = dw.height,
			x = dw.x,
			y = dw.y,
		};
	end

	dw.titlebar:hide("fullscreen");

-- not all clients provide a canvas surface that match
	dw.centered = true;
	dw.fullscreen = space.last_mode;

-- prevent any hooks on wnd_resize that might also trigger space actions
	space.hook_block = "set_fullscreen";

-- hide all images + statusbar > if we are active <, someone could force
-- the fullscreen setting on a space in the background
	if in_space then
		sbar_hide(dw.wm);
		show_image(dw.anchor);
	end

	if valid_vid(dw.shadow) then
		hide_image(dw.shadow);
		delete_image(dw.shadow);
	end

-- fake-hide all windows (retains !hidden attribute)
	local wnds = linearize(space);
	for k,v in ipairs(wnds) do
		hide_image(v.anchor);
	end

	dw:set_border(false);
	dw:set_titlebar(false);
	dw:set_dispmask(TD_HINT_FULLSCREEN);

-- need to hook switching between workspaces to enable things like the sbar
	space.mode_hook = drop_fullscreen;
	space.switch_hook = switch_fullscreen;

-- drop border, titlebar, ...
	move_image(dw.canvas, 0, 0);
	move_image(dw.anchor, 0, 0);
	dw.max_w = dw.wm.width;
	dw.max_h = dw.wm.height;
	dw.x = 0;
	dw.y = 0;

	dw.wm.statusbar:set_nested();

-- and send relayout / fullscreen hints that match the size of the WM
	dw:resize(dw.wm.width, dw.wm.height);
	space.hook_block = nil;
end

-- floating mode has different rulesets for spawning, sizing and all windows
-- are "unlocked" for custom drag-resize
local function set_float(space)
	local tbl = linearize(space);

-- rescue any windows that are outside of view
	for _,v in ipairs(tbl) do
		if v.x > v.wm.width then
			v:move(v.wm.width - v.x, 0, false, false, true)
		end

		if v.y > v.wm.height then
			v:move(v.wm.height - v.y, 0, false, false, true)
		end
	end

	if (space.in_float) then
		return;
	end

	space.reassign_hook = reassign_float;
	space.mode_hook = drop_float;
	space.in_float = true;

	if (space.layouter and space.layouter.resize(space, tbl)) then
		return;
	end

	for i,v in ipairs(tbl) do
		local props = image_storage_properties(v.canvas);
		local neww;
		local newh;
-- work with relative position / size to handle migrate or resize
		if (v.last_float) then
			neww = space.wm.effective_width * v.last_float.width;
			newh = space.wm.effective_height * v.last_float.height;
			v.x = space.wm.effective_width * v.last_float.x;
			v.y = space.wm.effective_height * v.last_float.y;

			local lm, lr, interp = wnd_animation_time(v, v.anchor, false, true);
			move_image(v.anchor, v.x, v.y, lm, interp);
-- if window havn't been here before, clamp
		else
			neww = props.width;
			newh = props.height;
			neww = (space.wm.effective_width < neww
				and space.wm.effective_width) or neww;
			newh = (space.wm.effective_height < newh
			and space.wm.effective_height) or newh;
		end

-- doesn't really matter here as we run with "force" flag
		v.max_w = neww;
		v.min_h = newh;

		v.titlebar:switch_group("float", true, false);
		v:resize(neww, newh, false);
	end
end

local function set_tile(space, repos)
	local wm = space.wm;
	if (gconfig_get("sbar_visible") == "desktop") then
		sbar_show(wm);
	else
		sbar_hide(wm);
	end

	local tbl = linearize(space);
	for _,v in ipairs(tbl) do
		if (v.titlebar) then
			v.titlebar:switch_group("tile", true, false);
		end
	end

	if (space.layouter) then
		local tbl = linearize(space);
		if (space.layouter.resize(space, tbl)) then
			return;
		end
	end

	level_resize(space, 0, 0, wm.effective_width, wm.effective_height, repos);
end

local space_handlers = {
	tile = set_tile,
	float = set_float,
	fullscreen = set_fullscreen,
	tab = set_tab,
	vtab = set_vtab,
	htab = set_htab,
};

local function workspace_destroy(space)
	if (space.mode_hook) then
		space:mode_hook();
		space.mode_hook = nil;
	end

	for k,v in pairs(space.listeners) do
		v(space, k, "destroy");
	end

	while (#space.children > 0) do
		space.children[1]:destroy();
	end

	if (valid_vid(space.rtgt_id)) then
		delete_image(space.rtgt_id);
	end

	if (space.label_id ~= nil) then
		delete_image(space.label_id);
	end

	if (space.background) then
		delete_image(space.background);
	end

	delete_image(space.anchor);
	for k,v in pairs(space) do
		space[k] = nil;
	end
end

local function workspace_set(space, mode)
	tiler_logfun("set_mode=" .. mode)

	if (space_handlers[mode] == nil or mode == space.mode) then
		return;
	end

-- cleanup to revert to the normal stable state (tiled)
	local post_closure
	if (space.mode_hook) then
		post_closure = space:mode_hook();
		space.mode_hook = nil;
	end

-- for float, first reset to tile then switch to get a fair distribution
-- another option would be to first set their storage dimensions and then
-- force
	if (mode == "float" and space.mode ~= "tile" and not space.layouter) then
		space.mode = "tile";
		space:resize();
	end

	space.last_mode = space.mode;
	space.mode = mode;

-- enforce titlebar changes (some modes need them to work..)
	local lst = linearize(space);
	for k,v in ipairs(lst) do
		v.titlebar:switch_group(mode, true, mode ~= "float");
		v:set_title();
	end

-- relayout the space to match new constraints, and reflect changes in statusbar
	if (space.wm.spaces[space.wm.space_ind]) then
		tiler_statusbar_update(space.wm);
	end
	space:resize();

	if post_closure then
		post_closure();
	end
end

local function workspace_resize(space, external)
	if (space_handlers[space.mode]) then
		space_handlers[space.mode](space, external);
	end

	if (valid_vid(space.background)) then
		resize_image(space.background, space.wm.width, space.wm.height);
	end

	for k,v in pairs(space.listeners) do
		v(space, k, "resized");
	end
end

local function workspace_label(space, lbl)
	space.label = lbl;

-- update identifiers
	local lst = space:linearize();
	for i,v in ipairs(lst) do
		v:recovertag();
	end

	tiler_statusbar_update(space.wm);
end

local function workspace_empty(wm, i)
	return (wm.spaces[i] == nil or
		(#wm.spaces[i].children == 0 and wm.spaces[i].label == nil));
end

local function workspace_save(ws)

	local ind;
	for k,v in pairs(ws.wm.spaces) do
		if (v == ws) then
			ind = k;
		end
	end

	assert(ind ~= nil);

	local keys = {};
	local prefix = string.format("wsk_%s_%d", ws.wm.name, ind);
	keys[prefix .. "_mode"] = ws.mode;
	keys[prefix .. "_insert"] = ws.insert;
	if (ws.label) then
		keys[prefix .."_label"] = ws.label;
	end

	if (ws.background_name) then
		keys[prefix .. "_bg"] = ws.background_name;
	end

	drop_keys(prefix .. "%");
	store_key(keys);

-- depth serialization and metastructure missing, some of this come implicitly
-- through how windows are saved and their attempts at recreating known
-- structure during adopt phase
end

local function workspace_background(ws, bgsrc, generalize, bgsrc_input)
	local wm = ws.wm;
	if (not wm) then
		return;
	end

	if (bgsrc == wm.background_name and valid_vid(wm.background_id)) then
		bgsrc = wm.background_id;
	end

	local ttime = gconfig_get("transition");
	local crossfade = false;
	if (valid_vid(ws.background)) then
		ttime = ttime * 0.5;
		crossfade = true;
		expire_image(ws.background, ttime);
		blend_image(ws.background, 0.0, ttime);
		ws.background = nil;
		ws.background_name = nil;
	end

	local new_vid = function(src)
		if (not valid_vid(ws.background)) then
			ws.background = null_surface(wm.width, wm.height);
			image_mask_set(ws.background, MASK_UNPICKABLE);
			image_tracetag(ws.background, "workspace_bg", "workspace background");
			shader_setup(ws.background, "simple", "noalpha");
		end
		if (not valid_vid(ws.anchor)) then
			tiler_logfun("new on broken workspace");
			return;
		end
		resize_image(ws.background, wm.width, wm.height);
		link_image(ws.background, ws.anchor);
		local sb_sz = sbar_geth(wm);
		move_image(ws.background, -ws.wm.xoffset, -ws.wm.yoffset);
		if (crossfade) then
			blend_image(ws.background, 0.0, ttime);
		end
		blend_image(ws.background, 1.0, ttime);

-- if the background is an application and we want input forwarding,
-- set it as the workspace background_src and it will receive the nofocus
-- input
		if (valid_vid(src)) then
			image_sharestorage(src, ws.background);
			ws.background_src_input = bgsrc_input;
			if (bgsrc_input and valid_vid(src, TYPE_FRAMESERVER)) then
				ws.background_src = src;
			end
		end
	end

	if (bgsrc == nil) then
	elseif (type(bgsrc) == "string") then
-- before loading, check if some space doesn't already have the bg
		local vid = load_image_asynch(bgsrc, function(src, stat)
			if (stat.kind == "loaded") then
			ws.background_name = bgsrc;
			new_vid(src);
			delete_image(src);
			if (generalize) then
				wm.background_name = bgsrc;
				store_key(string.format("ws_%s_bg", wm.name), bgsrc);
			end
		else
			delete_image(src);
		end
	end);
--		new_vid(vid);
	elseif (type(bgsrc) == "number" and valid_vid(bgsrc)) then
		new_vid(bgsrc);
		ws.background_name = nil;
	else
		warning("workspace_background - called with invalid. arg");
	end
end

local function workspace_listener(ws, key, cbfun)
	ws.listeners[key] = cbfun;
end

local function workspace_preview(space, width, height, n_contrib, rate)
-- always return a vid, even if black
	if not space then
		return;
	end

-- filter out the n contributors with the largest surface area
	local lst = space:linearize();
	table.sort(lst, function(a, b)
		return (a.width * a.height) > (b.width * b.height);
	end);

	local wset = {};
	local n = n_contrib > #lst and #lst or n_contrib;
	for i=1,n_contrib do
		table.insert(wset, lst[i]);
	end

-- now build miniature border-less windows with the same surface,
-- this is another one of those where a lower level mip would be nice
	local wf = width / space.wm.width;
	local hf = height / space.wm.height;

	local set = {};
-- use background if available
	if (valid_vid(space.background)) then
		local nsrf = null_surface(width, height);
		if valid_vid(nsrf) then
			show_image(nsrf);
			image_sharestorage(space.background, nsrf);
			image_tracetag(nsrf, "workspace_preview_bg", "workspace preview");
			table.insert(set, nsrf);
		end
	end

-- then add the selection of miniatures
	for _,v in ipairs(wset) do
		local nsrf = null_surface(
			math.clamp(v.width * wf, 1, width),
			math.clamp(v.height * hf, 1, height)
		);
		if (valid_vid(nsrf)) then
			image_sharestorage(v.canvas, nsrf);
			show_image(nsrf);
			move_image(nsrf, v.x * wf, v.y * hf);
			order_image(nsrf, image_surface_resolve(v.canvas).order);
			image_tracetag(nsrf, "workspace_preview_item");
			table.insert(set, nsrf);
		end

-- there is more interesting things that can be done here for sure,
-- one paper (featur preserving downscaling) went into a 2-pass setup
-- with first pass doing a box-filter, then using that to calculate
-- a weight matrix used for convolution, as way of generating the
-- icons but preserving identification attributes.
		shader_setup(nsrf, "ui", "miniature", "active");
	end

	if #set == 0 then
		return;
	end

-- build the rendertarget and step it, but flush rtgt on failure
	local buf = alloc_surface(width, height);
	if not valid_vid(buf) then
		for _,v in ipairs(set) do
			delete_image(v);
		end
		return;
	end

-- set the rendertarget and make sure it has contents and that we
-- are not out of rendertargets (FBO allocation limit)
	if not (define_rendertarget(buf, set,
		RENDERTARGET_DETACH, RENDERTARGET_NOSCALE, rate)) then
		for _,v in ipairs(set) do
			delete_image(v);
		end
		delete_image(buf);
		return;
	else
		rendertarget_forceupdate(buf);
	end

-- caller is responsible for cleanup
	return buf;
end

create_workspace = function(wm, anim)
	if (not wm) then
		return;
	end

	local res = {
		activate = workspace_activate,
		deactivate = workspace_deactivate,
		resize = workspace_resize,
		destroy = workspace_destroy,
		migrate = workspace_migrate,
		save = workspace_save,
		linearize = linearize,
		lost = workspace_lost,
		preview = workspace_preview,

-- different layout modes, patch here and workspace_set to add more
		fullscreen = function(ws) workspace_set(ws, "fullscreen"); end,
		tile = function(ws) workspace_set(ws, "tile"); end,
		tab = function(ws) workspace_set(ws, "tab"); end,
		vtab = function(ws) workspace_set(ws, "vtab"); end,
		htab = function(ws) workspace_set(ws, "htab"); end,
		float = function(ws) workspace_set(ws, "float"); end,

		set_label = workspace_label,
		set_background = workspace_background,

-- for workspace destroy, window attach, window detach
		add_listener = workspace_listener,
		listeners = {},

-- can be used for clipping / transitions
		anchor = null_surface(wm.width, wm.height),
		mode = "tile",
		name = "workspace_" .. tostring(ent_count);
		insert = "h",
		children = {},
		weight = 1.0,
		vweight = 1.0,
		last_action = CLOCK
	};
	res.wm = wm;

	local mh = mouse_handler_factory.background(res);
	mouse_addlistener(mh,  {"button", "motion", "click", "rclick"});

	image_tracetag(res.anchor, "workspace_anchor");
	show_image(res.anchor);
	link_image(res.anchor, wm.anchor);
	ent_count = ent_count + 1;

-- special treat 'bsp' as it is treated as an insertion mode on tile
	local mode = gconfig_get("ws_default");
	if mode == "tile_bsp" then
		mode = "tile";
		res.insert = "bsp";
	end
	workspace_set(res, mode);

	if (wm.background_name) then
		res:set_background(wm.background_name);
	end

	res:activate(anim);
	return res;
end

local function wnd_merge(wnd, left, count)
	if (not wnd.space or
		(wnd.space.layouter and wnd.space.layouter.block_merge)) then
		return;
	end

-- find index in parent
	local i = 1;
	while (i ~= #wnd.parent.children) do
		if (wnd.parent.children[i] == wnd) then
			break;
		end
		i = i + 1;
	end

-- limit number of merges?
	local limit = count and count or #wnd.parent.children;

	if (left) then
		if (i == 1) then
			return;
		end

		for j=i-1,1,-1 do
			table.insert(wnd.children, wnd.parent.children[j]);
			wnd.parent.children[j].parent = wnd;
			table.remove(wnd.parent.children, j);
			limit = limit - 1;
			if (limit == 0) then
				break;
			end
		end

-- otherwise right
	else
		if (i >= #wnd.parent.children) then
			return;
		end

-- slice out and then add in reverse order
		local limit_i = math.clamp(i + limit, 1, #wnd.parent.children);
		local tmp = {};
		for j=limit_i,i+1,-1 do
			table.insert(tmp, wnd.parent.children[j]);
			table.remove(wnd.parent.children, j);
		end
		for i=#tmp,1,-1 do
			table.insert(wnd.children, tmp[i]);
			tmp[i].parent = wnd;
		end
	end

	wnd:recovertag();
	wnd.space:resize();
end

local function wnd_collapse(wnd)
	if (not wnd.space or
		(wnd.space.layouter and wnd.space.layouter.block_collapse)) then
		return;
	end

	local i = table.find_i(wnd.parent.children, wnd);
	local c = 1;
	for k,v in ipairs(wnd.children) do
		table.insert(wnd.parent.children, i+c, v);
		v.parent = wnd.parent;
		c = c + 1;
	end
	wnd.children = {};
	wnd.space:resize();
end

-- these rules are quite complicated in order to account for all different
-- kinds of custom scaling, effect scaling, cropping, client-preferred,
-- user overrides etc.
local function apply_scalemode(wnd, mode, src, props, maxw, maxh, force)
	local outw = 1;
	local outh = 1;

	if (wnd.scalemode == "client") then
		outw = math.clamp(props.width, 1, maxw);
		outh = math.clamp(props.height, 1, maxh);

	elseif (wnd.scalemode == "normal" and not force) then

		if (props.width > 0 and props.height > 0) then
			outw = props.width < maxw and props.width or maxw;
			outh = props.height < maxh and props.height or maxh;
		end

	elseif (wnd.scalemode == "aspect") then
		local ar = props.width / props.height;
		local wr = props.width / maxw;
		local hr = props.height / maxh;

		outw = hr > wr and maxh * ar or maxw;
		outh = hr < wr and maxw / ar or maxh;

	elseif (force or wnd.scalemode == "stretch") then
		outw = maxw;
		outh = maxh;
	end

	outw = math.floor(outw);
	outh = math.floor(outh);

-- we separate return width/height for the resize command
-- and for the values to forward / store in the structure
	local retw = outw;
	local reth = outh;

-- for normal where the source is larger than the alloted slot,
-- this does not stack with manually defined crop regions, though
-- the use cases are not really the same
	if (wnd.autocrop) then
		local ip = image_storage_properties(src);
		image_set_txcos_default(src, wnd.origo_ll);
		local ss = outw / ip.width;
		local st = outh / ip.height;
		image_scale_txcos(src, ss, st);

	elseif (wnd.in_drag_rz) then
-- some processing is missing here as well, we shouldn't apply
-- the resize to a non-scaled client before we actually get the
-- data
	else

	end

-- update the mouse scaling factors (value 5 and 6) so that the final
-- absolute value take the effective range into account
	if (wnd.crop_values) then
		local ip = image_storage_properties(src);
		wnd.crop_values[6] =
			(ip.width - wnd.crop_values[2] - wnd.crop_values[4]) / ip.width;
		wnd.crop_values[5] =
			(ip.height - wnd.crop_values[1] - wnd.crop_values[3]) / ip.height;

		local s1 = wnd.crop_values[2] / ip.width;
		local t1 = wnd.crop_values[1] / ip.height;
		local s2 = (ip.width - wnd.crop_values[4]) / ip.width;
		local t2 = (ip.height - wnd.crop_values[3]) / ip.height;
		if (wnd.origo_ll) then
			local tmp = t2;
			t2 = t1;
			t1 = tmp;
		end

		image_set_txcos(wnd.canvas, {s1, t1, s2, t1, s2, t2, s1, t2});

		if (not wnd.ignore_crop) then
			retw = ip.width - wnd.crop_values[2] - wnd.crop_values[4];
			reth = ip.height - wnd.crop_values[1] - wnd.crop_values[3];
		end
	end

	if (wnd.filtermode) then
		image_texfilter(src, wnd.filtermode);
	end

	tiler_debug(wnd.wm,
		string.format("pre_resize:name=%s:scale=%s:sw=%d:sh=%d:maxw=%d:maxh=%d" ..
			":force=%s:outw=%d:outh=%d:origo=%s", wnd.name, wnd.scalemode, props.width,
			props.height, maxw, maxh, force and "yes" or "no", outw, outh,
			wnd.origo_ll and "ll" or "ul")
	);

	return outw, outh, retw, reth;
end

local function wnd_effective_resize(wnd, neww, newh, ...)
	wnd:resize(
		math.floor(neww + wnd.pad_left + wnd.pad_right),
		math.floor(newh + wnd.pad_top + wnd.pad_bottom), ...
	);
end

local lfh = target_fonthint;
target_fonthint = function(id, fn, sz, hint, app)
	if (type(fn) == "table") then
		for k,v in ipairs(fn) do
			lfh(id, v, sz, hint, k > 1 and 1 or 0);
		end
	else
		lfh(id, fn, sz, hint, app);
	end
end

local function wnd_font(wnd, sz, hint, font)
	if (wnd.font_block) then
		if (type(wnd.font_block) == "function") then
			wnd:font_block(sz, hint, font);
		end
		return;
	end

	if (valid_vid(wnd.external, TYPE_FRAMESERVER)) then
		if (type(font) == "string") then
			font = {font};
		end

-- maintain tracking of font settings
		if (wnd.last_font) then
			wnd.last_font = {
				sz ~= -1 and sz or wnd.last_font[1],
				hint ~= -1 and hint or wnd.last_font[2],
				font and font or wnd.last_font[3]
			};
		else
			wnd.last_font = {sz, hint, font and font or {""}};
		end
		sz = wnd.last_font[1];
		hint = wnd.last_font[2];
		assert(type(wnd.last_font[3]) == "table");

-- update font or only attributes?
		if (font) then
			for i=1,#wnd.last_font[3] do
				target_fonthint(wnd.external,
					wnd.last_font[3][i], sz * FONT_PT_SZ, hint, i ~= 1);
			end
-- only attributes
		else
			target_fonthint(wnd.external, sz * FONT_PT_SZ, hint);
		end
	end
end

local function wnd_repos(wnd)
--reposition within the alotted space
	if (not wnd.space) then
		return;
	end

-- figure out the animation time and interpolation span in order to have the
-- same calculation and reset behavior for both the decorations and the canvas
	local lm, lr, interp = wnd_animation_time(wnd, wnd.anchor, false, true);
	wnd.ofs_x = 0;
	wnd.ofs_y = 0;

	if (wnd.centered and wnd.space.mode ~= "float") then
-- this means that the anchor won't actually be at wnd.x, wnd.y, which affects
-- the mode-switch from tile to something else and for temporary- drag
		if (wnd.space.mode == "tile") then
-- centering operation can be visually annoying during a cascaded tile relayout
-- when a resize operation has just occured on an external window. In that case,
-- defer the reposition based on displayhint timestamp.
			if wnd.hint_ts and CLOCK - wnd.hint_ts <= 2 then
				if not wnd.relayout_queued then
					wnd.relayout_queued = true
					timer_add_periodic(
						"relayout_" .. wnd.name, 1, true, function()
							wnd.relayout_queued = nil
							if wnd.reposition then
								wnd:reposition()
							end
						end, true)
					end
				return
			end

			wnd.ofs_x = math.floor(0.5 * (wnd.max_w - wnd.width));
			wnd.ofs_y = math.floor(0.5 * (wnd.max_h - wnd.height));

			move_image(wnd.anchor, wnd.x + wnd.ofs_x, wnd.y + wnd.ofs_y, lm, interp);

		elseif (is_tab_mode(wnd.space.mode)) then
			move_image(wnd.anchor, 0, 0);
		end

		if (wnd.fullscreen) then
			move_image(wnd.canvas,
				math.floor(0.5*(wnd.wm.width - wnd.effective_w)),
				math.floor(0.5*(wnd.wm.height - wnd.effective_h)));
		end
	else
		move_image(wnd.anchor, wnd.x, wnd.y, lm, interp);
	end

	run_event(wnd, "move", wnd.x, wnd.y);
end

local function wnd_hide(wnd)
	hide_image(wnd.anchor);
	wnd.hidden = true;
end

local function wnd_show(wnd)
	show_image(wnd.anchor);
	wnd.hidden = false;
end

local function wnd_recalc_pad(wnd)
	local tbh = tbar_geth(wnd);
	local bw = wnd:border_width();

	wnd.pad_top = bw;
	wnd.pad_left = bw;
	wnd.pad_right = bw;
	wnd.pad_bottom = bw;

	local pos = gconfig_get("tbar_position")
	if pos == "left" then
		wnd.pad_left = wnd.pad_left + tbh;
	elseif pos == "right" then
		wnd.pad_right = wnd.pad_right + tbh;
	elseif pos == "down" then
		wnd.pad_bottom = wnd.pad_bottom + tbh;
	else
		wnd.pad_top = wnd.pad_top + tbh;
	end
end

wnd_size_decor = function(wnd, w, h, animate)
-- redraw / update the decorations
	local bw = wnd:border_width();
	local tbh = tbar_geth(wnd);
	local interp = nil;
	local at = 0;
	local af = nil;

	if (animate) then
		_, at, af = wnd_animation_time(wnd, wnd.anchor, true, false);
	end

	local want_shadow = wnd.want_shadow and not wnd.fullscreen
	if (want_shadow) then
		suppl_region_shadow(wnd, w, h, {time = at, interp = af, reference = wnd.canvas});
	elseif valid_vid(wnd.shadow) then
		hide_image(wnd.shadow)
	end

	tiler_debug(wnd.wm, string.format(
		"size_decor:animate=%s:at=%d:border=%d:tbar=%d:shadow=%s",
		animate and "yes" or "no", at, bw, tbh, want_shadow and "yes" or "no")
	);

	wnd_recalc_pad(wnd);

-- note that all these resize calls should actually first get the 'reset'
-- transform length and subtract that from the at if the at is larger than
-- zero to get proper animation cancellation
	reset_image_transform(wnd.anchor);
	resize_image(wnd.anchor, w, h, at);

	local border_ofs_y = 0;
	local border_ofs_x = 0;

	if (wnd.show_titlebar or not tbar_mode(wnd.space.mode)) then
		wnd.titlebar:show();

		local pos = gconfig_get("tbar_position");
		if pos == "left" then
			wnd.titlebar:set_vertical();
			wnd.titlebar:resize(tbh,
				wnd.height - wnd.pad_top - wnd.pad_bottom + wnd.dh_pad_h, at, af);
			wnd.titlebar:reanchor(wnd.anchor, 4, bw, wnd.pad_top, ANCHOR_UL);
		elseif pos == "right" then
			wnd.titlebar:set_vertical();
			wnd.titlebar:resize(tbh,
				wnd.height - wnd.pad_top - wnd.pad_bottom + wnd.dh_pad_h, at, af);
			wnd.titlebar:reanchor(wnd.anchor, 4, -tbh, wnd.pad_top, ANCHOR_UR);
		elseif pos == "down" then
			wnd.titlebar:set_horizontal();
			wnd.titlebar:resize(
				wnd.width - wnd.pad_left - wnd.pad_right + wnd.dh_pad_w, tbh, at, af);
			wnd.titlebar:reanchor(wnd.anchor, 4, wnd.pad_left, -tbh - bw, ANCHOR_LL);
		else
			wnd.titlebar:set_horizontal();
			if wnd.titlebar:is_compact() then
				border_ofs_y = tbh;
			end

			wnd.titlebar:resize(
				wnd.width - wnd.pad_left - wnd.pad_right + wnd.dh_pad_w, tbh, at, af);
			wnd.titlebar:reanchor(wnd.anchor, 4, bw, bw, ANCHOR_UL);
		end

-- only hide if we are not in a nested state. otherwise parent decides
	elseif (not wnd.titlebar.parent) then
		wnd.titlebar:hide();
	end

	if (wnd.show_border) then
		reset_image_transform(wnd.border);
		resize_image(wnd.border,
			w + wnd.dh_pad_w - border_ofs_x,
			h + wnd.dh_pad_h - border_ofs_y, at, af);
		move_image(wnd.border, border_ofs_x, border_ofs_y, af);
		show_image(wnd.border);
	else
		hide_image(wnd.border);
	end

	reset_image_transform(wnd.canvas);
	if (animate and wnd.resize_w and wnd.resize_h) then
		resize_image(wnd.canvas, wnd.resize_w, wnd.resize_h, at, af);
	else
		resize_image(wnd.canvas, wnd.effective_w, wnd.effective_h);
	end

	shader_setup(wnd.border, "ui",
		wnd.space.mode == "float" and "border_float" or "border", wnd.titlebar.state);

	move_image(wnd.canvas, wnd.pad_left, wnd.pad_top, at, af);
end

--
-- One of the worst functions in the entire project, the amount of
-- edge cases are considerable. Test for:
--  . float drag-resize during external resize
--  . source that stretch, source that force aspect
--  . layouter- triggered
--  . switch to/from float
--  . dbl-click titlebar in float
--  . migrate then reposition
--  . toggle decorations / titlebar
--  . spawn during float
--
local function wnd_resize(wnd, neww, newh, force, maskev)
	if (wnd.in_drag_rz and not force) then
		return false;
	end

-- programming error, invoked on not-attached
	if (not valid_vid(wnd.canvas) or not wnd.space) then
		tiler_debug(active_display(), "kind=error:message=resize_unattached");
		return false;
	end

-- clamp desired new complete window width
	neww = math.clamp(neww, wnd.wm.min_width);
	newh = math.clamp(newh, wnd.wm.min_height);

	if (not force) then
		neww = math.clamp(neww, neww, wnd.max_w);
		newh = math.clamp(newh, newh, wnd.max_h);
	end

-- take the properties of the backing store, subtract the crop area
	local props = image_storage_properties(wnd.canvas);
	props.width = props.width - wnd.dh_pad_w;
	props.height = props.height - wnd.dh_pad_h;

-- to save space for border width, statusbar and other properties
	local decw = math.floor(wnd.pad_left + wnd.pad_right);
	local dech = math.floor(wnd.pad_top + wnd.pad_bottom);

-- reposition according to padding / decoration
	if (not wnd.fullscreen) then
		move_image(wnd.canvas, wnd.pad_left, wnd.pad_top);
		neww = neww - decw;
		newh = newh - dech;
	else
		decw = 0;
		dech = 0;
	end

-- edge-case ignore
	if (neww <= 0 or newh <= 0) then
		return;
	end

	force = force and force or
		(wnd.space.mode == "float" and true) or false;

-- Now we have the desired [neww, newh], the current [props],
-- the scalemode, the size of the decration areas. Combine to calculate
-- the size, input scaling and so on for the effective surface (canvas)
	local outw, outh, rzw, rzh;
	if (force) then
		outw, outh, rzw, rzh = apply_scalemode(
			wnd, wnd.scalemode, wnd.canvas, props, neww, newh, force);
	else
		outw, outh, rzw, rzh = apply_scalemode(wnd, wnd.scalemode,
			wnd.canvas, props, wnd.max_w-decw, wnd.max_h-dech, force);
	end

-- effective size + decoration sizes = total size
	wnd.effective_w = outw;
	wnd.effective_h = outh;

-- but we may want different actual size arguments to the canvas itself
	wnd.resize_w = rzw;
	wnd.resize_h = rzh;
	wnd.resize_ts = CLOCK;

	wnd.width = wnd.effective_w + decw - wnd.dh_pad_w;
	wnd.height = wnd.effective_h + dech - wnd.dh_pad_h;

-- still up for experimentation, but this method favors
-- the canvas size rather than the allocated tile size
	wnd_size_decor(wnd, wnd.width, wnd.height, force);
	wnd:reposition();

-- allow a relayouter to manipulate sizes etc. and finally, call all resize
-- listeners. the most important one is in durden.lua which tells each external
-- client what it will be displayed as.
	if (wnd.space.layouter and wnd.space.layouter.block_rzevent) then
		wnd.space.layouter.resize(wnd.space, nil, true, wnd,
			function(neww, newh, effw, effh)
				tiler_debug(wnd.wm,
					string.format("resize:name=%s:scale=%s:w=%d:h=%d:ew=%d:eh=%d",
						wnd.name, wnd.scalemode, neww, newh, effw, effh)
				);
				run_event(wnd, "resize", neww, newh, effw, effh);
			end
		);

	elseif (not maskev) then
		tiler_debug(wnd.wm,
			string.format("resize:name=%s:scale=%s:w=%d:h=%d:ew=%d:eh=%d", wnd.name,
				wnd.scalemode, wnd.width, wnd.height, wnd.effective_w, wnd.effective_h));
		run_event(wnd, "resize", neww, newh, wnd.effective_w, wnd.effective_h);
	else
		tiler_debug(wnd.wm,
			string.format("resize_masked:name=%s:scale=%s:w=%d:h=%d:ew=%d:eh=%d", wnd.name,
				wnd.scalemode, wnd.width, wnd.height, wnd.effective_w, wnd.effective_h));
	end

-- overlay surfaces that are attached to the window canvases also need to
-- be updated to reflect the changes, and save the new state into the tag
-- area of the canvas.
	wnd:synch_overlays();
	wnd:recovertag();
end

-- sweep all windows, calculate center-point distance,
-- and weight based on desired direction (no diagonals)
local function find_nearest(wnd, wx, wy)
	if (not wnd.space) then
		return;
	end

	local lst = linearize(wnd.space);
	local ddir = {};

	local cp_xy = function(vid)
		local props = image_surface_resolve(vid);
		return (props.x + 0.5 * props.width), (props.y + 0.5 * props.height);
	end

	local bp_x, bp_y = cp_xy(wnd.canvas);

-- only track distances for windows in the desired direction (wx, wy)
	local shortest;

	for k,v in ipairs(lst) do
		if (v ~= wnd and not v.hidden) then
			local cp_x, cp_y = cp_xy(v.canvas);
			cp_x = cp_x - bp_x;
			cp_y = cp_y - bp_y;
			local dist = math.sqrt(cp_x * cp_x + cp_y * cp_y);
			if ((cp_x * wx > 0) or (cp_y * wy > 0)) then
				if (not shortest or dist < shortest[2]) then
					shortest = {v, dist};
				end
			end
		end
	end

	return (shortest and shortest[1] or nil);
end

local level_step =
function(mw, lst, step)
	local ind = table.find_i(lst, mw);
	local ni = ind;
	if #lst == 0 then
		return
	end

	repeat
		ni = ni + step;
		if ni <= 0 then
			ni = #lst
		end
		if ni > #lst then
			ni = 1
		end
		if not lst[ni].hidden then
			break;
		end
	until ni == ind;

	return lst[ni];
end

local function cycle_window(mw, step, vertical)
	local mode = mw.space.mode;

-- float and tile uses spatial
	if mode == "float" then
		local sx = step;
		local sy = 0;
		if vertical then
			sy = step;
			sx = 0;
		end
		return find_nearest(mw, sx, sy);
	end

-- tab is 'flattened'
	if is_tab_mode(mwm) then
		return level_step(mw, linearize(mw.space), step);
	end

-- left is tiled, parent case is 'simple' unless root node is hidden
	if vertical then
		local base = mw

		if (step < 0) then
			while mw.parent do
				mw = mw.parent
				if not mw.hidden then
					return mw;
				end
			end
			return cycle_window(mw.parent, step, false);
		else
			for i,v in ipairs(mw.children) do
				if not v.hidden then
					return v;
				end
			end
		end

-- if we are at root and can't go further? switch to horiz
		mw = base
	end

	local res = level_step(mw, mw.parent.children, step);
	if not res or res == mw and mw.parent then
		return cycle_window(mw, -1, true);
	end
	return res;
end

local function wnd_next(mw, vert)
	if (mw.fullscreen or not mw.space) then
		return;
	end

	local res = cycle_window(mw, 1, vert);
	if res and res.select then
		res:select();
	end
end

local function wnd_prev(mw, vert)
	if (mw.fullscreen or not mw.space) then
		return;
	end

	local res = cycle_window(mw, -1, vert);
	if res and res.select then
		res:select();
	end
end

local function wnd_reassign(wnd, ind, ninv)
-- for reassign by name, resolve to index
	local newspace = nil;
	local wm = wnd.wm;
	if (not wnd.space) then
		return;
	end

-- this ugly mess should really be split up into func/type
	if (type(ind) == "string") then
		for k,v in ipairs(wm.spaces) do
			if (v.label == ind) then
				ind = k;
			end
		end
		if (type(ind) == "string") then
			return;
		end
		newspace = wm.spaces[ind];
	elseif (type(ind) == "table") then
		newspace = ind;
		for i,v in ipairs(wm.spaces) do
			if (v == ind) then
				ind = i;
				break;
			end
		end
		if (type(ind) == "table") then
			warning("migrate couldn't space with matching table");
			return;
		end
	else
		newspace = wm.spaces[ind];
	end

-- don't switch unless necessary
	if (wnd.space == newspace or wnd.fullscreen) then
		return;
	end

	if (wnd.space.selected == wnd) then
		wnd.space.selected = nil;
	end

	if (wnd.space.previous == wnd) then
		wnd.space.previous = nil;
	end

-- drop selection references unless we can find a new one,
-- or move to child if there is one
	if (wm.selected == wnd) then
		wnd:prev();
		if (wm.selected == wnd) then
			if (wnd.children[1] ~= nil) then
				wnd.children[1]:select();
			else
				wm.statusbar:set_nested();
				wm.selected = nil;
			end
		end
	end
-- create if it doesn't exist
	local oldspace = wm:active_space();
	if (newspace == nil) then
		wm.spaces[ind] = create_workspace(wm);
		newspace = wm.spaces[ind];
	end

	moveup_children(wnd);

-- update workspace assignment
	wnd.children = {};
	local oldspace = wnd.space;
	wnd.space = newspace;
	wnd.space_ind = ind;
	wnd.parent = newspace;
-- weights aren't useful for new space, reset
	wnd.weight = 1.0;
	wnd.vweight = 1.0;
	link_image(wnd.anchor, newspace.anchor);

-- restore vid structure etc. to the default state

-- edge condition, if oldspace had more children, the select event would
-- have caused a deselect already - but deselect can only be called once
-- or iostatem_ saving will be messed up.
	if (#oldspace.children == 0) then
		wnd:deselect();
	end

-- the hook might consume the window, and then we can do nothing more
	if (oldspace.reassign_hook and newspace.mode ~= oldspace.mode) then
		if oldspace:reassign_hook(wnd) then
			return
		end;
	end

-- subtle resize in order to propagate resize events while still hidden
	if (not(newspace.selected and newspace.selected.fullscreen)) then
		newspace.selected = wnd;
		if not (newspace.layouter and newspace.layouter.added(newspace, wnd)) then
			table.insert(newspace.children, wnd);
			newspace:resize();
		end
		if (not ninv) then
			newspace:deactivate(true);
		end
	else
		table.insert(newspace.children, wnd);
	end

-- since new spaces may have come and gone
	tiler_statusbar_update(wm);
	if not (oldspace.layouter and oldspace.layouter.lost(oldspace, wnd)) then
		oldspace:resize();

-- protect against layouter breaking selection
		if ((not oldspace.selected or not wm.selected
			or wm.selected ~= oldspace.selected) and #oldspace.children > 0) then
			oldspace.children[#oldspace.children]:select();
		end
	end

-- and with a new mode, the set of titlebar icons might be different
	wnd.titlebar:switch_group(newspace.mode, true, newspace.mode ~= "float");

-- grab any swallow targets as well
	if wnd.swallow_window then
		wnd.swallow_window:assign_ws(ind, nind)
	end
end

local function wnd_drag_resize_enter(wnd, mask)
	tiler_debug(wnd.wm, "drag_resize_enter");

	wnd.in_drag_rz = true;
	if wnd.maximized then
		wnd:toggle_maximize();
	end

	wnd.drag_sz_ack = {
		w      = wnd.effective_w,
		h      = wnd.effective_h,
		acc_x  = 0,
		acc_y  = 0,
		size_x = mask[1], -- multiply acc to get dw, dh
		size_y = mask[2],
		pos_x  = mask[3], -- multiply acc to get move- delta
		pos_y  = mask[4]
	};
	wnd.drag_mode = wnd.scalemode;

-- it was easier (though not as pretty) this way to get the problem
-- with dominant axis/direction vs. drag- side when it comes to aspect-
-- ratio preserving drag resize.
	if (wnd.scalemode == "aspect") then
		wnd.scalemode = "stretch";
	end
end

local function wnd_drag_resize_leave(wnd)
	tiler_debug(wnd.wm, "drag_resize_leave")
	local dt = wnd.drag_sz_ack

	if not dt then
		return
	end

	if wnd.scalemode == "client" then
		dt.finished = true
		return
	end

	wnd.scalemode = wnd.drag_mode
	wnd.in_drag_rz = false

	local ew = dt.w + dt.acc_x
	local eh = dt.h + dt.acc_y
	wnd.drag_sz_ack = nil

-- make sure any client triggers etc. trigger accordingly
	wnd:resize_effective(ew, eh, true, false)
end

local function wnd_drag_resize(wnd, mask, dx, dy)
	tiler_debug(wnd.wm, "step_drag_resize")

	local dt = wnd.drag_sz_ack
	if not dt then
		return
	end

	dt.acc_x = dt.acc_x + dx * mask[1]
	dt.acc_y = dt.acc_y + dy * mask[2]

-- for client we track how much has accumulated since the dimensions of
-- the last known frame update as the resize handler in extev.lua tracks
	if wnd.scalemode == "client" then
		wnd:displayhint(
			dt.w + dt.acc_x,
			dt.h + dt.acc_y,
			bit.bor(wnd.dispmask, TD_HINT_CONTINUED)
		)
		return
	end

-- scale / aspect / crop we don't really care
	wnd.x = wnd.x + dx * mask[3]
	wnd.y = wnd.y + dy * mask[4]

-- forced masked resize to avoid feedback loops from event handlers
	wnd:resize_effective(
		dt.w + dt.acc_x, dt.h + dt.acc_y,
		true, true
	)

	move_image(wnd.anchor, wnd.x, wnd.y)
end

local function wnd_move(wnd, dx, dy, align, abs, now, noclamp)
	if (not wnd.space) then
		return;
	end

	tiler_debug(wnd.wm, string.format(
		"move:name=%s:absolute=%s:x=%d:y=%d:align=%s:now=%s:noclamp=%s",
		wnd.name, abs and "true" or "false", dx, dy,
		align and "true" or "false", now and "true" or "false",
		noclamp and "true" or "false")
	);

-- make sure the titlebar (if visible) isn't occluded by the statusbar
	local tbh = tbar_geth(wnd);
	local lm, ls, interp = wnd_animation_time(wnd, wnd.anchor, false, true);

	if (abs) then
		local props = image_surface_resolve(wnd.wm.anchor);
		wnd.x = wnd.wm.xoffset + dx - props.x;
		wnd.y = wnd.wm.yoffset + dy - props.y;

	elseif (align) then
		wnd.x = wnd.x + dx;
		wnd.y = wnd.y + dy;
		if (dx ~= 0) then
			wnd.x = wnd.x + (dx + -1 * dx) * math.fmod(wnd.x, math.abs(dx));
		end
		if (dy ~= 0) then
			wnd.y = wnd.y + (dy + -1 * dy) * math.fmod(wnd.y, math.abs(dy));
		end
		wnd.x = wnd.x < 0 and 0 or wnd.x;
		wnd.y = wnd.y < 0 and 0 or wnd.y;

	else
		wnd.x = wnd.x + dx;
		wnd.y = wnd.y + dy;
	end

	if (now) then
		lm = 0;
	end

-- this depends on titlebar state / position
	if (not noclamp) then
		wnd.y = math.clamp(wnd.y, 0, wnd.wm.ylimit - tbh);
	end

	tiler_debug(wnd.wm, string.format(
		"position:x=%.0f:y=%.0f:time=%d:method=%d", wnd.x, wnd.y, lm, interp));

	run_event(wnd, "move", wnd.x, wnd.y);
	move_image(wnd.anchor, wnd.x, wnd.y, lm, interp);
	wnd:recovertag();
end

--
-- build a popup that is attached to wnd at a fitting spot within
-- x1,y1,x2,y2 and a bias towards (bias_v) based on the current
-- window position. Inputs on other windows, etc. will kill the
-- popup and invoke destroy_cb.
--
--
-- If the bias is 0,it will try and pick 1 or 3 based on if there
-- are more popups or not.
-- 1 -- 2 -- 3
-- |    |    |
-- 4 -- 5 -- 6
-- |    |    |
-- 7 -- 8 -- 9
--
-- If there is already a popup on the window, the new popup will
-- be attached to that one if chain is set - or the current chain
-- will be destroyed/removed first if chain isn't set.
--
-- There are quite a few interesting edge cases here, particularly
-- in relation to locking and with the conditions that should force-
-- destroy popup chains, but also when it comes to all possible
-- presentation modes, like fullscreen etc.
--

-- compatibility hack
if not ANCHOR_LC then
	ANCHOR_CL = ANCHOR_UL;
	ANCHOR_CR = ANCHOR_UR;
	ANCHOR_UC = ANCHOR_UL;
	ANCHOR_LC = ANCHOR_LL;
end

local bias_lut = {
	ANCHOR_UL,
	ANCHOR_UC,
	ANCHOR_UR,
	ANCHOR_CL,
	ANCHOR_C,
	ANCHOR_CR,
	ANCHOR_LL,
	ANCHOR_LC,
	ANCHOR_LR
};

local function wnd_popup(wnd, vid, chain, destroy_cb)
	if (not valid_vid(vid)) then
		return;
	end

-- alias canvas to anchor so that it looks like a window
	local res = {
		anchor = null_surface(1, 1),
		on_destroy = destroy_cb
	};
	res.canvas = res.anchor;

	if (not valid_vid(res.anchor)) then
		return;
	end
	image_tracetag(res.anchor, "popup_anchor");
	local dst = wnd;

	if (chain) then
		if (#wnd.popups > 0) then
			dst = wnd.popups[#wnd.popups];
		end
	end

-- destroying an earlier popup should cascade down the chain
	res.destroy = function(pop)
		tiler_debug(wnd.wm,
			string.format("popup_destroyed:name=%s:index=%d", wnd.name, res.index));
		res.dead = true

		delete_image(vid);
		mouse_droplistener(pop);
		for i=#wnd.popups, pop.index, -1 do
			if (wnd.input_focus) then
				table.remove_match(wnd.input_focus, wnd.popups[i]);
				if (#wnd.input_focus == 0) then
					wnd.input_focus = nil;
				end
			end
			wnd:drop_popup();
		end
	end

-- we chain onwards so the res table exposes mostly the same entry points
-- as a normal window
	res.add_popup = function(pop, source, dcb)
		return wnd:add_popup(source, dcb);
	end

	res.focus = function(pop, state)
		if (not wnd.input_focus) then
			wnd.input_focus = {pop};
		else
			table.remove_match(wnd.input_focus, pop);
			table.insert(wnd.input_focus, pop);
		end
	end

	res.show = function(pop)
		blend_image(vid, 1.0, gconfig_get("animation"));
	end

	res.hide = function(pop)
		blend_image(vid, 0.0, gconfig_get("animation"));
	end

	res.reposition = function(pop, x1, y1, x2, y2, bias)
		if (wnd.crop_values) then
			x1 = x1 - wnd.crop_values[2];
			y1 = y1 - wnd.crop_values[1];
			x2 = x2 - wnd.crop_values[2];
			y2 = y2 - wnd.crop_values[1];
		end

-- figure out where the caller want to bias the popup anchor and tie the src
-- vid to our new popup anchor
		local ap = bias == 0 and (#wnd.popups > 0 and 3 or 1) or bias;
		ap = bias_lut[ap] and bias_lut[ap] or ANCHOR_UL;
		link_image(vid, res.anchor, ap);
		move_image(res.anchor, x1, y1);

		local props = image_surface_resolve(res.anchor);
		local vprops = image_surface_resolve(vid);

-- account for overflow, the rules here aren't really as good as they could be
-- since there is a region of influence that could be taken into account for
-- the cases where the popup would hit the edge and you'd want to chose spawn
-- direction accordingly
		local ox = wnd.wm.width - (props.x + vprops.width);
		if (ox < 0) then
			nudge_image(res.anchor, ox, 0);
		end
		local oy = wnd.wm.height - (props.y + vprops.height);
		if (oy < 0) then
			nudge_image(res.anchor, 0, oy);
		end
		tiler_debug(wnd.wm,
			string.format(
				"popup_reposition:name=%s:index=%d:x1=%d:y1=%d:x2=%d:y2=%d:ox=%d:oy=%d",
				wnd.name, res.index, x1, y1, x2, y2, ox, oy)
		);
	end

-- tie our anchor to the canvas portion of the destination window OR if we are
-- launching popup inside popup, the 'fake' canvas of that popup
	link_image(vid, res.anchor);
	link_image(res.anchor, dst.canvas);
	image_inherit_order(vid, true);
	image_inherit_order(res.anchor, true);
	order_image(vid, 1);
	show_image(res.anchor);
	table.insert(wnd.popups, res);
	res.index = #wnd.popups;

-- add mouse handler, each one makes sure any children are killed off
	image_mask_set(res.anchor, MASK_UNPICKABLE);
	res.own = function(ctx, vid) return vid == vid; end

-- note, this does not rate-limit
	res.motion = function(ctx, vid, x, y, rx, ry)
		local aprops = image_surface_resolve(vid);
		local lx = x - aprops.x;
		local ly = y - aprops.y;
		target_input(vid, {
			kind = "analog", mouse = true, devid = 0, subid = 0,
			samples = {lx, rx}
		});
		target_input(vid, {
			kind = "analog", mouse = true, devid = 0, subid = 1,
			samples = {ly, ry}
		});
	end
	res.name = "popup";

	res.button = function(ctx, vid, ind, pressed, x, y)
		target_input(vid, { active = pressed,
			devid = 0, subid = ind, kind = "digital", mouse = true});
	end

	mouse_addlistener(res,
		valid_vid(vid, TYPE_FRAMESERVER) and {"button", "motion"} or {});

	tiler_debug(wnd.wm, string.format(
		"popup_added:name=%s:index=%d", wnd.name, res.index));
	return res;
end

local function wnd_droppopup(wnd, all)
	local at = gconfig_get("animation");

-- work in reverse order
	if (all) then
		for i=#wnd.popups,1,-1 do
			v = wnd.popups[i];
			if (v.on_destroy) then
				v:on_destroy();
			end
			expire_image(v.anchor, at);
			blend_image(v.anchor, 0.0, at);
			mouse_droplistener(v);
		end
		wnd.popups = {};
		wnd.input_focus = nil;

-- or just remove the previous in the chain
	elseif (#wnd.popups > 0) then
		local pop = wnd.popups[#wnd.popups];
		if (pop.on_destroy) then
			pop:on_destroy();
		end
		expire_image(pop.anchor, at);
		blend_image(pop.anchor, 0.0, at);
		mouse_droplistener(pop);

		table.remove(wnd.popups, #wnd.popups);
		if (wnd.input_focus) then
			table.remove_match(wnd.input_focus, pop);
			if (#wnd.input_focus == 0) then
				wnd.input_focus = nil;
			end
		end
	end
end

-- define a new crop region and remap mouse coordinates
local function wnd_crop(wnd, t, l, d, r, mask, nopad)
	local props = image_storage_properties(wnd.canvas);
	t = math.clamp(t, 0, props.width);
	l = math.clamp(l, 0, props.height);
	d = math.clamp(d, 0, props.height - t);
	r = math.clamp(r, 0, props.width - l);
	wnd.crop_values = {t, l, d, r, 1, 1};

-- when sending window sizes, add these values in order to go from sliced
-- window size to actual surface size, since we are now cropped, there is
-- more area for the client to use - basically the case of wl- clients on
-- tiling layout
	if (nopad) then
		wnd.dh_pad_w = 0;
		wnd.dh_pad_h = 0;
		wnd.ignore_crop = true;
	else
		wnd.ignore_crop = false;
		wnd.dh_pad_w = l + r;

-- missing coordinate calculations for zoom etc.wnd.dh_pad_h = t + d;
	end

	wnd:resize(wnd.width, wnd.height, false, mask);
end

-- and grow it
local function wnd_crop_append(wnd, t, l, d, r, mask)
	if (not wnd.crop_values) then
		return wnd:set_crop(t, l, d, r);
	end
	local props = image_storage_properties(wnd.canvas);
	wnd.crop_values[1] = math.clamp(wnd.crop_values[1] + t, 0, props.width);
	wnd.crop_values[2] = math.clamp(wnd.crop_values[2] + l, 0, props.height);
	wnd.crop_values[3] = math.clamp(
		wnd.crop_values[3] + d, 0, props.height - wnd.crop_values[1]);
	wnd.crop_values[4] = math.clamp(
		wnd.crop_values[4] + r, 0, props.width - wnd.crop_values[2]);

	wnd.dh_pad_h = wnd.crop_values[1] + wnd.crop_values[3];
	wnd.dh_pad_w = wnd.crop_values[2] + wnd.crop_values[4];
	wnd:resize(wnd.width, wnd.height, false, mask);
end

--
-- re-adjust each window weight, they are not allowed to go down to negative
-- range and the last cell will always pad to fit
--
local function wnd_grow(wnd, w, h)
	if (not wnd.space) then
		return;
	end

	if (wnd.space.mode == "float") then
		local stepw = math.floor(wnd.wm.effective_width * w);
		local steph = math.floor(wnd.wm.effective_height * h);

-- align to step size?
		if (wnd.sz_delta and wnd.sz_delta[1] > 0 and wnd.sz_delta[2] > 0) then
			if (w ~= 0) then
				stepw = math.clamp(
					math.floor(math.abs(wnd.sz_delta[1] / stepw)), 1) *
					wnd.sz_delta[1] * math.sign(w);
			end

			if (h ~= 0) then
				steph = math.clamp(
					math.floor(math.abs(wnd.sz_delta[2] / steph)), 1) *
					wnd.sz_delta[2] * math.sign(h);
			end
		end

-- if the client is allowed to drive its own resize, go with that.
		if (wnd.scalemode == "client" and
			valid_vid(wnd.external, TYPE_FRAMESERVER)) then
			local width = math.clamp(wnd.width + stepw, 32);
			local height = math.clamp(wnd.height + steph, 32);
			local efw = width - (wnd.pad_left + wnd.pad_right);
			local efh = height - (wnd.pad_top + wnd.pad_bottom);
			run_event(wnd, "resize", width, height, efw, efh);
-- and for the forced scalemodes, just go with that
		else
			wnd:resize(wnd.width + stepw, wnd.height + steph, true);
		end
		return;
	end

-- we don't care about grow in tabbed or if the layouter blocks us
	if (wnd.space.mode ~= "tile" or
		(wnd.space.layouter and wnd.space.layouter.block_grow)) then
		return;
	end

-- for tiled mode, recalc all horizontal and vertical weights
	if (h ~= 0) then
		wnd.vweight = wnd.vweight + h;
		wnd.parent.vweight = wnd.parent.vweight - h;
	end

-- horizontal being the worst as the siblings need to shrink
	if (w ~= 0) then
		wnd.weight = wnd.weight + w;
		if (#wnd.parent.children > 1) then
			local ws = w / (#wnd.parent.children - 1);
			for i=1,#wnd.parent.children do
				if (wnd.parent.children[i] ~= wnd) then
					wnd.parent.children[i].weight = wnd.parent.children[i].weight - ws;
				end
			end
		end
	end

-- and force a relayout
	wnd.space:resize();
end

local function wnd_title(wnd, title)
	local old_text = wnd.title_text

	if (title) then
		wnd.title = title;
	end

-- based on new title/ font, apply pattern and set to fill region
	local dsttbl = {};
	local ptn = wnd.titlebar_ptn and wnd.titlebar_ptn or gconfig_get("titlebar_ptn");
	suppl_ptn_expand(dsttbl, ptn, wnd);
	wnd.title_text = table.concat(dsttbl, " ");
	table.insert(dsttbl, 1, gconfig_get("tbar_textstr"));
	wnd.titlebar:update("center", 1, dsttbl);

	local wm = wnd.wm

-- notify if the title changed
	if old_text ~= wnd.title_text then
		for i,v in ipairs(wm.on_wnd_title) do
			v(wm, wnd, wnd.space, wnd.space == wm:active_space());
		end
	end
end

local function tiler_convert_mousexy(wnd, x, y, rx, ry)
-- note, this should really take viewport into account (if provided), when
-- doing so, move this to be part of fsrv-resize and manual resize as this is
-- rather wasteful.

-- first, remap coordinate range (x, y are absolute)
	local aprop = image_surface_resolve(wnd.canvas);
	local locx = x - aprop.x;
	local locy = y - aprop.y;

-- take server-side scaling into account
	local res = {};
	local sprop = image_storage_properties(
		valid_vid(wnd.external) and wnd.external or wnd.canvas);

	if wnd.autocrop then
		aprop.width = sprop.width;
		aprop.height = sprop.height;
	end

	local sfx = sprop.width / aprop.width;
	local sfy = sprop.height / aprop.height;
	local lx = sfx * locx;
	local ly = sfy * locy;

-- and append our translation
	if (wnd.crop_values) then
		lx = lx * wnd.crop_values[6] + wnd.crop_values[2];
		ly = ly * wnd.crop_values[5] + wnd.crop_values[1];
	end

	res[1] = lx;
	res[2] = rx and rx or 0;
	res[3] = ly;
	res[4] = ry and ry or 0;

-- track mouse sample and try to generate relative motion
	if (wnd.last_ms and not rx) then
		res[2] = (wnd.last_ms[1] - res[1]);
		res[4] = (wnd.last_ms[2] - res[3]);
	else
		wnd.last_ms = {};
	end

	wnd.last_ms[1] = res[1];
	wnd.last_ms[2] = res[3];

	return res;
end

local function wnd_mousecursor(wnd, cursor)
	wnd.cursor = cursor
	if wnd.space and wnd.space.selected == wnd then
		wnd:mouseactivate();
	end
end

local function wnd_mousebutton(wnd, ind, pressed, x, y)
	if (wnd.wm.selected ~= wnd) then
		return;
-- collapse the entire tree on canvas- click
	elseif (#wnd.popups > 0 and pressed) then
		wnd:drop_popup(true);
		return;
	end

	local m1, m2 = dispatch_meta();

	if (not m1 and not m2) then
		output_mouse_devent({
			active = pressed, devid = 0, subid = ind}, wnd);
	end

-- forward mouse event both in the display- local and the surface- local
	local x, y = mouse_xy();
	wnd_synch_mouse(wnd, x, y);
	run_event(wnd, "mouse_button",
		ind, pressed, x, y, wnd.mouse[1], wnd.mouse[2]);
end

local function wnd_toggle_maximize(wnd)

-- restore old?
	if (wnd.maximized) then
		local x = wnd.maximized.x * wnd.wm.effective_width;
		local y = wnd.maximized.y * wnd.wm.effective_height;
		wnd:move(x, y, false, true, false, true);

		local neww = wnd.maximized.w * wnd.wm.effective_width + wnd.dh_pad_w;
		local newh = wnd.maximized.h * wnd.wm.effective_height + wnd.dh_pad_h;
		wnd.dispmask = bit.bor(wnd.dispmask, TD_HINT_MAXIMIZED)

		if (wnd.scalemode == "client") then
			wnd:displayhint(neww, newh, wnd.dispmask);
		else
			wnd:resize(neww, newh, true);
		end
		wnd.maximized = nil;

-- or define new, we have the option here to decide if the titlebar should
-- be reattached to the statusbar to save more vertical space, and if the
-- border region should be hidden though right now it is just oversize and
-- position so the border falls outside
	else
		local cur = {};
		local props = image_surface_resolve(wnd.anchor);
		local neww = wnd.wm.effective_width;
		wnd.dispmask = bit.band(wnd.dispmask, bit.bnot(TD_HINT_MAXIMIZED))

-- save relative so we can restore properly even if the screen changes
		cur.x = wnd.x / wnd.wm.effective_width;
		cur.y = wnd.y / wnd.wm.effective_height;
		cur.w = wnd.width / wnd.wm.effective_width;
		cur.h = wnd.height / wnd.wm.effective_height;
		wnd.maximized = cur;

		wnd:move(0, 0, false, true, false, true);
		if (wnd.scalemode == "client") then
			wnd:displayhint(
				wnd.wm.effective_width - wnd.pad_left - wnd.pad_right - wnd.dh_pad_w,
				wnd.wm.effective_height - wnd.pad_top - wnd.pad_bottom - wnd.dh_pad_h,
				wnd.dispmask
			);
		else
			wnd:resize(wnd.wm.effective_width, wnd.wm.effective_height, true);
		end
	end
end

local function wnd_mousedblclick(wnd)
	if (#wnd.popups > 0) then
		wnd:drop_popup(true);
		return;
	end

	output_mouse_devent({
		active = true, devid = 0, subid = 0,
		label = "dblclick", gesture = true}, wnd
	);
end

local function wnd_mousepress(wnd)
	if (wnd.wm.selected ~= wnd) then
		if (gconfig_get("mouse_focus_event") == "click") then
			wnd:select(nil, true);
		end
		return;
	end

	local ct = mouse_state().cursortag;

	if (not wnd.space or wnd.space.mode ~= "float") then
		return;
	end
end

local function wnd_mousemotion(wnd, x, y, rx, ry)
-- popups, drag resize or internal-only windows are stop conditions
	if (wnd.input_focus or
		wnd.in_drag_move or wnd.in_drag_rz or
		not valid_vid(wnd.external, TYPE_FRAMESERVER)) then
		run_event(wnd, "mouse_motion", x, y, rx, ry)
		return;
	end

-- for center-lock we do the warping that some clients would otherwise do
	if (wnd.mouse_lock_center) then
		local rt = {
			kind = "analog",
			mouse = true,
			relative = true,
			devid = 0,
			subid = 2;
			samples = {rx, 0, ry, 0};
		};
		target_input(wnd.external, rt);
		return;
	end

-- apply coordinate transforms to reach surface-local coordinates
	local iotbl = {
		kind = "analog",
		mouse = true,
		devid = 0,
		subid = 2,
		samples = wnd.wm.convert_mouse_xy(wnd, x, y, rx, ry)
	};
	wnd.last_mouse_motion = iotbl;

-- with rate limited mouse events (those 2khz gaming mice that likes to saturate
-- things even when not needed), we accumulate relative samples and flush on timer
	if (not wnd.rate_unlimited) then
		if EVENT_SYNCH[wnd.external] then
			EVENT_SYNCH[wnd.external].pending = {iotbl};
		end
		return;
	end

	target_input(wnd.external, iotbl);
end

local function wnd_mousehover(wnd)
-- this event can be triggered slightly deferred and race against destroy
	if (not wnd.wm) then
		return;
	end

	if (wnd.wm.selected ~= wnd and
		gconfig_get("mouse_focus_event") == "hover") then
		wnd:select(nil, true);
	end
end

local function wnd_mouseover(wnd)
--focus follows mouse
	if (wnd.wm.selected ~= wnd and
		gconfig_get("mouse_focus_event") == "motion") then
		wnd:select(nil, true);
	end
end

local function wnd_alert(wnd)
	local wm = wnd.wm;

	if (not wnd.space or not wm.selected or wm.selected == wnd) then
		return;
	end

	if (wnd.space ~= wm.spaces[wm.space_ind]) then
		wm.sbar_ws[wnd.space_ind]:switch_state("alert");
	end

	wnd.titlebar:switch_state("alert", true);
	shader_setup(wnd.border, "ui",
		wnd.space.mode == "float" and "border_float" or "border", "alert");
end

local function wnd_prefix(wnd, prefix)
	wnd.prefix = prefix and prefix or "";
	wnd:set_title();
end

local function wnd_tag(wnd, tag)
	if (not tag or #tag == 0) then
		wnd.group_tag = nil;
	else
		wnd.group_tag = tag;
	end
end

local function wnd_ident(wnd, ident)
	wnd.ident = ident and ident or "";
	wnd:set_title();
end

local function wnd_getname(wnd)
	if (wnd.title_text and string.len(wnd.title_text) > 0) then
		return wnd.title_text;
	else
		return wnd.name;
	end
end

-- allow one or multiple listeners in a chain, since this can be
-- high frequency, try to avoid a table indirection if possible
local function wnd_add_dispatch(wnd, ev, fun)
	if (wnd.dispatch[ev]) then
		if (type(wnd.dispatch[ev]) == "function") then
			wnd.dispatch[ev] = {wnd.dispatch[ev]};
		end
		table.insert(wnd.dispatch[ev], fun);
	else
		wnd.dispatch[ev] = fun;
	end
end

local function wnd_drop_dispatch(wnd, ev, fun)
	if (not wnd.dispatch[ev]) then
		warning("tried to remove handler for unhandled event: " .. ev);
		return;
	end
	if (type(wnd.dispatch[ev]) == "function") then
		if (wnd.dispatch[ev] == fun) then
			wnd.dispatch[ev] = nil;
		else
			warning("tried to remove unregistered handler for: " .. ev);
		end
	else
		table.remove_match(wnd.dispatch[ev], fun);
-- demote back to single function
		if (#wnd.dispatch[ev] == 1) then
			wnd.dispatch[ev] = wnd.dispatch[ev][1];
		end
	end
end

local function wnd_addhandler(wnd, ev, fun)
	if (wnd.handlers[ev] == nil) then
		warning("tried to add handler for unknown event: " .. ev);
		return;
	end

-- enable frame delivery events
	if (ev == "frame" and
		#wnd.handlers.frame == 0 and valid_vid(wnd.external)) then
		tiler_logfun(string.format(
			"wnd=:%s:kind=status:message=frame enabled", wnd.name));
		target_flags(wnd.external, TARGET_VERBOSE, true);
	end

	table.remove_match(wnd.handlers[ev], fun);
	table.insert(wnd.handlers[ev], fun);
end

local function wnd_drophandler(wnd, ev, fun)
	assert(ev);
	if (wnd.handlers[ev] == nil) then
		warning("tried to remove handler for unknown event: " .. ev);
		return;
	end
	table.remove_match(wnd.handlers[ev], fun);

-- enable frame delivery events
	if (ev == "frame" and
		#wnd.handlers.frame == 0 and valid_vid(wnd.external)) then
		tiler_logfun(string.format(
			"wnd=:%s:kind=status:message=frame disabled", wnd.name));
		target_flags(wnd.external, TARGET_VERBOSE, false);
	end
end

local function wnd_dispmask(wnd, val, noflush)
	wnd.dispmask = wnd.dispstat_block and wnd.dispmask or val;

	if (not noflush) then
		wnd:displayhint(0, 0, wnd.dispmask);

-- tell the scheduler to prioritise this target
		if (not bit.band(wnd.dispmask, TD_HINT_UNFOCUSED)
			and valid_vid(wnd.external, TYPE_FRAMESERVER)) then
			focus_target(wnd.external);
		end
	end
end

local function wnd_migrate(wnd, tiler, disptbl)
	if (tiler == wnd.wm) then
		return;
	end

-- revert to normal state on fullscreen
	if (wnd.fullscreen and wnd.space) then
		wnd.space:tile();
	end

-- need the list of windows in the space to find any dependent
	local windows = linearize(space)

-- select next in line
	wnd:prev();
	if (wnd.wm.selected == wnd) then
		if (wnd.children[1] ~= nil) then
			wnd.children[1]:select();
		else
			wnd.wm.selected = nil;
		end
	end

	local reattach_full =
	function(wnd, dst)
		for i,v in ipairs(get_hier(wnd.anchor)) do
			rendertarget_attach(dst, v, RENDERTARGET_DETACH);
			local tt = image_tracetag(v)
			tiler_debug(wnd.wm, "reattach:name=%s", tt and tt or "missing");
		end
		rendertarget_attach(dst, wnd.anchor, RENDERTARGET_DETACH);
	end

-- switch rendertarget
-- change association with wm and relayout old one
	if (not wnd.space) then
		return;
	end

	tiler_debug(wnd.wm, string.format(
		"migrate:name=%s:to=%s", wnd.name, wnd.wm.name, tiler.name));

	local oldsp = wnd.space;
	table.remove_match(wnd.wm.windows, wnd);
	wnd.wm = tiler;
	oldsp:resize();

-- employ relayouting hooks to currently active ws
	local dsp = tiler.spaces[tiler.space_ind];
	wnd:assign_ws(dsp, true);
	wnd.children = {};

-- rebuild border and titlebar to account for changes in font/scale
	for i in wnd.titlebar:all_buttons() do
		i.fontfn = tiler.font_resfn;
	end
	wnd.titlebar:invalidate();
	wnd:set_title();

	if (wnd.last_font) then
		wnd:update_font(unpack(wnd.last_font));
	end

-- propagate pixel density information
	if (disptbl) then
		wnd:displayhint(0, 0, wnd.dispmask, get_disptbl(wnd, disptbl));
	end

-- special handling, will be next selected
	if (tiler.deactivated and not tiler.deactivated.wnd) then
		tiler.deactivated.wnd = wnd;
	elseif (not tiler.deactivated) then
		tiler.deactivated = {
			wnd = wnd,
			mx = 0.5 * tiler.width,
			my = 0.5 * tiler.height
		};
	end

-- if the window masks another, move that one as well - assume that
-- the layouter will do the right thing
	if wnd.swallow_window then
		wnd.swallow_window:migrate(tiler, disptbl);
	end

	reattach_full(wnd, tiler.rtgt_id);

-- update
	dsp:resize();
	wnd:recovertag();
end

-- track suspend state with window so that we can indicate with
-- border color and make sure we don't send state changes needlessly
local function wnd_setsuspend(wnd, susp)
	if (susp == nil) then
		local state;
		if (wnd.suspended == true) then
			state = false;
		else
			state = true;
		end
		wnd_setsuspend(wnd, state);
		return;
	end

-- if it's a no-op (suspend+suspend) or there's no external target, leave
	if ((wnd.suspended and susp) or (not wnd.suspended and not susp) or
		not valid_vid(wnd.external, TYPE_FRAMESERVER)) then
		return;
	end

	local sel = (wnd.wm.selected == wnd);

	if (susp) then
		tiler_debug(wnd.wm, string.format("suspend:name=%s:state=true", wnd.name));
		suspend_target(wnd.external);
		wnd.suspended = true;
		shader_setup(wnd.border, "ui",
			wnd.space.mode == "float" and "border_float" or "border", "suspended");
		wnd.titlebar:switch_state("suspended", true);
	else
		tiler_debug(wnd.wm, string.format("suspend:name=%s:state=false", wnd.name));
		resume_target(wnd.external);
		wnd.suspended = nil;
		shader_setup(wnd.border, "ui", wnd.space.mode == "float"
			and "border_float" or "border", sel and "active" or "inactive");
		wnd.titlebar:switch_state(sel and "active" or "inactive");
	end
end

local function wnd_toback(wnd, step)
	if not wnd.space or #wnd.wm.windows == 1 then
		return;
	end

	local wm = wnd.wm;
	local wnd_i = table.find_i(wm.windows, wnd);
	if wnd_i then
		table.remove(wm.windows, wnd_i);
	end

-- step back logically within the same workspace to find insertion spot
	wnd_i = wnd_i > #wm.windows and #wm.windows or wnd_i
	local new_i = 1
	while wnd_i >= 1 and step and step > 0 do
		if wm.windows[wnd_i].space == wnd.space then
			step = step - 1
			new_i = wnd_i
		end
		wnd_i = wnd_i - 1
	end

-- activate the changes
	table.insert(wm.windows, new_i, wnd);
	wm:rebuild_order();

	if not wnd.selected then
		return
	end

-- change selection if needed
	for i=#wm.windows,1,-1 do
		if wm.windows[i].space == wnd.space then
			wm.windows[i]:select()
			break
		end
	end
end

local function wnd_tofront(wnd)
	if not wnd.space then
		return;
	end

	local wm = wnd.wm;
	local wnd_i = table.find_i(wm.windows, wnd);

	if (wnd_i) then
		table.remove(wm.windows, wnd_i);
	end
	table.insert(wm.windows, wnd);

	wm:rebuild_order();
end

local function wnd_titlebar(wnd, visible)
	if (wnd.show_titlebar == visible) then
		return;
	end

-- options not considered here is an 'undocked' titlebar that
-- is attached to the statusbar, this could be done as part of
-- marking the titlebar as invisible, and on wnd_select simply
-- set/attach the titlebar in the statusbar region although
-- with some size constraints.
	local h;
	if (not visible) then
		h = tbar_geth(wnd);
	end

	wnd.show_titlebar = visible;
	if (not visible) then
		h = -h;
	else
		h = tbar_geth(wnd);
	end

	local selected = wnd.wm.selected == wnd;
	if visible and wnd.wm.statusbar == wnd.titlebar then
		wnd.wm.statusbar:set_nested()
	elseif selected and not visible then
		wnd_titlebar_to_statusbar(wnd)
	end

	if (wnd.space.mode == "float") then
		wnd.height = wnd.height + h;
		wnd_size_decor(wnd, wnd.width, wnd.height, false);
--		wnd.space:resize();
	end

	wnd:resize(wnd.width, wnd.height, true, true);
end

local function wnd_border(wnd, visible, user_force, bw)
	bw = wnd:border_width();
	blend_image(wnd.border, visible and 1 or 0);

-- early out no-ops
	if (wnd.show_border == visible) then
		if wnd.border_w == bw then
			return;
		end
	end

-- change border size or visibility?
	local bdiff;
	if (visible == wnd.show_border) then
		bdiff = math.abs(wnd:border_width() - bw);
	else
		bdiff = (visible and 1 or -1) * wnd:border_width();
	end

-- apply difference to pad region while respecting possibly custom padding
	wnd.show_border = visible;

-- with float, we can simply grow/shrink and redraw the decor
	if (wnd.space.mode == "float") then
		wnd.width = wnd.width + bdiff;
		wnd.height = wnd.height + bdiff;
		wnd_size_decor(wnd, wnd.width, wnd.height, false);

-- for tile we need to actually resize a cascade of clients
	elseif (wnd.space.mode == "tile") then
		wnd:resize(wnd.width + bdiff, wnd.height + bdiff, true, true);
	end

-- and the other modes don't care about border
	wnd.space:resize();
end

-- move w1 from whatever parent and set as child or sibling to w2
-- within the same workspace
local function wnd_tochild(w1, w2, sibling)
	if (w1.space ~= w2.space) then
		return;
	end

	local wp1 = w1.parent;
	local wp1i = table.find_i(wp1.children, w1);
	table.remove(wp1.children, wp1i);

	if (sibling) then
		w1.parent = w2.parent;
		table.insert(w1.parent.children, w1);
	else
		table.insert(w2.children, w1);
		w1.parent = w2;
	end

	w1:recovertag();
end

-- swap the logical position of two windows within the same workspace,
-- moving to a different workspace requires other logic as the layouting
-- scheme may differ
local function wnd_swap(w1, w2, deep, force)
	if (w1 == w2 or (not force
		and w1.space.layouter and w1.space.layouter.block_swap)) then
		return;
	end

-- 1. weights, only makes sense in tile mode
	if (w1.space.mode == "tile") then
		local wg1 = w1.weight;
		local wg1v = w1.vweight;
		w1.weight = w2.weight;
		w1.vweight = w2.vweight;
		w2.weight = wg1;
		w2.vweight = wg1v;
	end

-- 2. parent->children entries
	local wp1 = w1.parent;
	local wp1i = table.find_i(wp1.children, w1);
	local wp2 = w2.parent;
	local wp2i = table.find_i(wp2.children, w2);

	wp1.children[wp1i] = w2;
	wp2.children[wp2i] = w1;

-- 3. parents
	w1.parent = wp2;
	w2.parent = wp1;

-- 4. question is if we want children to tag along or not
	if (not deep) then
		for i=1,#w1.children do
			w1.children[i].parent = w2;
		end
		for i=1,#w2.children do
			w2.children[i].parent = w1;
		end
		local wc = w1.children;
		w1.children = w2.children;
		w2.children = wc;
	end

	w1:recovertag();
	w2:recovertag();
end

-- based on the current mode, present a client size that would make sense
local function wnd_suggest_size(wnd)
	local space = wnd.space and wnd.space or active_display():active_space();
	local wm = wnd.wm

-- as with all space layouters, this should really be refactored and moved
-- into a separate file and move all operations to a pluggable workspace
-- mode setup rather than the ungodly mess this evolved into
	if space.mode == "tab" then
		local tbarh = math.ceil(gconfig_get("tbar_sz") * wm.scalef);
		return wm.effective_width, wm.effective_height - tbarh;

	elseif space.mode == "htab" then
		local tbarw = math.ceil(
			wm.effective_width * gconfig_get("htab_barw") * wm.scalef);
			return wm.effective_width - tbarw, wm.effective_height;

	elseif space.mode == "vtab" then
		local nw = #linearize(space)

		local tbarh = math.ceil(
			wm.effective_width * gconfig_get("tbar_sz") * wm.scalef);
			return wm.effective_width, wm.effective_height - nw * tbarh;

	elseif space.mode == "tile" then
-- Tile-mode is worse off as we need heuristics to figure out where it will
-- be attached (the suggest_size doesn't account for that), the current
-- insertion mode and so on. There is also no 'dry run' that would account
-- for window scaling modes and so on. It is very likely that the suggested
-- size will change almost immediately.

	elseif space.mode == "float" then
	end

	return wm.effective_width * 0.25, wm.effective_height * 0.25;
end

local function find_leaf(node, depth)
	if #node.children <= 1 then
		return node, depth
	end

	local min_node = node
	local min_depth = depth

	for _,v in ipairs(node.children) do
		local x, y = find_leaf(v, depth + 1)
		if min_depth == 0 or #min_node.children > 1 or y < min_depth then
			min_node = x
			min_depth = y
		end
	end

	return min_node, min_depth
end

-- attach a window to the active workspace, this is a one-time action
local function wnd_ws_attach(res, from_hook)
	local wm = res.wm;
-- attach to specific parent or 'swallow' (which is attach + hide)
	local as_child = gconfig_get("tile_insert_child") == "child" and res.attach_parent
	local dstindex = 1;

-- request to attach to parent, but this has a UAF risk should the parent
-- have died or not been completely setup at the time of the child arriving
	if (res.attach_parent) then
		if (not res.attach_parent.attach_time) then
			res.attach_parent = nil;
		else
			wm = res.attach_parent.wm;
		end
	end

-- hide the swallow target and absorb some of its properties in the hierarcy
	if (res.swallow_window and res.swallow_window.attach_time) then
		res.attach_parent = res.swallow_window.parent;
		res.swallow_window:hide();
		res.defer_x = res.swallow_window.x;
		res.defer_y = res.swallow_window.y;
		dstindex = res.swallow_window.space_ind;
		res.swallow_window.swallow_master = res;
		as_child = true;
		tiler_debug(wm, tiler_fmt("attach_swallow:x=%d:y=%d", res.defer_x, res.defer_y));

-- or attach as child to a specific window?
	elseif as_child then
		dstindex = res.attach_parent.space_ind;

-- or just use a default workspace (spawn target)
	else
		if wm.space_default_ind then
			dstindex = wm.space_default_ind;
		else
			dstindex = wm.space_ind;
		end
	end

-- very special windows can refuse attaching at all
	if (res.attach_block) then
		tiler_debug(wm, "attach_block:name=" .. res.name);
		return false;
	end

-- can be set either in the atype/, derived from tracetag during recover or
-- grabbed from the config- db per application
	if (res.default_workspace) then
		local dst = res.default_workspace;
-- absolute index
		if (type(dst) == "number") then
			dstindex = math.clamp(dst, 1, 10);

-- tag or relative (+1)
		elseif (type(dst) == "string") then
			if (string.sub(dst, 1, 1) == "+" or string.sub(dst, 1, 1) == "-") then
				local ind = tonumber(string.sub(dst, 2));
				if (ind) then
					dstindex = math.clamp(dstindex + ind, 1, 10);
				end
			else
				for i,v in ipairs(res.wm.spaces) do
					if (v.label and v.label == dst) then
						dstindex = i;
					end
				end
			end
		end

-- if we are tiled and the intended space is full based on cap, find a new
-- empty one and switch to it unless we also want to attach as child to a
-- current parent.
	elseif gconfig_get("tile_breadth_cap") > 0 and not as_child then
		local dspace = res.wm.spaces[dstindex]

		if dspace and dspace.mode == "tile" and
			#dspace.children >= gconfig_get("tile_breadth_cap") then
			local ci = dstindex + 1
			if ci > 10 then
				ci = 1
			end

-- sweep until all 10 have been checked, and if we couldn't find one, stick
-- with the current
			while ci ~= dstindex do
				if not res.wm.spaces[ci] or res.wm.spaces[ci].mode == "tile" and
					#res.wm.spaces[ci].children < gconfig_get("tile_breadth_cap") then
					res.wm:switch_ws(ci)
					dstindex = ci
					break
				end

				ci = ci + 1
				if ci > 10 then
					ci = 1
				end
			end
		end
	end

-- Can be intercepted by a hook handler that regulates placement but we avoid
-- it if we are attaching after recovery or if the window spawns in a
-- non-active workspace. A proper hook handler then re-runs attachment when it
-- has done its possible positioning and sizing - example of this is the
-- draw-to-spawn mode.
	if ((dstindex == wm.space_ind and not res.attach_temp)
		and wm.attach_hook and not from_hook) then
			tiler_debug(wm, "attach_hook:name=" .. res.name);
			return wm:attach_hook(res);
	end

	res.ws_attach = nil;
	res.attach_time = CLOCK;

-- this will only happen on assignment to non-active workspace
	if (wm.spaces[dstindex] == nil) then
		wm.spaces[dstindex] = create_workspace(wm);
		tiler_statusbar_update(wm);
	end

-- actual dimensions depend on the state of the workspace we'll attach,
-- which in turn can have complicated layouting etc. rules so first
-- attach.
	local space = wm.spaces[dstindex];
	res.space_ind = dstindex;
	res.space = space;
	link_image(res.anchor, space.anchor);
	space.last_action = CLOCK;

--	size_decor will override this anyhow
	tbh = tbar_geth(res);
	res.pad_top = res.pad_top + tbh;

-- this should be improved by allowing w/h/x/y overrides based on
-- history for the specific source or the class it belongs to, or a 'find
-- best fit'.
	if (space.mode == "float") then
		local props = image_storage_properties(res.canvas);
		res.width = props.width;
		res.height = props.height;
		if (res.defer_x) then
			res.x = res.defer_x;
			res.y = res.defer_y;
		else
			res.x, res.y = mouse_xy();
			res.x = math.clamp(res.x - res.pad_left - res.pad_right, 0);
			res.y = math.clamp(res.y - res.pad_top - res.pad_bottom, 0);
		end
		res.max_w = wm.effective_width;
		res.max_h = wm.effective_height;
		move_image(res.anchor, res.x, res.y);
	else
	end

-- same goes for hierarchical position, but here there are other controls
-- with the main ones being attachment workspace and originating parent,
-- but first, let an assigned layouter try (all modes should really be
-- implemented as a layouter though).
	local insert = space.layouter and space.layouter.added(space,res);
	local insert_parent = wm.selected;

-- default insertion policy
	if (not insert) then

		if as_child and res.attach_parent then
-- with 'swallowing' (one window that hides another) the two windows should
-- be next to each-other in the structure as well, so find the index of the
-- sibling
			local set = res.attach_parent.children
			local attach_point = #set+1

			if res.swallow_window then
				local ind = table.find_i(set, res.swallow_window)
				if ind then
					attach_point = ind + 1
				end
-- there might also be a need to attach left or right of a specific sibling
			elseif res.attach_left then
				local ind = table.find_i(set, res.attach_left)
				if ind then
					attach_point = ind
				end
			elseif res.attach_right then
				local ind = table.find_i(set, res.attach_right)
				if ind then
					attach_point = ind + 1
				end
			end

			table.insert(set, attach_point, res);
			res.parent = res.attach_parent;

-- redirect to custom space (crash recovery for instance)
		elseif (not insert_parent or wm.selected.space ~= space) then
			table.insert(space.children, res);
			res.parent = space;

-- no, use default insertion mode, pick a tree hierarchy regardless of workspace
-- layout mode, as a tree is typically useful - 'h' -> new as sibling to current
-- window, 'v' as child.
		elseif (space.insert == "h") then
			if (wm.selected.parent) then
				local ind = table.find_i(wm.selected.parent.children, wm.selected);
				table.insert(wm.selected.parent.children, ind+1, res);
				res.parent = wm.selected.parent;
			else
				table.insert(space.children, res, ind);
				res.parent = space;
			end

		elseif (space.insert == "bsp") then
			local leaf, depth = find_leaf(space, 0);
			table.insert(leaf.children, res);
			res.parent = leaf;

-- add as child to current
		else
			table.insert(wm.selected.children, res);
			res.parent = wm.selected;
		end
	end

	res.titlebar:switch_group(space.mode, true, space.mode ~= "float");

-- if we are attaching on the workspace that is currently selected, and
-- there is no selected window (and the space is not in fullscreen state)
-- then we should make the window visible immediately, otherwise that is
-- deferred until the space loses fullscreen
	if (wm.space_ind == dstindex and
		not(wm.selected and wm.selected.fullscreen)) then
		show_image(res.anchor);
		if (not insert) then
			res:select();
		end
		space:resize();
	else
		shader_setup(res.border, "ui",
			res.space.mode == "float" and "border_float" or "border", "suspended");
	end

-- trigger the resize cascade now that we know the layout..
	if (res.space.mode == "float") then
		local x, y = mouse_xy();
		if res.defer_x then
			x = res.defer_x
			y = res.defer_y
			res.defer_x = nil
			res.defer_y = nil
		end

		local w;
		local h;

		if (res.attach_temp) then
			x = res.attach_temp[1] * wm.effective_width;
			y = res.attach_temp[2] * wm.effective_height;
			w = res.attach_temp[3] * wm.effective_width;
			h = res.attach_temp[4] * wm.effective_height;
			res.attach_temp = nil;
		else
-- hint the clamp against the display
			w = math.clamp(res.wm.effective_width - x - res.wm.xoffset, 32, res.wm.xlimit);
			h = math.clamp(res.wm.effective_height - y - res.wm.yoffset, 32, res.wm.ylimit);
		end

		x = x - res.wm.xoffset;
		y = y - res.wm.yoffset;

		res.max_w = w;
		res.max_h = h;
		res:move(x, y, true, true, true);
		if (res.scalemode == "client") then
			res:displayhint(w, h);
		else
			res:resize(w, h, true);
		end
	end

-- add buttons to the titlebar
	local add_buttons =
	function(dst_group, list)
		for _,v in ipairs(list) do
			res:add_titlebar_button(v.direction, v.label, v.command, v.alt_command, dst_group);
		end
	end

-- we don't enumerate the table as there would be an iterator order problem
	add_buttons(nil, wm.buttons.all);
	add_buttons("float", wm.buttons.float);
	add_buttons("tile", wm.buttons.tile);

-- and merge the new titlebar into the statusbar if on the right workspace,
-- otherwise the merge-to-statusbar mode would indicate the wrong window
	if (wm.space_ind == dstindex) then
		wnd_titlebar_to_statusbar(res);

-- animate to indicate that a new window spawned on the workspace in question
-- (if the button and statusbar is visible that is), we do this simply by
-- drawing a short-lived color overlay
	else
		if wm.sbar_ws[dstindex] and valid_vid(wm.sbar_ws[dstindex].bg) then
			local props = image_surface_resolve(wm.sbar_ws[dstindex].bg);
			local wanim = gconfig_get("animation");
			if (props.opacity > 0 and wanim > 0) then
				local r,g,b = suppl_hexstr_to_rgb(HC_PALETTE[1]);
				local csurf = color_surface(props.width, props.height, r, g, b);
				move_image(csurf, props.x, props.y);
				order_image(csurf, props.order + 3);
				blend_image(csurf, 0.3, wanim * 0.5);
				blend_image(csurf, 0.0, wanim * 0.5);
				expire_image(csurf, wanim);
			end
		end
	end

	if res.adopt_window and res.adopt_window.reparent then
		res.adopt_window:reparent(res)
	end

	for k,v in ipairs(wm.on_wnd_create) do
		v(wm, res, space, space == wm:active_space());
	end

	tiler_debug(wm, "attach:name=" .. res.name);
	for k,v in pairs(space.listeners) do
		v(space, k, "attach", res);
	end

	return res;
end

-- name assignment is a bit iffy for external windows, so track and keep
-- on trying. optname is provided when a window wants to recover an old name,
-- which may be relevant for path- bindings.
--
local wnd_names = {};
local function get_window_name(wnd, optname)
	if (optname and not wnd_names[optname]) then
		wnd_names[optname] = true;
		wnd.name = optname;
		return wnd.name;
	end

	repeat
		wnd.name = "wnd_" .. tostring(ent_count) .. "_" .. tostring(CLOCK);
		ent_count = ent_count + 1;
	until wnd_names[wnd.name] == nil;
	wnd_names[wnd.name] = true;
	return wnd.name;
end

local function recover_restore(wnd)
	local str = image_tracetag(wnd.external);
	if (string.sub(str, 1, 6) ~= "durden") then
		return;
	end

	local entries = string.split(str, "\n\r");
	local res = {};
	for k,v in ipairs(entries) do
		local i = string.find(v, "=");
		if (i and i > 1) then
			res[string.sub(v, 1, i-1)] = string.sub(v, i+1);
		end
	end

	if (res["name"]) then
		get_window_name(wnd, res["name"]);
	end
	if (res["show_titlebar"]) then
		wnd.show_titlebar = true;
	end
	if (res["show_border"]) then
		wnd.show_border = true;
	end
	if (res["group_tag"]) then
		wnd.group_tag = res["group_tag"];
	end
	if (res["title"]) then
		wnd.title = res["title"];
	end
	if (res["prefix"]) then
		wnd.prefix = res["title"];
	end
	if (res["origo_ll"]) then
		wnd.origo_ll = true;
	end
	if (res["geom"]) then
		local vl = string.split(res["geom"], ":");
		if (#vl == 4) then
			wnd.attach_temp = {
				tonumber(vl[1]), tonumber(vl[2]),
				tonumber(vl[3]), tonumber(vl[4])
			};
		end
	end

-- this is a deferred attribute as recover clients can come in any order
	wnd.desired_parent = res["parent"];
	wnd:set_title();

-- for an adopted display we can only remember where home is and wait
	if res.ws_home and wnd.wm.name ~= res.ws_home then
		wnd.adopt_display = {
			home = res.ws_home,
			index = res.ws_home_ind,
			mode = res.ws_mode,
			label = res.ws_label
		};

-- otherwise try to reset the workspace as we remember it
	elseif (res.ws_ind and tonumber(res.ws_ind)) then
		local dw = math.clamp(tonumber(res.ws_ind), 1, 10);

		wnd.default_workspace = dw;
		local dspace = wnd.wm.spaces[dw];

		if (not dspace) then
			wnd.wm.spaces[dw] = create_workspace(wnd.wm, false);
			dspace = wnd.wm.spaces[dw];
		end

-- only restore mode if we are the first in a workspace
		local lst = linearize(dspace);
		if (#lst == 0) then
			if res.ws_mode then
				dspace.mode = res.ws_mode;
			end

			if res.ws_label then
				dspace:set_label(res.ws_label);
			end
		end
	end

	tiler_statusbar_update(wnd.wm);
end

-- Use the image_tracetag option to pack a string that can be used
-- to reassign the window to the correct position, weight, workspace,
-- layout mode and so on. The same tag can then be saved / stored with
-- an application guid to get settings persistance across reboots as well
local function wnd_recovertag(wnd, restore)
	if (not valid_vid(wnd.external)) then
		return;
	end

	if (restore) then
		recover_restore(wnd);
		return;
	end

	local recoverlst = {"durden"};

-- space- properties
	table.insert(recoverlst, string.format("ws_ind=%d", wnd.space_ind));
	table.insert(recoverlst, string.format("ws_mode=%s", wnd.space.mode));
	if (wnd.space.label) then
		table.insert(recoverlst, string.format("ws_label=%s", wnd.space.label));
	end
	if (wnd.space.home) then
		table.insert(recoverlst, string.format("ws_home=%s", wnd.space.home));
	end
	if (wnd.space.home_ind) then
		table.insert(recoverlst, string.format("ws_home_ind=%d", wnd.space.home_index));
	end

-- window- properties
	if (wnd.atype) then
		table.insert(recoverlst, string.format("atype=%s", wnd.atype));
	end

	table.insert(recoverlst, string.format("name=%s", wnd.name));

-- hierarchy
	if (string.sub(wnd.parent.name, 1, 3) == "wnd") then
		table.insert(recoverlst, string.format("parent=%s", wnd.parent.name));
		table.insert(recoverlst, string.format("weight=%f", wnd.weight));
		table.insert(recoverlst, string.format("vweight=%f", wnd.vweight));
	end

-- mode specific
	if (wnd.space.mode == "float") then
		local x = wnd.x / wnd.wm.effective_width;
		local y = wnd.y / wnd.wm.effective_height;
		local w = wnd.width / wnd.wm.effective_width;
		local h = wnd.height / wnd.wm.effective_height;
		table.insert(recoverlst, string.format("geom=%f:%f:%f:%f", x, y, w, h));
	end

	if (wnd.group_tag) then
		table.insert(recoverlst, string.format("group_tag=%s", wnd.group_tag));
	end

-- custom overrides / dynamic settings
	if (wnd.show_titlebar) then
		table.insert(recoverlst, "show_titlebar=1");
	end

	if (wnd.title) then
		table.insert(recoverlst, string.format("title=%s", wnd.title));
	end

	if (wnd.show_border) then
		table.insert(recoverlst, "show_border=1");
	end

	if (wnd.prefix) then
		table.insert(recoverlst, string.format("prefix=%s", wnd.prefix));
	end

	if (wnd.origo_ll) then
		table.insert(recoverlst, string.format("origo_ll=1"));
	end

-- missing restore:
-- custom bindings / translations
-- aural/visual junk (shader, scale, centered, gain)
-- workspace properties: background
--

-- flag this so the timer gets to update our k/v store
	if (wnd.config_tgt) then
		wnd.config_dirty = true;
	end

	local tag = table.concat(recoverlst, "\n\r");
	image_tracetag(wnd.external, tag);
end

local function wnd_inputtable(wnd, iotbl, multicast)
	if (wnd.hidden or not valid_vid(wnd.external, TYPE_FRAMESERVER)) then
		return;
	end

	target_input(wnd.external, iotbl);

	if (multicast or wnd.multicast) then
		for i,v in ipairs(wnd.children) do
			wnd_inputtable(v, iotbl, true);
		end
	end
	return true;
end

local function wnd_synch_overlays(wnd)
	for _,v in pairs(wnd.overlays) do
		local xofs = wnd.crop_values and wnd.crop_values[2] or 0;
		local yofs = wnd.crop_values and wnd.crop_values[1] or 0;

-- missing coordinate calculations for zoom etc.
		move_image(v.vid, v.xofs - xofs, v.yofs - yofs);

		if (v.stretch) then
			resize_image(v.vid, v.w, v.h);
		end
	end
end

local function wnd_add_overlay(wnd, key, vid, opts)
	if (not valid_vid(vid)) then
		return;
	end
	opts = opts and opts or {};

-- only one overlay per key
	if (wnd.overlays[key]) then
		delete_image(vid);
		return;
	end

-- link, shared order level between all overlays, force clipping
	link_image(vid, wnd.canvas);
	image_inherit_order(vid, true);
	order_image(vid, 1);

-- clipping is default, but opt out of it
	if not (opts.noclip) then
		image_clip_on(vid, CLIP_SHALLOW);
	end

-- opaque or blended
	if (opts.blend) then
		blend_image(vid, opts.blend, gconfig_get("wnd_animation"));
	else
		show_image(vid);
	end

-- three mouse input responses, custom handler, block out region,
-- let default canvas behavior apply
	if (opts.mouse_handler) then
		opts.mouse_handler.name = "overlay_mh";
		opts.mouse_handler.own = function(ctx, mvid) return mvid == vid; end;
		local lst = {};
		for k,v in pairs(opts.mouse_handler) do
			if (type(v) == "function" and k ~= "own") then
				table.insert(lst, k);
			end
		end
		mouse_addlistener(opts.mouse_handler, lst);
	elseif (opts.block_mouse) then
		image_mask_set(vid, MASK_UNPICKABLE);
	end

	local overent = {
		vid = vid,
		stretch = opts.stretch,
		xofs = opts.xofs and opts.xofs or 0,
		yofs = opts.yofs and opts.yofs or 0,
		w = opts.w and opts.w or 0,
		h = opts.h and opts.h or 0,
		mh = opts.mouse_handler,
		wnd = wnd,
		key = key,
		closure = opts.closure
	};

	tiler_debug(wnd.wm, tiler_fmt(
		"overlay_added:name=%s:key=%s:x=%.0f:y=%0.f:w=%0.f:h=%0.f",
		wnd.name, key, overent.xofs, overent.yofs, overent.w, overent.h));

	wnd.overlays[key] = overent;
	wnd:synch_overlays();
	return overent;
end

local function wnd_identstr(wnd)
	return wnd.name;
end

local function wnd_guid(wnd, guid)
	if (wnd.config_tgt or not guid or
		guid == "AAAAAAAAAAAAAAAAAAAAAA==") then
		return;
	end

	wnd.guid = guid;
	wnd.config_tgt = string.gsub(guid, "=", "_");
	local key = "durden_temp_" .. wnd.config_tgt;
	recover = get_key(key);
	if (recover) then
		store_key(key, "");
		image_tracetag(wnd.external, recover);
		wnd:recovertag(true);
	end
end

local function default_displayhint(wnd, hw, hh, dm, tbl, ...)
	if (not valid_vid(wnd.external, TYPE_FRAMESERVER)) then
		return;
	end

	if not tbl then
		tbl = get_disptbl(wnd, wnd.wm.disptbl);
	end

	hw = math.clamp(hw, 0, MAX_SURFACEW);
	hh = math.clamp(hh, 0, MAX_SURFACEH);
	if (hw > 0 and hh > 0) then
		if wnd.hint_w ~= hw or wnd.hint_h ~= hh then
			wnd.hint_ts = CLOCK;
		end
		wnd.hint_w = hw;
		wnd.hint_h = hh;
	end

	if (not dm) then
		dm = wnd.dispmask;
	end

-- so many important details to this that it's better to have a
-- mode where we track it and allow runtime inspection of it
	if (DEBUGLEVEL > 0) then
		if (not wnd.hint_history) then
			wnd.hint_history = {};
		end
		table.insert(wnd.hint_history, string.format(
			"(%d) %d * %d => %d * %d : %d", CLOCK,
			wnd.effective_w, wnd.effective_h, hw, hh, dm)
		);
		if (#wnd.hint_history > 4) then
			table.remove(wnd.hint_history, 1);
		end
	end

	tiler_debug(wnd.wm, string.format(
		"display_hint:name=%s:vid=%d:hint_w=%d:hint_h=%d:flags=%d",
		wnd.name, wnd.external, hw, hh, dm)
	);

	if (wnd.block_rz_hint) then
		tiler_debug(wnd.wm, string.format(
			"display_hint:name=%s:vid=%d:status=blocked", wnd.name, wnd.external));
	else
		target_displayhint(wnd.external, hw, hh, dm, tbl, ...);
	end
end

local function wnd_drop_overlay(wnd, key)
	if (not wnd.overlays[key]) then
		return;
	end

	if (wnd.overlays[key].mh) then
		mouse_droplistener(wnd.overlays[key].mh);
	end
	tiler_debug(wnd.wm,
		string.format("overlay_destroyed:name=%s:key=%s", wnd.name, key));

	delete_image(wnd.overlays[key].vid);

	local closure = wnd.overlays[key].closure;
	wnd.overlays[key] = nil;
	if closure then
		closure();
	end
end

local function wnd_set_drag_move(wnd)
	wnd.in_drag_move = wnd.space:linearize();
	wnd.in_drag_ts = CLOCK;
end

local function wnd_tbar_btn(wnd, dir, vsym, action, altaction, dst_group)
	local dir = dir and dir or "left";

	local outlbl = resolve_vsymbol(wnd.wm, vsym, tbh);
	wnd.titlebar:add_button(dir,
		"titlebar_iconbg", "titlebar_icon", outlbl,
		gconfig_get("sbar_tpad") * wnd.wm.scalef,
		wnd.wm.font_resfn, nil, nil,
		suppl_button_default_mh(wnd, action, altaction),
		{group = dst_group, alt = vsym}
	);
end

-- step content relatively (this should translate into seek
-- operations when we have contenthint set for server-side
-- seeking).
local function wnd_scroll(wnd, rel, dy, dx)
	if not valid_vid(wnd.external, TYPE_FRAMESERVER) then
		return;
	end

	if not wnd.got_scroll then
		target_seek(wnd.external, dy, rel, SEEK_SPACE, dx);
		tiler_debug(wnd.wm,	tiler_fmt("seek:%d:%d", dx, dy));
	else
		target_seek(wnd.esternal, dy, rel, SEEK_TIME, dx);
		tiler_debug(wnd.wm,	tiler_fmt("scroll:%d:%d", dx, dy));
	end
end

local function wnd_scroll_report(wnd, yprog, ysize, xprog, xsize)
	if not yprog then
		tiler_debug(wnd.wm, "scroll_state:disabled")
		wnd.got_scroll = nil
		run_event(wnd, "scroll_state", false);
		return;
	end

	wnd.got_scroll = {yprog, ysize, xprog, xsize}
--	tiler_debug(wnd.wm,
--		tiler_fmt("scroll:yprog=%f:ysize=%f:xprog=%f:xsize=%f",
--		yprog or 0, ysize or 0, xprog or 0, xsize or 0)
--	)
	run_event(wnd, "scroll_state", true, wnd.got_scroll);
end

local function wnd_cursortag(wnd, accept, src)
-- probe
	local valid_src_dst =
		wnd.stateinf ~= nil and src.stateinf ~= nil
		and wnd.stateinf.typeid == src.stateinf.typeid and
		valid_vid(src.external, TYPE_FRAMESERVER) and
		valid_vid(wnd.external, TYPE_FRAMESERVER)

	if accept == nil or not valid_src_dst then
		return valid_src_dst
	end

	if accept == false then
		return
	end

-- activate
	bond_target(src.external, wnd.external);
end

local function wnd_set_vtable_vattr(wnd)
	wnd.alert = wnd_alert
	wnd.show = wnd_show
	wnd.hide = wnd_hide
	wnd.set_message = wnd_message
	wnd.set_guid = wnd_guid
	wnd.set_title = wnd_title
	wnd.set_prefix = wnd_prefix
	wnd.set_tag = wnd_tag
	wnd.set_ident = wnd_ident
	wnd.set_titlebar = wnd_titlebar
	wnd.set_border = wnd_border
	wnd.set_dispmask = wnd_dispmask
	wnd.toggle_maximize = wnd_toggle_maximize
	wnd.to_front = wnd_tofront
	wnd.to_back = wnd_toback
	wnd.update_font = wnd_font
	wnd.resize = wnd_resize
	wnd.display_table = get_disptbl
	wnd.grow = wnd_grow
	wnd.set_crop = wnd_crop
	wnd.append_crop = wnd_crop_append
	wnd.identstr = wnd_identstr
	wnd.add_titlebar_button = wnd_tbar_btn
	wnd.iconify = wnd_iconify
end

local function wnd_set_vtable_hier(wnd)
	wnd.reposition = wnd_repos
	wnd.assign_ws = wnd_reassign
	wnd.select = wnd_select
	wnd.deselect = wnd_deselect
	wnd.next = wnd_next
	wnd.merge = wnd_merge
	wnd.collapse = wnd_collapse
	wnd.prev = wnd_prev
	wnd.move = wnd_move
	wnd.swap = wnd_swap
	wnd.reparent = wnd_tochild
	wnd.suggest_size = wnd_suggest_size
	wnd.drag_resize = wnd_drag_resize
	wnd.drag_resize_enter = wnd_drag_resize_enter
	wnd.drag_resize_leave = wnd_drag_resize_leave
	wnd.drop_overlay = wnd_drop_overlay
	wnd.add_overlay = wnd_add_overlay
	wnd.synch_overlays = wnd_synch_overlays
end

local function wnd_set_vtable_input(wnd)
	wnd.input_table = wnd_inputtable
	wnd.mousebutton = wnd_mousebutton
	wnd.mousemotion = wnd_mousemotion
	wnd.mouseactivate = wnd_mouseactivate
	wnd.mousepress = wnd_mousepress
	wnd.mousedblclick = wnd_mousedblclick
	wnd.mousehover = wnd_mousehover
	wnd.mouseover = wnd_mouseover
	wnd.scroll = wnd_scroll
	wnd.set_cursor = wnd_mousecursor
end

-- split up into multiples to avoid LuaJit bailing on too many upvalues
local function wnd_set_vtable(wnd)
	wnd_set_vtable_hier(wnd)
	wnd_set_vtable_vattr(wnd)
	wnd_set_vtable_input(wnd)

-- lifecycle
	wnd.set_suspend = wnd_setsuspend
	wnd.destroy = wnd_destroy
	wnd.get_name = wnd_getname
	wnd.add_handler = wnd_addhandler
	wnd.drop_handler = wnd_drophandler
	wnd.add_dispatch = wnd_add_dispatch
	wnd.drop_dispatch = wnd_drop_dispatch
	wnd.migrate = wnd_migrate
	wnd.resize_effective = wnd_effective_resize
	wnd.recovertag = wnd_recovertag

-- special windows
	wnd.add_popup = wnd_popup
	wnd.drop_popup = wnd_droppopup

-- function hooks
	wnd.displayhint = default_displayhint
	wnd.displaytable = get_disptbl
end

function wnd_set_vitable(wnd)
-- input
	wnd.input_table = wnd_inputtable
	wnd.mousebutton = wnd_mousebutton
	wnd.mousemotion = wnd_mousemotion
	wnd.mouseactivate = wnd_mouseactivate
	wnd.mousepress = wnd_mousepress
	wnd.mousedblclick = wnd_mousedblclick
	wnd.mousehover = wnd_mousehover
	wnd.mouseover = wnd_mouseover
	wnd.scroll_report = wnd_scroll_report
	wnd.scroll = wnd_scroll
	wnd.receive_cursortag = wnd_cursortag
end

-- build an orphaned window that isn't connected to a real workspace yet,
-- but with all the expected members setup-up and in place. This means that
-- some operations will be no-ops and the window will not appear in normal
-- iterators.
local wnd_setup = function(wm, source, opts)
	if (opts == nil) then opts = {}; end
	local bw = gconfig_get("borderw");

-- burn a slot for external storages so we get .external != .canvas for easier
-- detach or filter actions that rely on indirection
	local nsrf = nil;
	local extvid = nil;
	if (valid_vid(source, TYPE_FRAMESERVER)) then
		local nsrf = null_surface(32, 32);
		image_sharestorage(source, nsrf);
		extvid = source;
		source = nsrf;
	end

	local res = {
		wm = wm,
		anchor = null_surface(1, 1),
-- we use fill surfaces rather than color surfaces to get texture coordinates
		border = color_surface(1, 1, unpack(gconfig_get("border_color"))),
		canvas = source,
		external = extvid,
		gain = 1.0 * gconfig_get("global_gain"),
		popups = {},

-- hierarchies used for tile layout
		children = {},

-- overlay surfaces drawn on top of the canvas, linked to its position,
-- lifecycle, clipped to its size and likely blended etc.
		overlays = {},

-- specific event / keysym bindings
		labels = {},
		bindings = {},
		dispatch = {},
		u8_translation = {},

-- register:able event handlers to relate one window to another
		handlers = {
			destroy = {},
			register = {},
			resize = {},
			move = {},
			select = {},
			deselect = {},
			mouse_motion = {},
			mouse_button = {},
			mouse = {},
			frame = {},
			scroll_state = {},
		},
		run_event = run_event,

-- padding is split into a custom [variable] and a border- area [calculated]
-- based on which decorations are available and so on. The pad_[lrtd] are the
-- resolved values and will be updated when decorations are rebuilt etc.
		pad_left = bw,
		pad_right = bw,
		pad_top = bw,
		pad_bottom = bw,

-- note on multi-PPCM:
-- scale factor is manipulated by the display manager in order to take pixel
-- density into account, so when a window is migrated or similar -- scale
-- factor may well change. Sizes are primarily defined relative to self or
-- active default font size though, and display manager changes font-size
-- during migration and display setup.

-- properties that change visual behavior
		dispmask = 0,

-- though the active values are defined by the anchor and canvas, these
-- values are used for tracking / budgets in the current layout mode
		effective_w = 0,
		effective_h = 0,
		max_w = wm.effective_width,
		max_h = wm.effective_height,
		x = 0,
		y = 0,

-- local adjustements based on subposition (centered = true, wnd_reposition)
		ofs_x = 0,
		ofs_y = 0,
		centered = true,
		scalemode = opts.scalemode and opts.scalemode or "normal",
		default_workspace = opts.default_workspace,
		attach_parent = opts.attach_parent,
		attach_left = opts.attach_left,
		attach_right = opts.attach_right,
		adopt_window = opts.adopt_window,
		swallow_window = opts.swallow_window,

-- external displayhint offsets to mask cropping actions
		dh_pad_w = 0,
		dh_pad_h = 0,
		dh_ts = 0,

-- weights used for balancing tile tree
		weight = 1.0,
		vweight = 1.0,

-- custom color overrides
		color_table = {},

-- decoration controls
		cursor = "default",
		show_titlebar = not gconfig_get("hide_titlebar"),
		show_border = true,
		indirect_parent = nil,
		border_width = wnd_border_width,
	};

-- default mouse position to center
	res.mouse = {0.5, 0.5};
	wnd_set_vtable(res);
	wnd_set_vitable(res);

-- this can be overridden / broken due to window restoration
	tiler_latest_window_name(get_window_name(res));

	res.title_text = "(no title)"
	res.width = opts.width and opts.width or wm.min_width;
	res.height = opts.height and opts.height or wm.min_height;
	res.want_shadow =
		(not opts.block_shadow) and gconfig_get("shadow_style") ~= "none";

	if opts.external_prot then
		res.external_prot = opts.external_prot;
	end

	if (opts.show_titlebar ~= nil) then
		res.show_titlebar = opts.show_titlebar;
	end

	if (opts.show_border ~= nil) then
		res.show_border = opts.show_border;
	end

-- for float mode
	res.defer_x, res.defer_y = mouse_xy();

	image_tracetag(res.anchor, "wnd_anchor");
	image_tracetag(res.border, "wnd_border");
	image_tracetag(res.canvas, "wnd_canvas");

	image_inherit_order(res.anchor, true);
	image_inherit_order(res.border, true);
	image_inherit_order(res.canvas, true);

	link_image(res.canvas, res.anchor);
	link_image(res.border, res.anchor);

	image_mask_set(res.anchor, MASK_UNPICKABLE);

-- create the titlebar even though it might not be 'used'
	local tbh = math.floor(wm.scalef * gconfig_get("tbar_sz"));
	res.titlebar = uiprim_bar(res.anchor, ANCHOR_UL,
		res.width - 2 * bw, tbh, "titlebar",
		mouse_handler_factory.titlebar(res),
		"tbar"
	);

	res.titlebar.tag = res;
	res.titlebar:move(bw, bw);

-- start the titlebar as hidden immediately
	if (not res.show_titlebar) then
		res.titlebar:hide();
	end

	res.titlebar:add_button("center", nil, "titlebar_text",
		" ", gconfig_get("sbar_tpad") * wm.scalef, res.wm.font_resfn);
	res:set_title("");

-- order canvas so that it comes on top of the border for mouse events
-- this is pending a rewrite of the border management that splits it out
-- into separate surfaces instead
	order_image(res.canvas, 2);

-- mark titlebar etc. as 'inactive', a later call to :select will change that
	res.titlebar:switch_state("inactive", true);
	shader_setup(res.border, "ui", "border", "inactive");
	show_image({res.border, res.canvas});

-- attach the window related mouse handlers (tiler_mh.lua)
	res.handlers.mouse.border = mouse_handler_factory.border(res);
	res.handlers.mouse.canvas = mouse_handler_factory.canvas(res);
	res.block_mouse = opts.block_mouse;

-- the window has been created, but it is not yet 'attached' to a workspace
-- so a number of window management functions will be unavailable still
	res.ws_attach = wnd_ws_attach;
	res.set_drag_move = wnd_set_drag_move;

-- load / override settings with whatever is in tag-memory
	res:recovertag(true);

	tiler_debug(wm, tiler_fmt(
		"create:name=%s:w=%d:h=%d:titlebar=%s:border=%s:parent=%s",
		res.name, res.width, res.height,
		tostring(res.show_titlebar), tostring(res.show_border),
		res.attach_parent and res.attach_parent.name or "none"
	));

	return res;
end

local function wnd_create(wm, source, opts)
	local res = wnd_setup(wm, source, opts);
	if (res) then
		res:ws_attach();
	end
	return res;
end

local function tick_windows(wm)
	for k,v in ipairs(wm.windows) do
		if (v.tick) then
			v:tick();
		end
	end
	wm.statusbar:tick();
end

local function tiler_find(wm, source)
	for i=1,#wm.windows do
		if (wm.windows[i].canvas == source) then
			return wm.windows[i];
		end
	end
	return nil;
end

local function tiler_switchws(wm, ind)
	if (type(ind) ~= "number") then
		for k,v in pairs(wm.spaces) do
			if (type(ind) == "table" and v == ind) then
				ind = k;
				break;
			elseif (type(ind) == "string" and v.label == ind) then
				ind = k;
				break;
			end
		end
-- no match
		if (type(ind) ~= "number") then
			return;
		end
	end

-- don't switch if we're already selected
	local cw = wm.selected;
	if (ind == wm.space_ind) then
		return;
	end

	local nd = wm.space_ind < ind;
	local cursp = wm.spaces[wm.space_ind];

	if (not wm.spaces[ind]) then
		wm.spaces[ind] = create_workspace(wm, false);
	end

	local nextsp = wm.spaces[ind];

-- workaround for autodelete on workspace triggers are an edge condition when the
-- backgrounds are the same and should not be faded but when activate_ comes the
-- ws is already dead so we need an intermediate
	local oldbg = nil;
	local nextbg = nextsp.background and nextsp.background or wm.background_id;
	if (valid_vid(nextsp.background) and valid_vid(cursp.background)) then
		oldbg = null_surface(1, 1);
		image_sharestorage(cursp.background, oldbg);
	end

	if (cursp.switch_hook) then
		cursp:switch_hook(false, nd, nextbg, oldbg);
	else
		workspace_deactivate(cursp, false, nd, nextbg);
	end
-- policy, don't autodelete if the user has made some kind of customization
	if (#cursp.children == 0 and gconfig_get("ws_autodestroy") and
		(cursp.label == nil or string.len(cursp.label) == 0 ) and
		(cursp.background_name == nil or cursp.background_name == wm.background_name)) then
		cursp:destroy();

		wm.sbar_ws[wm.space_ind].last_lbl = nil;
		wm.spaces[wm.space_ind] = nil;
		wm.sbar_ws[wm.space_ind]:hide();
	else
		cursp.selected = cw;
	end

	wm.sbar_ws[wm.space_ind]:switch_state("inactive");
	wm.sbar_ws[ind]:show();
	wm.sbar_ws[ind]:switch_state("active");
	if (wm.space_last_ind ~= wm.space_ind) then
		wm.space_last_ind = wm.space_ind;
	end
	wm.space_ind = ind;

	if (nextsp.switch_hook) then
		nextsp:switch_hook(true, not nd, nextbg, oldbg);
	else
		workspace_activate(nextsp, false, not nd, oldbg);
	end

	if (valid_vid(oldbg)) then
		delete_image(oldbg);
	end
-- safeguard against broken state
	nextsp.selected = nextsp.selected and
		nextsp.selected or nextsp.children[1];

-- undo nesting as it might not apply for the next selected
	wm.statusbar:set_nested();
	if (nextsp.selected) then
		wnd_select(nextsp.selected);
	else
		wm.selected = nil;
	end

	tiler_statusbar_update(wm);
end

local function tiler_stepws(wm, dir)
	local cur = wm.space_ind + dir;
	dir = dir < -1 and -1 or dir;
	dir = dir >  1 and  1 or dir;

	repeat
		cur = cur <= 0 and 10 or cur;
		cur = cur >= 9 and 1 or cur;
		if (wm.spaces[cur] ~= nil) then
			wm:switch_ws(cur);
			return;
		end
		cur = cur + dir;
	until cur == wm.space_ind;
end

local function tiler_swapws(wm, ind2)
	local ind1 = wm.space_ind;

	if (ind2 == ind1) then
		return;
	end
  tiler_switchws(wm, ind2);
-- now space_ind is ind2 and ind2 is visible and hooks have been run
	local space = wm.spaces[ind2];
	wm.spaces[ind2] = wm.spaces[ind1];
 	wm.spaces[ind1] = space;
	wm.space_ind = ind1;

 -- now the swap is done with, need to update bar again
	if (valid_vid(wm.spaces[ind1].label_id)) then
		mouse_droplistener(wm.spaces[ind1].tile_ml);
		delete_image(wm.spaces[ind1].label_id);
		wm.spaces[ind1].label_id = nil;
	end

	if (valid_vid(wm.spaces[ind2].label_id)) then
		mouse_droplistener(wm.spaces[ind1].tile_m2);
		delete_image(wm.spaces[ind2].label_id);
		wm.spaces[ind2].label_id = nil;
	end

	wm:tile_update();
end

local function tiler_swapup(wm, deep, resel)
	local wnd = wm.selected;
	if (not wnd or wnd.parent.parent == nil) then
		return;
	end

	local p1 = wnd.parent;
	wnd_swap(wnd, wnd.parent, deep);
	if (resel) then
		p1:select();
	end

	if (wnd.space) then
		wnd.space:resize();
	end
end

local function tiler_swapdown(wm, resel)
	local wnd = wm.selected;
	if (not wnd or #wnd.children == 0) then
		return;
	end

	local pl = wnd.children[1];
	wnd_swap(wnd, wnd.children[1]);
	if (resel) then
		pl:select();
	end

	if (wnd.space) then
		wnd.space:resize();
	end
end

local function swap_wnd(wm, deep, resel, step)
	local wnd = wm.selected;
	if (not wnd or not wnd.space) then
		return;
	end

	local try_level = function(node, step)
		local ind = table.find_i(node.parent.children, node);
		if (ind + step <= 0 or ind + step > #node.parent.children) then
			return nil;
		else
			return node.parent.children[ind + step];
		end
	end

	local dst = wnd;
	local next_wnd = try_level(dst, step);
	while (next_wnd == nil) do
		 dst = dst.parent;
		if (not dst.parent) then
			return;
		end
		next_wnd = try_level(dst, step);
	end

	wnd_swap(wnd, next_wnd, deep);
	if (resel) then
		next_wnd:select();
	end
	wnd.space:resize();
end

local function tiler_swapleft(wm, deep, resel)
	swap_wnd(wm, deep, resel, -1);
end

local function tiler_swapright(wm, deep, resel)
	swap_wnd(wm, deep, resel, 1);
end

local function tiler_message(tiler, msg, timeout)
	local msgvid;
	if (timeout ~= -1) then
		timeout = gconfig_get("msg_timeout");
	end

	tiler.sbar_ws["msg"]:update(msg == nil and "" or msg, timeout);
end

local function tiler_rebuild_border(tiler)
	local bw = gconfig_get("borderw");
	local tw = bw - gconfig_get("bordert");
-- weight, vweight
	local s = {"active", "inactive", "alert", "default"};
	shader_update_uniform("border", "ui", "border", bw, s, "tiler-rebuild");
	shader_update_uniform("border", "ui", "thickness", tw, s, "tiler-rebuild");
	shader_update_uniform("border_float",
		"ui", "border", gconfig_get("borderw_float"), s, "tiler-rebuild");
	shader_update_uniform("border_float", "ui", "thickness",
		gconfig_get("borderw_float") - gconfig_get("bordert_float"), s, "tiler-rebuild");

	for i,v in ipairs(tiler.windows) do
		wnd_size_decor(v, v.width, v.height, false);
	end
end

local function tiler_rendertarget(wm, set)
	if (set == nil or (wm.rtgt_id and set) or (not set and not wm.rtgt_id)) then
		return wm.rtgt_id;
	end

	local list = get_hier(wm.anchor);

-- the surface we use as rendertarget for compositioning will use the highest
-- quality internal storage format, and disable the use of the alpha channel
	if (set == true) then
		local quality = ALLOC_QUALITY_NORMAL;
		wm.rtgt_id = alloc_surface(wm.width, wm.height, true, quality);
		image_tracetag(wm.rtgt_id, "tiler_rt" .. wm.name);
		local pitem = null_surface(32, 32); --workaround for rtgt restriction
		image_tracetag(pitem, "rendertarget_placeholder");
		define_rendertarget(wm.rtgt_id, {pitem});
		for i,v in ipairs(list) do
			rendertarget_attach(wm.rtgt_id, v, RENDERTARGET_DETACH);
		end
		local colors = gconfig_get("display_color");
		image_color(wm.rtgt_id, colors[1], colors[2], colors[3]);
	else
		for i,v in ipairs(list) do
			rendertarget_attach(WORLDID, v, RENDERTARGET_DETACH);
		end
		delete_image(rt);
		wm.rtgt_id = nil;
	end
	image_texfilter(wm.rtgt_id, FILTER_NONE);
	return wm.rtgt_id;
end

local function tiler_activespace(wm)
	assert(wm.spaces[wm.space_ind]);
	return wm.spaces[wm.space_ind];
end

local function tiler_countspaces(wm)
	local r = 0;
	for i=1,10 do
		r = r + (wm.spaces[i] ~= nil and 1 or 0);
	end
	return r;
end

-- for floating mode, if we receive input with no window selection,
-- absorb and forward to someone else.
-- inputh prototype: wm, iotbl
local function tiler_fallthrough_input(wm, inputh)
	if (inputh) then
		wm.fallthrough_ioh = inputh;
	else
		wm.fallthrough_ioh = nil;
	end
end

local function tiler_input_lock(wm, dst, source)
	local ret = wm.input_lock

	if (dst) then
		tiler_logfun("input locked to " .. (source and source or "unknown"));
		wm.input_lock = function(...)
			timer_reset_idle();
			dst(...);
		end
		return ret
	else
		tiler_logfun("input locked released")
		wm.input_lock = nil;
	end
end

local function tiler_resize(wm, neww, newh, norz, rotated)
-- special treatment for workspaces with float, we "fake" drop/set float
	for i=1,10 do
		if (wm.spaces[i] and wm.spaces[i].mode == "float") then
			drop_float(wm.spaces[i]);
		end
	end

-- empty resize call is just an invalidation, so map back the old size
	if (not neww or not newh) then
		neww = wm.width;
		newh = wm.height;
	end

	wm.width = neww;
	wm.height = newh;
	wm.rotated = rotated;
	resize_image(wm.anchor, neww, newh);

	if (valid_vid(wm.rtgt_id)) then
		tiler_debug(wm,
			tiler_fmt("resize_backing:width=%d:height=%d", neww, newh))
		image_resize_storage(wm.rtgt_id, neww, newh);
	end

	for i=1,10 do
		if (wm.spaces[i] and wm.spaces[i].mode == "float") then
			set_float(wm.spaces[i]);
		end
	end

	if (not norz) then
		for k,v in pairs(wm.spaces) do
			v:resize(neww, newh);
		end
	end

	for k,v in ipairs(wm.on_tiler_resize) do
		v(v, neww, newh);
	end

	tiler_statusbar_update(wm);
end

-- drop whatever interactive/cursor state that is currently pending
local function tiler_cancellation(wm, accept)
	local ct = mouse_state().cursortag
	if not ct then
		return
	end

	if not accept or not ct.handler or
		not ct.handler(wm.selected, true, ct.src, ct) then
		mouse_cursortag_state(false);
	else
		mouse_cursortag_state(true);
		ct.src.in_drag_tag = false;
	end

	mouse_cursortag_drop();
end

local function tiler_activate(wm)
	if (wm.deactivated) then
		local deact = wm.deactivated;
		wm.deactivated = nil;
		mouse_absinput_masked(deact.mx, deact.my, true);
		if (deact.wnd and deact.wnd.select) then
			deact.wnd:select();
		end
	end
end

-- could've just had the external party call deselect,
-- but hook may be useful for later so keep like this
local function tiler_deactivate(wm)
	local mx, my = mouse_xy();
	wm.deactivated = {
		mx = mx, my = my,
		wnd = wm.selected
	}
	if (wm.selected) then
		wm.selected:deselect(true);
	end
end

-- this is the wrong way to do it now that rendertargets actually support
-- setting an output density and rerastering accordingly, refactor when
-- time permits. Then we can simply return an empty string here.
local function recalc_fsz(wm)
	local fsz = gconfig_get("font_sz") * wm.scalef - gconfig_get("font_sz");
	local int, fract = math.modf(fsz);
	int = int + ((fract > 0.75) and 1 or 0);
	if (int ~= int or int == 0/0 or int == -1/0 or int == 1/0) then
		int = 0;
	end

	wm.font_deltav = int;
	wm.font_delta = "\\f," .. tostring(gconfig_get("font_sz") + int);
end

-- the tiler is now on a display with a new scale factor, this means redoing
-- everything from decorations to rendered text which will cascade to different
-- window sizes etc.
local function tiler_scalef(wm, newf, disptbl)
	wm.scalef = newf;

	if (disptbl) then
		for k,v in pairs(disptbl) do
			wm.disptbl[k] = v;
		end
	end

-- this will re-recreate some parts of the statusbar, and thus we need to be
-- sure that new items gets attached to the right rendertarget
	recalc_fsz(wm);
	wm:rebuild_border();
	wm:rebuild_statusbar_custom(wm.sbar_custom);

	tiler_debug(wm, tiler_fmt(
		"scale:new=%f:ppcm=%f:font_sz=%d",
		newf, (disptbl and disptbl.ppcm and disptbl.ppcm) or VPPCM,
		wm.font_deltav
	));

	for k,v in ipairs(wm.windows) do
		v:set_title();
		if (disptbl) then
			v:displayhint(0, 0, v.dispmask, get_disptbl(v, disptbl));
		end
	end

-- wm resize will also rebuild the statusbar
	local old_attach = set_context_attachment;
	set_context_attachment = function(id)
		return old_attach(id);
	end
	wm:resize(wm.width, wm.height);
	set_context_attachment = old_attach;

-- [removed, kept as a note]
-- easier doing things like this than fixing the other dimensioning edgecases
--	wm.statusbar:destroy();
-- this broke custom buttons and buttons from other origins

-- mouse locking coordinates depend on active rt
	if (active_display() == wm) then
		mouse_querytarget(wm.rtgt_id);
	end

end

local function tiler_fontres(wm)
	return wm.font_delta, wm.scalef * gconfig_get("sbar_tpad");
end

local function tiler_switchbg(wm, newbg, mh)
	wm.background_name = newbg;

	if (valid_vid(wm.background_id)) then
		blend_image(wm.background_id, 0.0, gconfig_get("transition"));
		expire_image(wm.background_id, gconfig_get("transition"));
		wm.background_id = nil;
	end

-- we need this synchronously unfortunately
	if (type(newbg) == "string") then
		local ln, kind = resource(newbg);
		if (kind ~= "file") then
			return;
		end
		wm.background_id = load_image(newbg);
	elseif (valid_vid(newbg)) then
		wm.background_id = null_surface(wm.width, wm.height);
		image_sharestorage(newbg, wm.background_id);
	end

-- update for all existing spaces that uses this already
	for k,v in pairs(wm.spaces) do
		if (v.background == nil or v.background_name == wm.background_name) then
			v:set_background(wm.background_name);
		end
	end
end

local counter = 0;
local create_listeners = {};
function tiler_create_listener(handler)
	table.insert(create_listeners, handler);
end

local function on_display_event(event, name, tiler, id)
	for disp in all_tilers_iter() do
		if disp.tile_update then
			disp:tile_update();
		end
	end
end

local function tiler_shutdown(tiler)
	for i=0,10 do
		if tiler.spaces[i] then
			tiler.spaces[i]:save()
		end
	end

	local keys = {};
	local prefix = "tiler_" .. tiler.name;
	keys[prefix .. "_sel"] = tiler.space_ind;
	store_key(keys);
end

local function tiler_reorder(wm)
	for i=1,#wm.windows do
		order_image(wm.windows[i].anchor, i * WND_RESERVED);
	end

	order_image(wm.order_anchor, #wm.windows * 2 * WND_RESERVED);
end

function tiler_create(width, height, opts)
	opts = opts == nil and {} or opts;
	counter = counter + 1;

	local res = {
-- null surfaces for clipping / moving / drawing
		name = opts.name and opts.name or tostring(counter),
		anchor = null_surface(1, 1),
		order_anchor = null_surface(1, 1),
		empty_space = workspace_empty,
		lbar = tiler_lbar,
		tick = tick_windows,

-- for multi-DPI handling
		font_delta = "\\f,+0",
		font_deltav = 0,
		scalef = opts.scalef and opts.scalef or 1.0,
		disptbl = opts.disptbl and opts.disptbl or {ppcm = VPPCM},

-- management members
		spaces = {},
		windows = {},
		space_ind = 1,

-- added to the titlebar ui-prim on window creation
		buttons = {
			all = {},
			float = {},
			tile = {}
		},

-- public functions
		set_background = tiler_switchbg,
		step_ws = tiler_stepws,
		switch_ws = tiler_switchws,
		swap_ws = tiler_swapws,
		swap_up = tiler_swapup,
		swap_down = tiler_swapdown,
		swap_left = tiler_swapleft,
		swap_right = tiler_swapright,
		active_space = tiler_activespace,
		active_spaces = tiler_countspaces,
		activate = tiler_activate,
		deactivate = tiler_deactivate,
		set_rendertarget = tiler_rendertarget,
		add_window = wnd_create,
		add_hidden_window = wnd_setup,
		find_window = tiler_find,
		message = tiler_message,
		resize = tiler_resize,
		tile_update = tiler_statusbar_update,
		rebuild_statusbar_custom = tiler_statusbar_custom,
		rebuild_border = tiler_rebuild_border,
		set_input_lock = tiler_input_lock,
		update_scalef = tiler_scalef,
		fallthrough_input = tiler_fallthrough_input,
		cancellation = tiler_cancellation,
		convert_mouse_xy = tiler_convert_mousexy,
		shutdown = tiler_shutdown,
		rebuild_order = tiler_reorder,

-- indirection to allow dynamic buttons to move to a separate tray
		get_dock =
		function(self)
			return self.statusbar;
		end,

-- shared event handlers, primarily for effects and layouting
		on_wnd_create = {},
		on_wnd_destroy = {},
		on_wnd_drag = {},
		on_wnd_hide = {},
		on_wnd_select = {},
		on_wnd_title = {},
		on_tiler_resize = {},

-- unique event handlers
		on_preview_step = function() end
	};

	res.sbar_custom = opts.sbar_custom;
	res.font_resfn = function() return tiler_fontres(res); end
	res.height = height;
	res.width = width;
	res.effective_width = width;
	res.effective_height = height;

-- statusbar may affect the drag/layout/...
	res.yoffset = 0;
	res.xoffset = 0;
	res.ylimit = height;
	res.xlimit = width;

-- to help with y positioning when we have large subscript,
-- this is manually probed during font-load
	recalc_fsz(res);
	tiler_statusbar_build(res);

	res.min_width = 32;
	res.min_height = 32;
	image_tracetag(res.anchor, "tiler_anchor");
	image_tracetag(res.order_anchor, "tiler_order_anchor");
	image_mask_clear(res.order_anchor, MASK_POSITION);

	order_image(res.order_anchor, 2);
	show_image({res.anchor, res.order_anchor});
	link_image(res.order_anchor, res.anchor);

-- unpack preset workspaces from saved keys
	local mask = string.format("wsk_%s_%%", res.name);
	local wstbl = {};
	for i,v in ipairs(match_keys(mask)) do
		local pos, stop = string.find(v, "=", 1);
		local key = string.sub(v, 1, pos-1);
		local ind, cmd = string.match(key, "(%d+)_(%a+)$");
		if (ind ~= nil and cmd ~= nil) then
			ind = tonumber(ind);
			if (wstbl[ind] == nil) then wstbl[ind] = {}; end
			local val = string.sub(v, pos+1);
			wstbl[ind][cmd] = val;
		end
	end

	for k,v in pairs(wstbl) do
		res.spaces[k] = {};
		res.spaces[k] = create_workspace(res, true);
		for ind, val in pairs(v) do
			if (ind == "mode") then
				res.spaces[k].mode = val;
			elseif (ind == "insert") then
				res.spaces[k].insert = val;
			elseif (ind == "bg") then
				res.spaces[k]:set_background(val);
			elseif (ind == "label") then
				res.spaces[k]:set_label(val);
			end
		end
	end

-- always make sure we have a 'first one'
	if (not res.spaces[1]) then
		res.spaces[1] = create_workspace(res, true);
	end

	res:tile_update();

	for _,v in ipairs(create_listeners) do
		v(res);
	end

-- only need one as it will rebuild on all tilers
	if not got_display_listener then
		display_add_listener(on_display_event)
		got_display_listener = true;
	end

-- with the tiler created, see if there are any persistence options to restore
--

	return res;
end

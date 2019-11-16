--
-- This translation unit returns factory functions for the possible decoration
-- mouse handlers, as well as the default implementation for mouse events that
-- are attached to a window on creation.
--
local tiler_logfun = suppl_add_logfn("wm");
local function tiler_debug(wm, msg)
	msg = msg and msg or "bad message";
	tiler_logfun(wm.name .. ":" .. msg);
end

local function dist(x, y)
	return math.sqrt(x * x + y * y);
end

-- map rectangle edge to mouse-cursor direction and name
local dir_lut = {
	ul = {"rz_diag_r", {-1, -1, 1, 1}},
	 u = {"rz_up", {0, -1, 0, 1}},
	ur = {"rz_diag_l", {1, -1, 0, 1}},
	 r = {"rz_right", {1, 0, 0, 0}},
	lr = {"rz_diag_r", {1, 1, 0, 0}},
	 d = {"rz_down", {0, 1, 0, 0}},
	ll = {"rz_diag_l", {-1, 1, 1, 0}},
	 l = {"rz_left", {-1, 0, 1, 0}}
};

-- display- local coordinate to window border conversion
-- returns a matching string/key from dir_lut
local function mouse_to_border(wnd)
	local x, y = mouse_xy();
	local props = image_surface_resolve(wnd.anchor);

-- hi-clamp radius, select corner by distance (priority)
	local cd_ul = dist(x-props.x, y-props.y);
	local cd_ur = dist(props.x + props.width - x, y - props.y);
	local cd_ll = dist(x-props.x, props.y + props.height - y);
	local cd_lr = dist(props.x + props.width - x, props.y + props.height - y);

	local lim = 32;
	if (cd_ur < lim) then
		return "ur";
	elseif (cd_lr < lim) then
		return "lr";
	elseif (cd_ll < lim) then
		return "ll";
	elseif (cd_ul < lim) then
		return "ul";
	end

	local dle = x-props.x;
	local dre = props.x+props.width-x;
	local due = y-props.y;
	local dde = props.y+props.height-y;

	local dx = dle < dre and dle or dre;
	local dy = due < dde and due or dde;

-- for aspect ratio scaling, we practically only have the diagonals
	if (wnd.scalemode == "aspect") then
		if (dx < dy) then
			if (dle < dre) then
				return due < 0.5 * props.height and "ul" or "ll";
			else
				return due < 0.5 * props.height and "ur" or "lr";
			end
		else
			if (dle < dre) then
				return due < 0.5 * props.height and "ul" or "ll";
			else
				return due < 0.5 * props.height and "ur" or "lr";
			end
		end
	end

	if (dx < dy) then
		return dle < dre and "l" or "r";
	else
		return due < dde and "u" or "d";
	end
end

-- evaluate position and update cursor etc. based on where we are, this is
-- made more complicated about a client actually telling us which border it
-- thinks that we are on.
local function set_borderstate(ctx)
	local p = mouse_to_border(ctx.tag);
	local ent = dir_lut[p];
	ctx.mask = ent[2];
	mouse_switch_cursor(ent[1]);
end

local function step_drag_resize(wnd, mctx, vid, dx, dy)
-- absurd warp->drag without over first
	if (not mctx.mask) then
		return;
	end

	wnd.x = wnd.x + dx * mctx.mask[3];
	wnd.y = wnd.y + dy * mctx.mask[4];

-- for client- driven resizing, we can only send our suggestion ('configure')
-- and then wait in the client event handler on a time where that makes sense
	if (wnd.scalemode == "client" and
		valid_vid(wnd.external, TYPE_FRAMESERVER)) then
		wnd.max_w = wnd.max_w + dx;
		wnd.max_h = wnd.max_h + dy;
		wnd:run_event("resize",
			wnd.max_w, wnd.max_h, wnd.effective_w, wnd.effective_h);

	else
		wnd:resize(
			wnd.width + dx * mctx.mask[1],
			wnd.height + dy * mctx.mask[2],
			true, false
		);
		move_image(wnd.anchor, wnd.x, wnd.y);
	end
end

-- special sematics for dragging a window and dropping it on top of another
local function try_swap(vids, wnd, candidates)
	for i,v in ipairs(candidates) do
		if (v ~= wnd and vids[v.canvas]) then
			local m1, m2 = dispatch_meta();
			if (m1) then
				wnd:reparent(v);
			elseif (m2) then
				wnd:reparent(v, true);
			else
				wnd:swap(v, false, false);
			end
			return;
		end
	end
end

local function drop_swap(wnd, mode)
	local x, y = mouse_xy();

-- gather / repack the suspects
	local items = pick_items(x, y, 8, true, active_display(true));
	if not items or #items == 0 then
		return;
	end

	local set = {};
	for i,v in ipairs(items) do
		set[v] = true;
	end

-- first, statusbar buttons
	for btn in wnd.wm.statusbar:all_buttons()	do
		if set[btn.bg] then
			if (btn.drag_command) then
				dispatch_symbol_wnd(wnd, btn.drag_command);
			end
			return;
		end
	end

	if mode ~= "tile" then
		return;
	end

-- for tiling modes, we can also try to swap or merge based on meta
	if (#items) then
		try_swap(set, wnd, wnd.space:linearize());
	end

-- restore is just relayout, so applies to both cases
	wnd.space:resize();
end

local function build_border(wnd)
	local table =
{
-- required 'metadata'
	name = wnd.name .. "_mh_border",
	own =
	function(ctx, vid)
		return vid == wnd.border;
	end,
	tag = wnd,

-- actual event handlers:
	motion =
	function(ctx)
		if (wnd.space.mode == "float") then
			set_borderstate(ctx);
		end
	end,

	over = function(ctx)
		return ctx.motion;
	end,

	out =
	function(ctx)
		mouse_switch_cursor("default");
		wnd.in_drag_rz = false;
		wnd.in_drag_move = false;
	end,

-- The worst of the bunch: border-drag-resize, this is made worse by the
-- wayland case where clients may have border contents we don't know about
-- and may need the client canvas to act as 'border'.
--
-- To deal with that, part of the drag_rz behavior is split into the handler
-- here and the in_drag_rz / drag_rz_enter states of the wnd table.
	drag =
	function(ctx, vid, dx, dy)
		if (not ctx.mask) then
			set_borderstate(ctx);
		end

-- protect against ugly "window destroyed just as we got drag"
		if (not wnd.drag_resize or wnd.space.mode ~= "float") then
			return;
		end

		if (not wnd.in_drag_rz and wnd.drag_rz_enter) then
			wnd:drag_rz_enter(ctx.mask);
		end

-- some (wayland) clients need entirely different behaviors here,
-- so we add an override that can be hooked and fall back to our own
-- if needed
		if (wnd.in_drag_rz) then
			if (type(wnd.in_drag_rz) == "function") then
				wnd:in_drag_rz(ctx, vid, dx, dy, false);
			else
				step_drag_resize(wnd, ctx, vid, dx, dy);
			end
			return;
		end

-- distinguish between on_begin_drag_resize and update_drag_resize
		wnd:drag_resize(ctx, true);
		step_drag_resize(wnd, ctx, vid, dx, dy);
	end,

	drop = function(ctx)
		tiler_debug(wnd.wm, "begin_drop");
		if (wnd.space.mode ~= "float") then
			return;
		end

-- should have separate rules for tiling here that shows a drag 'anchor'
-- which we use to calculate splitting point

		if (type(wnd.in_drag_rz) == "function") then
--			wnd:in_drag_rz(vid, 0, 0, true);
		end

-- normal might also care
		if (wnd.drag_resize) then
			wnd:drag_resize(ctx, false);
		end
	end
};

	mouse_addlistener(table, {"motion", "out", "over", "drag", "drop"});
	return table;
end

local function build_canvas(wnd)
	local table =
{
	name = wnd.name .. "_mh_canvas",
	own =
	function(ctx, vid)
		return vid == wnd.canvas;
	end,
	motion =
	function(ctx, vid, x, y, rx, ry)
		local ct = mouse_state().cursortag;
		if (ct) then
-- update accept state, for external clients we need to do a lot more
-- via the clipboard - i.e. ask if the type is currently accepted and
-- so on. the distributed mouse.lua is flawed here so temporarily set
-- overrides on vid and state here
			if (ct.handler and ct.handler(ct.ref, nil, wnd)) then
				mouse_cursortag_state(true);
				blend_image(ct.vid, 1.0);
				ct.accept = true;
			else
				mouse_cursortag_state(false);
				blend_image(ct.vid, 0.5);
				ct.accept = false;
			end
		end

		wnd:run_event("mouse_motion", x, y, rx, ry);
		wnd:mousemotion(x, y, rx, ry);
	end,

-- We support two modes of 'drag and drop' where one comes from press/
-- release and the other, more disability friendly, is a full click.
	release = function(ctx, vid, ...)
		local ct = mouse_state().cursortag;
		if (not ct) then
			return;
		end

		ct.handler(ct.ref, true, wnd);
		wnd.wm:cancellation();
	end,

	drag = function(ctx, vid, dx, dy, ...)
		if (wnd.space.mode ~= "float" and wnd.space.mode ~= "tile") then
			return;
		end

-- it has been an established custom elsewhere to always allow 'canvas+meta'
-- drag as an interpretation of starting a move, so go with that
		if (not wnd.in_drag_move) then
			local m1, m2 = dispatch_meta();
			if (m1 or m2) then
				wnd.x = wnd.x + wnd.ofs_x;
				wnd.y = wnd.y + wnd.ofs_y;
				wnd.in_drag_move = true;
				mouse_switch_cursor("drag");
			end
		end

-- with no decoration and a client that has requested that we are in resize
-- mode, we need to repeat the same dance we do in the border handler
		if (wnd.in_drag_rz) then
			if (wnd.in_drag_rz_mask) then
				ctx.mask = wnd.in_drag_rz_mask;
			end
			if (type(wnd.in_drag_rz) == "function") then
				wnd:in_drag_rz(ctx, vid, dx, dy);
			else
				wnd_step_drag(wnd, ctx, vid, dx, dy);
			end

-- move is easier, but options that are specific for mouse here:
-- a. don't align
-- b. interpret coordinates relative
-- c. perform instantaneous (no animation)
		elseif (wnd.in_drag_move) then
			wnd:move(dx, dy, false, false, true);

			for k,v in ipairs(wnd.space.wm.on_wnd_drag) do
				v(wnd.space.wm, wnd, dx, dy);
			end
			return true;

-- otherwise let the normal window mouse motion handler take care of
-- forwarding, updating state and translate to client coordinates
		else
			local x, y = mouse_xy();
			wnd:mousemotion(x, y, dx, dy);
		end
	end,

	drop = function(ctx, vid)
		if (wnd.in_drag_move) then
			drop_swap(wnd, wnd.space.mode);

-- wm global drag handlers
			for k,v in ipairs(wnd.space.wm.on_wnd_drag) do
				v(wnd.space.wm, wnd, 0, 0, true);
			end
			wnd:recovertag();
		end

		wnd.in_drag_rz = false;
		wnd.in_drag_move = false;
		mouse_switch_cursor();
	end,

	press = function(ctx, vid, ...)
		if (wnd.mousepress and not wnd.in_drag_rz and not wnd.in_drag_move) then
			wnd:mousepress(...);
		end
	end,

	over = function(ctx)
		if (wnd.wm.selected ~= wnd and
			gconfig_get("mouse_focus_event") == "motion") then
			wnd:select();
		else
			wnd:mouseactivate();
		end
	end,

-- make sure that the cursor is always visible (if it is supposed to be)
-- when we leave the surface, chances are it might get re-hidden when it
-- enters something else though.
	out = function(ctx)
		mouse_hidemask(true);
		mouse_show();
		mouse_switch_cursor();
		mouse_hidemask(false);

-- also reset border drag-state
		wnd.in_drag_rz = false;
		wnd.in_drag_move = false;
	end,

	button = function(ctx, vid, ...)
		if wnd.mousebutton then
			wnd:mousebutton(...);
		end
	end,

	dblclick = function(ctx)
		if wnd.mousedblclick then
			wnd:mousedblclick();
		end
	end
};

	mouse_addlistener(table, {
		"motion", "out", "over", "drag", "drop",
		"button", "dblclick", "press", "release"
	});
	return table;
end

local function build_titlebar(wnd)
	local table = {
	tag = wnd,
	name = wnd.name .. "_tbar_mh",
	over =
	function(ctx)
		if (wnd.space.mode == "float" or wnd.space.mode == "tile") then
			mouse_switch_cursor("grabhint");
		end
	end,

	out =
	function(ctx)
		mouse_switch_cursor("default");
	end,

	press =
	function(ctx)
		wnd:select();
		local mode = wnd.space.mode;
		if (mode == "float" or mode == "tile") then
			mouse_switch_cursor("drag");
		end
	end,

	release =
	function(ctx)
		if (wnd.space.mode == "tile") then
			mouse_switch_cursor("grabhint");
		end
	end,

	drop =
	function(ctx)
		local mode = wnd.space.mode;
		drop_swap(wnd, mode);

		if (mode == "float" or mode == "tile") then
			mouse_switch_cursor("grabhint");

			for k,v in ipairs(wnd.wm.on_wnd_drag) do
				v(wnd.wm, wnd, 0, 0, true);
			end
-- make sure new position gets saved
			wnd:recovertag();
		end
	end,

	drag =
	function(ctx, vid, dx, dy)
		local mode = wnd.space.mode;
-- no constraint or collision solver here, might be needed?
		if (mode == "float" or mode == "tile") then
-- disable the VIDs from the 'drag' so that on-over/on-out tracking
-- register for windows that we are passing
			wnd:move(dx, dy, false, false, true);

-- some event handlers to allow determining if it is 'droppable' or not
			for k,v in ipairs(wnd.wm.on_wnd_drag) do
				v(wnd.wm, wnd, dx, dy);
			end
		end
-- possibly check for other window in tile hierarchy based on
-- polling mouse cursor, and do a window swap
	end,

	click =
	function(ctx)
	end,

	rclick =
	function(ctx)
		wnd:select();
		dispatch_symbol(gconfig_get("tbar_rclick"));
	end,

	dblclick =
	function(ctx)
		if (wnd.space.mode == "float") then
			wnd:toggle_maximize();
		end
	end
};
	return table;
end

local function build_statusbar_icon(wm, cmd, alt_cmd)
	tiler_debug(wm, "sbar_icon:" ..
		"cmd=" .. (cmd and cmd or "none"),
		"alt_cmd=" .. (alt_cmd and alt_cmd or "none"));

	local table = {
		click =
		function(btn)
			local m1, m2 = dispatch_meta();
			if (m1 and alt_cmd) then
				dispatch_symbol(alt_cmd);
			elseif (cmd) then
				dispatch_symbol(cmd);
			end
		end,

		over =
		function(btn)
			btn:switch_state("active");
		end,

		out =
		function(btn)
			btn:switch_state("inactive");
		end,

		rclick =
		function(btn)
			dispatch_symbol(alt_cmd and alt_cmd or cmd);
		end
	};

	return table;
end

local function build_statusbar_wsicon(wm, i)
	local table = {
	click =
	function(btn)
		wm:switch_ws(i);
	end,
	rclick =
	function(btn)
		local ment = gconfig_get("ws_popup");
		local menu = menu_lookup_custom(ment);
		if not menu then
			tiler_debug(wm, "wsbtn:kind=error:status=einval:message=redirect_click:name=" .. ment);
			return btn:click();
		end
		local x, y = mouse_xy();
		uimap_popup(menu, x, y, btn.bg);
	end,
	over =
	function(btn)
		btn:switch_state(wm.space_ind == i and "alert" or "active");
	end,
	out =
	function(btn)
		btn:switch_state(wm.space_ind == i and "active" or "inactive")
	end
	}
	return table;
end

local function fallthrough(wm)
	local m1, m2 = dispatch_meta();
	return (wm.fallthrough_ioh and not m1 and not m2);
end

local function symaction(wm, sym)
	local action = gconfig_get(sym);
	tiler_logfun(string.format("action: %s, fallthrough: %s", action, tostring(fallthrough(wm))));
	if not action or #action == 0 or fallthrough(wm) then
		return;
	end
	dispatch_symbol(action);
end

local function build_background(wm)
	local table = {
	name = "workspace_background",
	motion = function(ctx, vid, x, y, rx, ry)
		if not fallthrough(wm) then
			return;
		end

-- re-use the window coordinate bits so that we get the storage-
-- relative coordinate scaling etc.
		local fakewnd = {
			last_ms = wm.last_ms,
			external = wm:active_space().background_src,
			canvas = vid
		};
		local mv = wm.convert_mouse_xy(fakewnd, x, y, rx, ry);
		wm:fallthrough_ioh({
			kind = "analog",
			mouse = true,
			devid = 0,
			subid = 0,
			samples = {mv[1], mv[2]}
		});
		wm:fallthrough_ioh({
			kind = "analog",
			mouse = true,
			devid = 0,
			subid = 1,
			samples = {mv[3], mv[4]}
		});
	end,
	button = function(ctx, vid, ind, pressed, x, y)
		if (wm.selected) then
			wm.selected:deselect();
		end
-- only forward if meta is not being held
		if fallthrough(wm) then
			wm:fallthrough_ioh(
			{
				kind = "digital", mouse = true, devid = 0,
				active = pressed, subid = ind
			});
		end
	end,
	click = function(ctx, vid, ...)
		symaction(wm, "float_bg_click");
	end,
	rclick = function(ctx, vid, ...)
		symaction(wm, "float_bg_rclick");
	end,
	dblclick = function(ctx, vid, ...)
		symaction(wm, "float_bg_dblclick");
	end,
	own = function(ctx, vid, ...)
		local sp = wm:active_space();
		return sp and sp.background == vid and sp.mode == "float";
	end
	};
	return table;
end

return {
	background = build_background,
	border = build_border,
	canvas = build_canvas,
	titlebar = build_titlebar,
	statusbar_icon = build_statusbar_icon,
	statusbar_wsicon = build_statusbar_wsicon
};

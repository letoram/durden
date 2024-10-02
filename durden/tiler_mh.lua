--
-- This translation unit returns factory functions for the possible decoration
-- mouse handlers, as well as the default implementation for mouse events that
-- are attached to a window on creation.
--
-- Much of this could/should be reworked to use builtin/decorator.lua instead.
--
local tiler_logfun = suppl_add_logfn("wm");
local function tiler_debug(wm, msg)
	msg = msg and msg or "bad message";
	if type(msg) == "table" then
		msg = table.concat(msg, "");
		return
	end
	tiler_logfun(wm.name .. ":" .. msg);
end

local function dist(x, y)
	return math.sqrt(x * x + y * y);
end

-- map rectangle edge to mouse-cursor direction and name
local dir_lut = {
	ul = {"north-west", {-1, -1, 1, 1}},
	 u = {"north-south", {0, -1, 0, 1}},
	ur = {"north-east", {1, -1, 0, 1}},
	 r = {"west-east", {1, 0, 0, 0}},
	lr = {"south-east", {1, 1, 0, 0}},
	 d = {"north-south", {0, 1, 0, 0}},
	ll = {"south-west", {-1, 1, 1, 0}},
	 l = {"west-east", {-1, 0, 1, 0}}
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

	if (dx < dy) then
		return dle < dre and "l" or "r";
	else
		return due < dde and "u" or "d";
	end
end

local old_btn
local function wnd_drag_preview_synch(wnd)
	if wnd.in_drag_ts < wnd.space.last_action then
		wnd.in_drag_move = wnd.space:linearize();
	end

-- more options here is with tab (swap order) and if rcpt is the titlebar
-- (merge/hide into window then add as button)
	local x, y = mouse_xy();

-- statusbar buttons are the exception, we need to go in / out
	if old_btn and valid_vid(old_btn.bg) then
		if image_hit(old_btn.bg, x, y) then
			old_btn:switch_state("active")
			return
		end
		old_btn:switch_state("inactive")
	end

	for btn in wnd.wm.statusbar:all_buttons()	do
		if image_hit(btn.bg, x, y) then
			old_btn = btn
			btn:switch_state("active")

			if valid_vid(wnd.drag_move_preview) then
				delete_image(wnd.drag_move_preview)
				wnd.drag_move_preview = nil
				wnd.in_drag_last = nil
				wnd.drag_move_pos = nil
			end
			return
		end
	end

	old_btn = nil

-- the action depends on if we are in tiling or not
	if wnd.space.mode ~= "tile" then
		return
	end

-- cache to not iterate on every step, account for lw being removed during drag
	local lw = wnd.in_drag_last;
	if lw then
		if lw.x and
			x >= lw.x and x <= lw.width + lw.x and
			y >= lw.y and y <= lw.height + lw.y then
		else
			lw = nil;
		end
	end

-- otherwise we have to searh
	if not lw then
		for _,v in ipairs(wnd.in_drag_move) do
			if v ~= wnd and x >= v.x and x <= v.width + v.x and
				y >= v.y and y <= v.height + v.y then
				lw = v;
				break;
			end
		end
	end

	wnd.in_drag_last = lw;
	if not lw then
-- top, bottom or statusbar
		return
	end

-- figure out effective region (and action), since it attaches to the current
-- 'over' window it could die while we are moving
	local dmp;
	local dpos = wnd.drag_move_pos;
	if not valid_vid(wnd.drag_move_preview) then
		wnd.drag_move_preview = color_surface(64, 64, unpack(gconfig_get("tbar_color")));
		image_inherit_order(wnd.drag_move_preview, true);
		order_image(wnd.drag_move_preview, 1);
		dmp = wnd.drag_move_preview;
	else
		dmp = wnd.drag_move_preview;
	end

	local set_preview =
	function(anchor, anchor_dir, w, h, dw, dh, tag)
		if dpos == tag then
			return;
		end

		local at = gconfig_get("animation");
		hide_image(dmp);
		resize_image(dmp, 1, 1);
		move_image(dmp, 0, 0);
		link_image(dmp, anchor, anchor_dir);
		resize_image(dmp, w, h, at);
		move_image(dmp, w * dw, h * dh, at);
		blend_image(dmp, 0.5, at);
		image_mask_set(dmp, MASK_UNPICKABLE);

		wnd.drag_move_pos = tag;
	end

	if y < lw.y + lw.effective_h * 0.2 then
		set_preview(lw.canvas, ANCHOR_UL,
			lw.effective_w, lw.effective_h * 0.2, 0, 0, "t");

	elseif y > lw.y + lw.effective_h * 0.8 then
		local bh = math.ceil(lw.effective_h * 0.2);
		set_preview(lw.canvas, ANCHOR_LL, lw.effective_w, bh, 0, -1, "d");

	elseif x < lw.x + lw.effective_w * 0.2 then
		set_preview(lw.canvas, ANCHOR_UL,
			lw.effective_w * 0.2, lw.effective_h, 0, 0, "l");

	elseif x > lw.x + lw.effective_w * 0.8 then
		local bw = math.ceil(lw.effective_w * 0.2);
		set_preview(lw.canvas, ANCHOR_UR, bw, lw.effective_h, -1, 0, "r");

	else
		local bw = math.ceil(lw.effective_w * 0.4);
		local bh = math.ceil(lw.effective_h * 0.4);
		set_preview(lw.canvas, ANCHOR_C, bw, bh, -0.5, -0.5, "c");
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

-- special sematics for dragging a window and dropping it on top of another
local function try_swap(wnd, tgt, tgt_dir)
	if tgt_dir == "c" then
		wnd:swap(tgt, false, false);

	elseif tgt_dir == "t" then
		wnd:collapse();
		wnd:reparent(tgt);
		wnd:swap(wnd.parent);
		wnd.space:resize();

	elseif tgt_dir == "l" then
		wnd:collapse();
		wnd:reparent(tgt, true);

-- re-order so it lands at the index to the left
		table.remove_match(tgt.parent.children, wnd);
		local i = table.find_i(tgt.parent.children, tgt);

		table.insert(tgt.parent.children, i, wnd);

		wnd.space:resize();

	elseif tgt_dir == "r" then
		wnd:collapse();
		wnd:reparent(tgt, true);

		table.remove_match(tgt.parent.children, wnd);
		local i = table.find_i(tgt.parent.children, tgt);
		table.insert(tgt.parent.children, i + 1, wnd);

		wnd.space:resize();

-- re-order so it lands at the index to the right
	elseif tgt_dir == "d" then
		wnd:collapse();
		wnd:reparent(tgt);
		wnd.space:resize();
	end
end

local function drop_swap(wnd, mode, tgt, tgt_dir, ostate)
-- first clean up
	local dir = wnd.drag_move_pos;
	wnd.drag_move_pos = nil;
	wnd.in_drag_move = false;

	if valid_vid(wnd.drag_move_preview) then
		delete_image(wnd.drag_move_preview);
		wnd.drag_move_preview = nil;
	end

-- if we have an explicit target, just go with that
	if tgt then
		if mode == "tile" then
			try_swap(wnd, tgt, tgt_dir);
			wnd.space:resize();
		end
		return;
	end

-- otherwise we still need to check for drag over statusbar buttons
	local x, y = mouse_xy();

	wnd.in_drag_move = false;
	wnd.in_drag_pos = nil;

	if valid_vid(wnd.drag_move_preview) then
		delete_image(wnd.drag_move_preview);
		wnd.drag_move_preview = nil;
	end

-- gather / repack the suspects
	local items = pick_items(x, y, 8, true, active_display(true));
	if not items or #items == 0 then

-- no picking result, send a last move event without the in_drag_move
		wnd:move(0, 0);
		return;
	end

	local set = {};
	for i,v in ipairs(items) do
		set[v] = true;
	end

-- this could also be used for individual window titlebar buttons or the bar
-- itself, e.g. drag to dock into titlebar for pseudo- tabbed, or border to
-- link coordinate systems
	for btn in wnd.wm.statusbar:all_buttons()	do
		if set[btn.bg] then
			if type(btn.drag_command) == "string" then
				dispatch_symbol_wnd(wnd, btn.drag_command);
			elseif type(btn.drag_command) == "function" then
				btn.drag_command(wnd)
			end
			break;
		end
	end

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
		wnd.in_drag_move = false;
	end,

-- The worst of the bunch: border-drag-resize, this is made worse by the
-- wayland case where clients may have border contents we don't know about
-- and may need the client canvas to act as 'border'.
--
	drag =
	function(ctx, vid, dx, dy)
		if (not ctx.mask) then
			set_borderstate(ctx);
		end

-- protect against ugly "window destroyed just as we are in drag"
		if (wnd.space.mode ~= "float") then
			return;
		end

		if (not wnd.in_drag_rz) then
			wnd:drag_resize_enter(ctx.mask);
		end

		wnd:drag_resize(ctx.mask, dx, dy);
	end,

	drop = function(ctx)
		tiler_debug(wnd.wm, "begin_drop");
		if (wnd.space.mode ~= "float") then
			return;
		end

		wnd:drag_resize_leave(ctx.mask)
		ctx.mask = nil
	end
	};

	mouse_addlistener(table, {"motion", "out", "over", "drag", "drop"});
	return table;
end

local function ct_handler(wnd, accept)
	local ct = mouse_state().cursortag;
	if not ct then
		return
	end

	if not ct.handler or not ct.handler(wnd, accept, ct.src, ct) then
		mouse_cursortag_state(false);
		mouse_switch_cursor("drag-reject");
	else
		mouse_switch_cursor("drag-drop");
		mouse_cursortag_state(true);
	end

	if accept ~= nil then
		mouse_switch_cursor("default");
		ct.src.in_drag_tag = false;
		wnd.wm:cancellation();
	end
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
		ct_handler(wnd, nil);
		wnd:run_event("mouse_motion", x, y);
		wnd:mousemotion(x, y, rx, ry);
	end,

-- We support two modes of 'drag and drop' where one comes from press/
-- release and the other, more disability friendly, is a full click.
	release = function(ctx, vid, ...)
		local ct = mouse_state().cursortag;
		if (not ct) then
			return;
		end

		if wnd.in_drag_tag and gconfig_get("mouse_stickydnd") then
			return
		end

		ct_handler(wnd, true);
	end,

	drag = function(ctx, vid, dx, dy, ...)
	-- handle drag as well since it will mask 'motion' events as soon as we
	-- are out of the drag threshold (if the event is handled)
		if (wnd.space.mode ~= "float" and wnd.space.mode ~= "tile") then
			local x, y = mouse_xy();
			wnd:mousemotion(x, y, dx, dy);
			return;
		end

-- it has been an established custom elsewhere to always allow 'canvas+meta'
-- drag as an interretation of starting a move, so go with that
		if (not wnd.in_drag_move and not wnd.in_drag_tag) then
			local m1, m2 = dispatch_meta();
			if (m1 or (m2 and not gconfig_get("mouse_m2_cursortag"))) then
				wnd.x = wnd.x + wnd.ofs_x;
				wnd.y = wnd.y + wnd.ofs_y;
				wnd.in_drag_move = wnd.space:linearize();
				wnd.in_drag_ts = CLOCK;
				wnd.in_drag_pos = {x = wnd.x, y = wnd.y};
				mouse_switch_cursor("drag");

			elseif m2 then
				wnd.in_drag_tag = true;
				dispatch_symbol_wnd(wnd, "/target/window/cursortag")
				ct_handler(wnd);
			end
		end

		if (wnd.in_drag_rz) then
			if ctx.mask then
				wnd:drag_resize(ctx.mask, dx, dy);
			else
				wnd:drag_resize_leave();
			end

-- move is easier, but options that are specific for mouse here:
-- a. don't align
-- b. interpret coordinates relative
-- c. perform instantaneous (no animation)
		elseif (wnd.in_drag_move) then
			wnd:move(dx, dy, false, false, true);
			wnd_drag_preview_synch(wnd);

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
			wnd.in_drag_move = false;
			drop_swap(wnd, wnd.space.mode, wnd.in_drag_last, wnd.drag_move_pos);
			wnd:move(0, 0, false, false, true);

-- wm global drag handlers
			for k,v in ipairs(wnd.space.wm.on_wnd_drag) do
				v(wnd.space.wm, wnd, 0, 0, true);
			end
			wnd:recovertag();

		elseif wnd.in_drag_tag then
			if gconfig_get("mouse_stickydnd") then
				return
			end
			mouse_cursortag_drop();
			wnd.in_drag_tag = false;
		end

		wnd.in_drag_rz = false;
		wnd:mouseactivate();
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
		wnd.in_drag_move = false;
	end,

	button = function(ctx, vid, ...)
		local ct = mouse_state().cursortag;
		if ct then
			return
		end

		if wnd.mousebutton then
			wnd:mousebutton(...);
		end
	end,

	click = function(ctx)
		if not gconfig_get("mouse_stickydnd") then
			return
		end

		ct_handler(wnd, true);
	end,

	dblclick = function(ctx)
		if wnd.mousedblclick then
			wnd:mousedblclick();
		end
	end
};

	mouse_addlistener(table);
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
		drop_swap(wnd, wnd.space.mode, wnd.in_drag_last, wnd.drag_move_pos);

		if old_btn and valid_vid(old_btn.bg) then
			old_btn:switch_state("inactive")
			old_btn = nil
		end

		if (mode == "float" or mode == "tile") then
			mouse_switch_cursor("grabhint");

			wnd.in_drag_move = false;
			wnd:move(0, 0, false, false, true);

-- cascade to space event handler as well (window is in drop_swap)
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
			if not wnd.in_drag_move then
				wnd:set_drag_move();
			end

			if wnd.maximized then
				local x, y = wnd.x, wnd.y
				wnd:toggle_maximize()
				wnd:move(x, y, false, true, true, false)
			end

			wnd:move(dx, dy, false, false, true);
			wnd_drag_preview_synch(wnd);

-- some event handlers to allow determining if it is 'droppable' or not
			for k,v in ipairs(wnd.wm.on_wnd_drag) do
				v(wnd.wm, wnd, dx, dy);
			end
		end
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

local function build_statusbar_addicon(wm)
	return {
	click =
	function(btn)
		dispatch_symbol("/global/workspace/switch/new");
	end,
	over =
	function(btn)
		btn:switch_state("active");
	end,
	out =
	function(btn)
		btn:switch_state("inactive")
	end
	};
end

local last_hover

local function button_hover_preview(btn, vid, x, y, on)
	local wm = active_display()

-- workaround for bug in mouse.lua not always sending 'off'
	if valid_vid(last_hover) then
		delete_image(last_hover)
		last_hover = nil
	end

	if not on then
		if valid_vid(btn.preview) then
			local at = gconfig_get("popup_animation")
			blend_image(btn.preview, 0.0, at)
			expire_image(btn.preview, at)
			btn.preview = nil
		end
		return
	end

	local arw = 128 * (wm.width / wm.height) * wm.scalef
	local arh = 128 * (wm.height / wm.width) * wm.scalef
	resize_image(vid, arw, arh)

	local pos = gconfig_get("sbar_position");

	last_hover = vid
	image_mask_set(vid, MASK_UNPICKABLE)
	blend_image(vid, 1.0, gconfig_get("popup_animation"))
	image_inherit_order(vid, true)
	shader_setup(vid, "ui", "rounded_border", "active")

-- for bar at T/L:
	local ms = mouse_state()
	btn.preview = vid
	if pos == "top" then
		link_image(vid, btn.bg, ANCHOR_LR)
	elseif pos == "left" then
		link_image(vid, btn.bg, ANCHOR_UR)
	elseif pos == "right" then
		link_image(vid, btn.bg, ANCHOR_UL)
		nudge_image(vid, -arw, 0);
	else
		link_image(vid, btn.bg, ANCHOR_YL)
		nudge_image(vid, 0, -arh);
	end
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
		menu = table.copy(menu);
		menu.preset = i;
		local x, y = mouse_xy();
		uimap_popup(menu, x, y);
	end,
	hover = function(btn, vid, x, y, on)
		local wm = active_display()
		local arw = 128 * (wm.width / wm.height) * wm.scalef
		local arh = 128 * (wm.height / wm.width) * wm.scalef

		local vid = wm.spaces[i]:preview(arw, arh, 64, -1)
		if not valid_vid(vid) then
			return
		end

		button_hover_preview(btn, vid, x, y, on)
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
	local msg = string.format("action=%s:fallthrough=%s", action, tostring(fallthrough(wm)));
	tiler_logfun(msg);
	if not action or #action == 0 or fallthrough(wm) then
		return;
	end
	dispatch_symbol(action);
end

local function build_background(ws)
	local wm = ws.wm;
	assert(wm);

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
		local mv = wm.convert_mouse_xy(fakewnd, fakewnd.vid, x, y, rx, ry);
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
		if (wm.selected and pressed) then
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
		return vid == ws.anchor and ws.mode == "float";
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
	statusbar_wsicon = build_statusbar_wsicon,
	statusbar_addicon = build_statusbar_addicon,
	hover_preview = button_hover_preview
};

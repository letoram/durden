-- Copyright: 2015-2017, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Depends: display, shdrmgmt, lbar, suppl, mouse
-- Description: Tiler comprise the main tiling window management, event
-- routing, key interpretation and other hooks. It returns a single
-- creation function (tiler_create(W, H)) that returns the usual table
-- of functions and members in pseudo-OO style.

-- number of Z values reserved for each window
local WND_RESERVED = 10;

local ent_count = 1;

local create_workspace = function() end

local function wnd_animation_time(wnd, source, decor, position)
	reset_image_transform(source);
	if (wnd.attach_time == CLOCK) then
		return 0;
	end

	if (position) then
		return gconfig_get("wnd_animation"), INTERP_SMOOTHSTEP;
	end

	if (not wnd.autocrop and ( wnd.space.mode == "tile" or
		(wnd.space.mode == "float" and not wnd.in_drag_rz))) then
		return gconfig_get("wnd_animation"), INTERP_SMOOTHSTEP;
	end
	return 0;
end

local function linearize(wnd)
	local res = {};
	local dive = function(wnd, df)
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
	return mode == "tile" or
		(mode == "float" and not gconfig_get("float_tbar_override"));
end

local function tbar_geth(wnd)
	assert(wnd ~= nil);
	return (wnd.space and wnd.hide_titlebar and tbar_mode(wnd.space.mode))
		and 0 or (wnd.wm.scalef * gconfig_get("tbar_sz"));
end

local function sbar_geth(wm, ign)
	if (ign) then
		return math.ceil(gconfig_get("sbar_sz") * wm.scalef);
	else
		if gconfig_get("sbar_hud") or
			((wm.spaces[wm.space_ind] and
				wm.spaces[wm.space_ind].mode == "fullscreen")) then
					wm.statusbar:hide();
					return 0;
		else
			return math.ceil(gconfig_get("sbar_sz") * wm.scalef);
		end
	end
end

local function sbar_hide(wm)
		if (not gconfig_get("sbar_hud")) then
		wm.statusbar:hide();
		wm.hidden_sb = true;
	end
end

local function sbar_show(wm)
	if (not gconfig_get("sbar_hud")) then
		wm.statusbar:show();
		wm.hidden_sb = false;
	end
end

local function run_event(wnd, event, ...)
	assert(wnd.handlers[event]);
	for i,v in ipairs(wnd.handlers[event]) do
		v(wnd, unpack({...}));
	end
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

local function wnd_destroy(wnd)
	local wm = wnd.wm;
	if (wnd.delete_protect) then
		return;
	end

-- need a local copy since the destroy will modify the table
	local list = {};
	for i,v in ipairs(wnd.dependents) do
		list[i] = v;
	end
	for i,v in ipairs(list) do
		v:destroy();
	end

	if (wm.deactivated and wm.deactivated.wnd == wnd) then
		wm.deactivated.wnd = nil;
	end

	if (wm.selected == wnd) then
		wnd:deselect();
	end

	local space = wnd.space;

	if (space and wnd.fullscreen) then
		space:tile();
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
		if (#wnd.children > 0) then
			wnd.children[1]:select();
		elseif (wnd.parent and wnd.parent.parent) then
			wnd.parent:select();
		else
			wnd:prev();
		end
	end

-- doesn't always hit
	if (wnd.wm.selected == wnd) then
		wnd.wm.selected = nil;
	end

-- deregister from space tracking
	if (space and wnd.space.selected == wnd) then
		space.selected = nil;
	end

-- re-assign all children to parent
	moveup_children(wnd);

-- now we can run destroy hooks
	run_event(wnd, "destroy");
	for i,v in ipairs(wnd.relatives) do
		run_event(v, "lost_relative", wnd);
	end

	wnd:drop_popup(true);

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

	wnd.titlebar:destroy();

	if (valid_vid(wnd.external) and not wnd.external_prot) then
		delete_image(wnd.external);
	end

	for k,v in pairs(wnd) do
		wnd[k] = nil;
	end

-- drop global tracking
	table.remove_match(wm.windows, wnd);

-- rebuild layout
	if (space and
		not (space.layouter and space.layouter.lost(space, wnd, true))) then
		space:resize();
	end
end

local function wnd_message(wnd, message, timeout)
--	print("wnd_message", message);
end

local function wnd_deselect(wnd, nopick)
	if (not wnd.space) then
		return;
	end

	local mwm = wnd.space.mode;
	if (mwm == "tab" or mwm == "vtab") then
		if (not nopick) then
			hide_image(wnd.anchor);
		end
	end

	if (wnd.wm.selected == wnd) then
		wnd.wm.selected = nil;
	end

	if (wnd.mouse_lock) then
		mouse_lockto(BADID);
	end

	wnd:set_dispmask(bit.bor(wnd.dispmask, TD_HINT_UNFOCUSED));

	local x, y = mouse_xy();
	if (image_hit(wnd.canvas, x, y) and wnd.cursor == "hidden") then
		mouse_hidemask(true);
		mouse_show();
		mouse_hidemask(false);
	end

	local state = wnd.suspended and "suspended" or "inactive";
	shader_setup(wnd.border, "ui", "border", state);
	wnd.titlebar:switch_state(state, true);

-- save scaled coordinates so we can handle a resize
	if (gconfig_get("mouse_remember_position")) then
		local props = image_surface_resolve_properties(wnd.canvas);
		if (x >= props.x and y >= props.y and
			x <= props.x + props.width and y <= props.y + props.height) then
			wnd.mouse = {
				(x - props.x) / props.width,
				(y - props.y) / props.height
			};
		end
	end

	run_event(wnd, "deselect");
end

local function output_mouse_devent(btl, wnd)
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

-- set leftmost button to match the layout mode of the workspace
local function wm_update_mode(wm)
	if (not wm.spaces[wm.space_ind]) then
		return;
	end

	local modestr = wm.spaces[wm.space_ind].mode;
	if (modestr == "tile") then
		modestr = modestr .. ":" .. wm.spaces[wm.space_ind].insert;
	end
	wm.sbar_ws["left"]:update(modestr);
end

local function tiler_statusbar_update(wm)
-- synch constraints
	local statush = sbar_geth(wm);
	if (statush > 0) then
		wm.statusbar:resize(wm.width, statush);
	end

-- reposition
	if (gconfig_get("sbar_pos") == "top") then
		wm.statusbar:move(0, -statush);
		move_image(wm.anchor, 0, statush);
	else
		move_image(wm.anchor, 0, 0);
		wm.statusbar:move(0, wm.height - statush);
	end

	if (not wm.space_ind or not wm.spaces[wm.space_ind]) then
		return;
	end

-- regenerate buttons and labels
	wm_update_mode(wm);
	local space = wm.spaces[wm.space_ind];

-- consider visibility (fullscreen, or HUD mode affects it)
	local invisible = space.mode == "fullscreen" or
		(gconfig_get("sbar_hud") and not tiler_lbar_isactive());

	wm.statusbar[invisible and "hide" or "show"](wm.statusbar);

	for i=1,10 do
		if (wm.spaces[i] ~= nil) then
			wm.sbar_ws[i]:show();
			local lbltbl = {gconfig_get("pretiletext_color"), tostring(i)};
			local lbl = wm.spaces[i].label;
			if (lbl and string.len(lbl) > 0) then
				lbltbl[3] = "";
				lbltbl[4] = ":";
				lbltbl[5] = gconfig_get("label_color");
				lbltbl[6] = lbl;
			end
			wm.sbar_ws[i]:update(lbltbl);
			if (wm.spaces[i].background) then
				move_image(wm.spaces[i].background, 0,
					gconfig_get("sbar_pos") == "top" and -statush or 0);
			end
		else
			wm.sbar_ws[i]:hide();
		end
		wm.sbar_ws[i]:switch_state(i == wm.space_ind and "active" or "inactive");
	end
end

local function tiler_statusbar_build(wm)
	local sbsz = sbar_geth(wm, true);
	wm.statusbar = uiprim_bar(
		wm.order_anchor, ANCHOR_UL, wm.width, sbsz, "statusbar");
	local pad = gconfig_get("sbar_tpad") * wm.scalef;
	wm.sbar_ws = {};

-- add_button(left, pretile, label etc.)
	wm.sbar_ws["left"] = wm.statusbar:add_button("left", "sbar_item_bg",
		"sbar_item", "mode", pad, wm.font_resfn, nil, sbsz,
		{
			click = function()
				if (not wm.spaces[wm.space_ind].in_float) then
					wm.spaces[wm.space_ind]:float();
				else
-- NOTE: this breaks the decoupling between tiler and rest of durden, and maybe
-- this mouse-handler management hook should be configurable elsewhere
					local fun = grab_global_function("global_actions");
					if (fun) then
						fun();
					end
				end
			end,
			rclick = function()
				if (wm.spaces[wm.space_ind].in_float) then
					local fun = grab_shared_function("target_actions");
					if (fun) then
						fun();
					end
				end
			end
		});

-- pre-allocate buffer slots, but keep hidden
	for i=1,10 do
		wm.sbar_ws[i] = wm.statusbar:add_button("left", "sbar_item_bg",
			"sbar_item", tostring(i), pad, wm.font_resfn, sbsz, nil,
			{
				click = function(btn)
					wm:switch_ws(i);
				end,
				rclick = click
			}
		);
		wm.sbar_ws[i]:hide();
	end
-- fill slot with system messages, will later fill the role of a notification
-- stack, with possible timeout and popup- list
	wm.sbar_ws["msg"] = wm.statusbar:add_button("center",
		"sbar_msg_bg", "sbar_msg_text", " ", pad, wm.font_resfn, nil, sbsz,
		{
			click = function(btn)
				btn:update("");
			end
		});
	wm.sbar_ws["msg"].align_left = true;
end

local function wm_order(wm)
	return wm.order_anchor;
end
-- recursively resolve the relation hierarchy and return a list
-- of vids that are linked to a specific vid
local function get_hier(vid)
	local ht = {};

	local level = function(hf, vid)
		for i,v in ipairs(image_children(vid)) do
			table.insert(ht, v);
			hf(hf, v);
		end
	end

	level(level, vid);
	return ht;
end

local function canvas_mouse_activate(wnd)
-- reset hidden state without running a reveal animation
	local hidden = mouse_state().hidden;

	mouse_hidemask(true);
	mouse_show();
	mouse_switch_cursor();
	mouse_hidemask(false);

-- switch to the desired mouse cursor
	if (wnd.custom_cursor and wnd.custom_cursor.active) then
		if (valid_vid(wnd.custom_cursor.vid)) then
			mouse_custom_cursor(wnd.custom_cursor);
		else
			wnd.custom_cursor = nil;
		end

	elseif (wnd.cursor_label) then
		mouse_switch_cursor(wnd.cursor_label);
	end

	if (hidden or wnd.cursor == "hidden") then
		mouse_hidemask(true);
		mouse_hide();
		mouse_hidemask(false);
	end
end

local function wnd_select(wnd, source, mouse)
	if (wnd.wm.deactivated or not wnd.space) then
		return;
	end

-- may be used to reactivate locking after a lbar or similar action
-- has been performed.
	if (wnd.wm.selected == wnd) then
		if (wnd.mouse_lock) then
			mouse_lockto(wnd.canvas, type(wnd.mouse_lock) == "function" and
				wnd.mouse_lock or nil, wnd.mouse_lock_center);
		end
		return;
	end

	wnd:set_dispmask(bit.band(wnd.dispmask,
		bit.bnot(wnd.dispmask, TD_HINT_UNFOCUSED)));

	if (wnd.wm.selected) then
		wnd.wm.selected:deselect();
	end

	local mwm = wnd.space.mode;
	if (mwm == "tab" or mwm == "vtab") then
		show_image(wnd.anchor);
	end

	local state = wnd.suspended and "suspended" or "active";
	shader_setup(wnd.border, "ui", "border", state);

-- we don't want to mess with cursor/selected when it's a hidden wnd

	wnd.titlebar:switch_state(state, true);

	wnd.space.previous = wnd.space.selected;
	if (wnd.wm.active_space == wnd.space) then
		wnd.wm.selected = wnd;
	end
	wnd.space.selected = wnd;
	run_event(wnd, "select", mouse);

-- activate all "on-trigger" mouse events, like warping and locking
	ms = mouse_state();
	ms.hover_ign = true;

	local props = image_surface_resolve_properties(wnd.canvas);
	if (gconfig_get("mouse_remember_position") and not ms.in_handler) then
		local px = 0.0;
		local py = 0.0;

		if (wnd.mouse) then
			px = wnd.mouse[1];
			py = wnd.mouse[2];
		end
		mouse_absinput_masked(
			props.x + px * props.width, props.y + py * props.height, true);
		canvas_mouse_activate(wnd);
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

	if (wnd.mouse_lock) then
		mouse_lockto(wnd.canvas, type(wnd.mouse_lock) == "function" and
				wnd.mouse_lock or nil, wnd.mouse_lock_center, wnd);
	end

	wnd:to_front();
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
local function level_resize(level, x, y, w, h, repos, fairh)
	local fairw = math.ceil(w / #level.children);
	fairw = (fairw % 2) == 0 and fairw or fairw + 1;
	if (#level.children == 0) then
		return;
	end

	local process_node = function(node, last, fairh)
		node.x = x; node.y = y;
		node.max_h = h;

		if (last) then
			node.max_w = w;
		else
			node.max_w = math.floor(fairw * node.weight);
			node.max_w = (node.max_w % 2) == 0 and node.max_w or node.max_w + 1;

-- align with font size, but safe-guard against bad / broken client
			if (node.sz_delta and
				node.sz_delta[1] < gconfig_get("term_font_sz") * 2) then
				local hd = node.pad_left + node.pad_right;
				local delta_diff = (node.max_w - hd) % node.sz_delta[1];
				if (delta_diff > 0) then
					if (node.max_w - hd + delta_diff <= w) then
						node.max_w = node.max_w + delta_diff + hd;
					elseif (node.max_w - hd + delta_diff > 0) then
						node.max_w = node.max_w - delta_diff + hd;
					end
				end
			end
		end

-- recurse downwards
		if (#node.children > 0) then
			node.max_h = math.floor(fairh * node.vweight);

-- this allows a node to be set to 'float' while still in tile- mode
			if (node.tile_ignore) then
				level_resize(node, x, y, node.max_w, h, repos, fairh);
			else
				level_resize(node,
						x, y + node.max_h, node.max_w, h - node.max_h, repos, fairh);
			end
		end

		node:resize(node.max_w, node.max_h, false, repos);

		x = x + node.max_w;
		w = w - node.max_w;
	end

-- recursively find the depth to know the fair division, (N) is not high
-- enough for this value to be worth tracking rather than just calculating
	local get_depth;
	get_depth = function(node, depth)
		if (#node.children == 0) then
			return depth;
		end

		local maxd = depth;
		for i=1,#node.children do
			local d = get_depth(node.children[i], depth + (node.tile_ignore and 0 or 1));
				maxd = d > maxd and d or maxd;
		end

		return maxd;
	end

	for i=1,#level.children-1 do
		process_node(level.children[i], false,
			fairh and fairh or math.floor(h / get_depth(level.children[i], 1)));
	end

-- allow the last node to "fill" to handle broken weights
	local last = level.children[#level.children];
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

	instant_image_transform(space.anchor);
	if (valid_vid(space.background)) then
		instant_image_transform(space.background);
	end

	if (not noanim and time > 0 and method ~= "none") then
		local htime = time * 0.5;
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
-- stay at level zero for a little while so not to fight with crossfade
			blend_image(space.anchor, 0.0);
			blend_image(space.anchor, 0.0, htime);
			blend_image(space.anchor, 1.0, htime);
		else
			warning("broken method set for ws_transition_in: " ..method);
		end
-- slightly more complicated, we don't want transitions if the background is the
-- same between different workspaces as it is visually more distracting
		local bg = space.background;
		if (bg) then
			if (not valid_vid(oldbg) or not image_matchstorage(oldbg, bg)) then
				blend_image(bg, 0.0, htime);
				blend_image(bg, 1.0, htime);
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
		if (space.background) then show_image(space.background); end
	end

	space.wm.active_space = space;
	local tgt = space.selected and space.selected or space.children[1];
end

local function workspace_deactivate(space, noanim, negdir, newbg)
	local time = gconfig_get("transition");
	local method = gconfig_get("ws_transition_out");

-- hack so that deselect event is sent but not all other state changes trigger
	if (space.selected and not noanim) then
		local sel = space.selected;
		wnd_deselect(space.selected);
		space.selected = sel;
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
		elseif (method == "move-v") then
			move_image(space.anchor, 0, (negdir and -1 or 1) * space.wm.height, time);
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
	if (oldt == display) then
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
		return;
	end

-- add/remove from corresponding tilers, update status bars
	workspace_deactivate(ws, true);
	ws.wm = newt;
	rendertarget_attach(newt.rtgt_id, ws.anchor, RENDERTARGET_DETACH);
	link_image(ws.anchor, newt.anchor);

	local wnd = linearize(ws);
	for i,v in ipairs(wnd) do
		v.wm = newt;
		table.insert(newt.windows, v);
		table.remove_match(oldt.windows, v);
-- send new display properties
		if (disptbl and valid_vid(v.external, TYPE_FRAMESERVER)) then
			target_displayhint(v.external, 0, 0, v.dispmask, get_disptbl(v, disptbl));
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
		local lst = linearize(space);
		for k,v in ipairs(space) do
			hide_image(space.anchor);
		end
			show_image(space.selected.anchor);
	else
		sbar_show(space.wm);
		workspace_deactivate(space, false, ndir, newbg);
	end
end

local function drop_fullscreen(space, swap)
	workspace_activate(space, true);
	sbar_show(space.wm);

-- show all hidden windows within the space
	local wnds = linearize(space);
	for k,v in ipairs(wnds) do
		show_image(v.anchor);
	end

-- safe-guard against bad code elsewhere
	if (not space.selected) then
		return;
	end

-- restore 'full-screen only' properties
	local dw = space.selected;
	dw.titlebar:show();
	show_image(dw.border);
	for k,v in pairs(dw.fs_copy) do dw[k] = v; end
	dw.fs_copy = nil;
	dw.fullscreen = nil;
	image_mask_set(dw.canvas, MASK_OPACITY);
	space.switch_hook = nil;
end

local function drop_tab(space)
	local res = linearize(space);

-- relink the titlebars so that they anchor their respective windows rather
-- than the client window itself.
	for k,v in ipairs(res) do
		v.titlebar:reanchor(v.anchor, 2, v.border_w, v.border_w);
		show_image(v.border);
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
		v.last_float = {
			width = v.width / space.wm.width,
			height = v.height / space.wm.height,
			x = pos.x / space.wm.width,
			y = pos.y / space.wm.height
		};
	end
end

local function reassign_float(space, wnd)
end

local function reassign_tab(space, wnd)
	wnd.titlebar:reanchor(wnd.anchor, 2, wnd.border_w, wnd.border_w);
	show_image(wnd.anchor);
	show_image(wnd.border);
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
	local fairw = math.ceil(wm.width / #lst);
	local tbar_sz = math.ceil(gconfig_get("tbar_sz") * wm.scalef);
	local sb_sz = sbar_geth(wm);
	local bw = gconfig_get("borderw");
	local ofs = 0;

	for k,v in ipairs(lst) do
		v.max_w = wm.width;
		v.max_h = wm.height - sb_sz - tbar_sz;
		if (not repos) then
			v:resize(v.max_w, v.max_h);
		end
		move_image(v.anchor, 0, 0);
		move_image(v.canvas, 0, tbar_sz);
		hide_image(v.anchor);
		hide_image(v.border);
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
	space.reassign_hook = reassign_tab;

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
		v.max_w = wm.width;
		v.max_h = cl_area;
		if (not repos) then
			v:resize(v.max_w, v.max_h);
		end
		move_image(v.anchor, 0, ypos);
		move_image(v.canvas, 0, 0);
		hide_image(v.anchor);
		hide_image(v.border);
		v.titlebar:reanchor(space.anchor, 2, 0, (k-1) * tbar_sz);
		v.titlebar:resize(wm.width, tbar_sz);
		ofs = ofs + tbar_sz;
	end

	if (space.selected) then
		local wnd = space.selected;
		wnd:deselect();
		wnd:select();
	end
end

local function set_fullscreen(space)
	if (not space.selected) then
		return;
	end
	local dw = space.selected;

-- keep a copy of properties we may want to change during fullscreen
	dw.fs_copy = {
		centered = dw.centered,
		fullscreen = false
	};
	dw.centered = true;
	dw.fullscreen = true;

-- hide all images + statusbar
	sbar_hide(dw.wm);

	local wnds = linearize(space);
	for k,v in ipairs(wnds) do
		hide_image(v.anchor);
	end
	show_image(dw.anchor);
	dw.titlebar:hide();
	hide_image(space.selected.border);

-- need to hook switching between workspaces to enable things like the sbar
	dw.fullscreen = true;
	space.mode_hook = drop_fullscreen;
	space.switch_hook = switch_fullscreen;

-- drop border, titlebar, ...
	move_image(dw.canvas, 0, 0);
	move_image(dw.anchor, 0, 0);
	dw.max_w = dw.wm.width;
	dw.max_h = dw.wm.height;

-- and send relayout / fullscreen hints that match the size of the WM
	dw:resize(dw.wm.width, dw.wm.height);
end

-- floating mode has different rulesets for spawning, sizing and all windows
-- are "unlocked" for custom drag-resize
local function set_float(space)
	if (space.in_float) then
		return;
	end

	space.reassign_hook = reassign_float;
	space.mode_hook = drop_float;
	space.in_float = true;

	local tbl = linearize(space);
	if (space.layouter and space.layouter.resize(space, tbl)) then
		return;
	end

	for i,v in ipairs(tbl) do
		local props = image_storage_properties(v.canvas);
		local neww;
		local newh;
-- work with relative position / size to handle migrate or resize
		if (v.last_float) then
			neww = space.wm.width * v.last_float.width;
			newh = space.wm.height * v.last_float.height;
			v.x = space.wm.width * v.last_float.x;
			v.y = space.wm.height * v.last_float.y;

			move_image(v.anchor, v.x, v.y,
				wnd_animation_time(v, v.anchor, false, true));
-- if window havn't been here before, clamp
		else
			neww = props.width + v.pad_left + v.pad_right;
			newh = props.height + v.pad_top + v.pad_bottom;
			neww = (space.wm.width < neww and space.wm.width) or neww;
			newh = (space.wm.height < newh and space.wm.height) or newh;
		end

-- doesn't really matter here as we run with "force" flag
		v.max_w = neww;
		v.min_h = newh;

		v:resize(neww, newh, true);
	end
end

local function set_tile(space, repos)
	local wm = space.wm;
	if (not gconfig_get("sbar_hud")) then
		wm.statusbar:show();
		wm.statusbar.hidden_sb = false;
	end
	if (space.layouter) then
		local tbl = linearize(space);
		if (space.layouter.resize(space, tbl)) then
			return;
		end
	end
	level_resize(space, 0, 0, wm.width, wm.height - sbar_geth(wm), repos);
end

local space_handlers = {
	tile = set_tile,
	float = set_float,
	fullscreen = set_fullscreen,
	tab = set_tab,
	vtab = set_vtab
};

local function workspace_destroy(space)
	if (space.mode_hook) then
		space:mode_hook();
		space.mode_hook = nil;
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
	if (space_handlers[mode] == nil or mode == space.mode) then
		return;
	end

-- cleanup to revert to the normal stable state (tiled)
	if (space.mode_hook) then
		space:mode_hook();
		space.mode_hook = nil;
	end

-- for float, first reset to tile then switch to get a fair distribution
-- another option would be to first set their storage dimensions and then
-- force
	if (mode == "float" and space.mode ~= "tile" and not space.layouter) then
		space.layouter = nil;
		space.mode = "tile";
		space:resize();
	end

	space.last_mode = space.mode;
	space.mode = mode;

-- enforce titlebar changes (some modes need them to work..)
	local lst = linearize(space);
	for k,v in ipairs(lst) do
		v:set_title();
	end

	space:resize();
	tiler_statusbar_update(space.wm);
end

local function workspace_resize(space, external)
	if (space_handlers[space.mode]) then
		space_handlers[space.mode](space, external);
	end

	if (valid_vid(space.background)) then
		resize_image(space.background, space.wm.width, space.wm.height);
	end
end

local function workspace_label(space, lbl)
	local ind = 1;
	repeat
		if (space.wm.spaces[ind] == space) then
			break;
		end
		ind = ind + 1;
	until (ind > 10);

	space.label = lbl;
	tiler_statusbar_update(space.wm);
end

local function workspace_empty(wm, i)
	return (wm.spaces[i] == nil or
		(#wm.spaces[i].children == 0 and wm.spaces[i].label == nil));
end

local function workspace_save(ws, shallow)

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

	if (shallow) then
		return;
	end
-- depth serialization and metastructure missing
end

local function workspace_background(ws, bgsrc, generalize)
	if (bgsrc == ws.wm.background_name and valid_vid(ws.wm.background_id)) then
		bgsrc = ws.wm.background_id;
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
			ws.background = null_surface(ws.wm.width, ws.wm.height);
			shader_setup(ws.background, "simple", "noalpha");
		end
		resize_image(ws.background, ws.wm.width, ws.wm.height);
		link_image(ws.background, ws.anchor);
		local sb_sz = sbar_geth(ws.wm);
		move_image(ws.background, 0,
			gconfig_get("sbar_pos") == "top" and -sb_sz or 0);
		if (crossfade) then
			blend_image(ws.background, 0.0, ttime);
		end
		blend_image(ws.background, 1.0, ttime);
		if (valid_vid(src)) then
			image_sharestorage(src, ws.background);
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
				ws.wm.background_name = bgsrc;
				store_key(string.format("ws_%s_bg", ws.wm.name), bgsrc);
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

create_workspace = function(wm, anim)
	local res = {
		activate = workspace_activate,
		deactivate = workspace_deactivate,
		resize = workspace_resize,
		destroy = workspace_destroy,
		migrate = workspace_migrate,
		save = workspace_save,
		linearize = linearize,
		lost = workspace_lost,

-- different layout modes, patch here and workspace_set to add more
		fullscreen = function(ws) workspace_set(ws, "fullscreen"); end,
		tile = function(ws) workspace_set(ws, "tile"); end,
		tab = function(ws) workspace_set(ws, "tab"); end,
		vtab = function(ws) workspace_set(ws, "vtab"); end,
		float = function(ws) workspace_set(ws, "float"); end,

		set_label = workspace_label,
		set_background = workspace_background,

-- can be used for clipping / transitions
		anchor = null_surface(wm.width, wm.height),
		mode = "tile",
		name = "workspace_" .. tostring(ent_count);
		insert = "h",
		children = {},
		weight = 1.0,
		vweight = 1.0
	};
	image_tracetag(res.anchor, "workspace_anchor");
	show_image(res.anchor);
	link_image(res.anchor, wm.anchor);
	ent_count = ent_count + 1;
	res.wm = wm;
	workspace_set(res, gconfig_get("ws_default"));
	if (wm.background_name) then
		res:set_background(wm.background_name);
	end
	res:activate(anim);

	if (gconfig_get("ws_preview")) then
		local scalef = gconfig_get("ws_preview_scale");
		res.preview = alloc_surface(scalef * wm.width, scalef * wm.height);
	end
	return res;
end

local function wnd_merge(wnd)
	if (not wnd.space or
		(wnd.space.layouter and wnd.space.layouter.block_merge)) then
		return;
	end

	local i = 1;
	while (i ~= #wnd.parent.children) do
		if (wnd.parent.children[i] == wnd) then
			break;
		end
		i = i + 1;
	end

	if (i < #wnd.parent.children) then
		for j=i+1,#wnd.parent.children do
			table.insert(wnd.children, wnd.parent.children[j]);
			wnd.parent.children[j].parent = wnd;
		end
		for j=#wnd.parent.children,i+1,-1 do
			table.remove(wnd.parent.children, j);
		end
	end

	wnd.space:resize();
end

local function wnd_collapse(wnd)
	if (not wnd.space or
		(wnd.space.layouter and wnd.space.layouter.block_collapse)) then
		return;
	end

	local i = table.find_i(wnd.parent.children, wnd) + 1;
	for k,v in ipairs(wnd.children) do
		table.insert(wnd.parent.children, i, v);
		v.parent = wnd.parent;
	end
	wnd.children = {};
	wnd.space:resize();
end

local function apply_scalemode(wnd, mode, src, props, maxw, maxh, force)
	local outw = 1;
	local outh = 1;

	if ((wnd.scalemode == "normal" or
		wnd.scalemode == "client") and not force) then
		if (props.width > 0 and props.height > 0) then
			outw = props.width < maxw and props.width or maxw;
			outh = props.height < maxh and props.height or maxh;
		end

	elseif (force or wnd.scalemode == "stretch") then
		outw = maxw;
		outh = maxh;

	elseif (wnd.scalemode == "aspect") then
		local ar = props.width / props.height;
		local wr = props.width / maxw;
		local hr = props.height/ maxh;

		outw = hr > wr and maxh * ar or maxw;
		outh = hr < wr and maxw / ar or maxh;
	end

	outw = math.floor(outw);
	outh = math.floor(outh);
	reset_image_transform(src);

-- for normal where the source is larger than the alloted slot
	if (wnd.autocrop) then
		local ip = image_storage_properties(src);
		image_set_txcos_default(src, wnd.origo_ll);
		local ss = outw / ip.width;
		local st = outh / ip.height;
		image_scale_txcos(src, ss, st);
	elseif (wnd.in_drag_rz) then
	end
	resize_image(src, outw, outh,
		wnd_animation_time(wnd, src, false, false));

	if (wnd.filtermode) then
		image_texfilter(src, wnd.filtermode);
	end

	return outw, outh;
end

local function wnd_effective_resize(wnd, neww, newh, force)
	wnd:resize(neww + wnd.pad_left + wnd.pad_right,
		newh + wnd.pad_top + wnd.pad_bottom, force);
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

	if (wnd.centered and wnd.space.mode ~= "float") then
		if (wnd.space.mode == "tile") then
			move_image(wnd.anchor,
				wnd.x + math.floor(0.5 * (wnd.max_w - wnd.width)),
				wnd.y + math.floor(0.5 * (wnd.max_h - wnd.height)),
				wnd_animation_time(wnd, wnd.anchor, false, true)
			);

		elseif (wnd.space.mode == "tab" or wnd.space.mode == "vtab") then
			move_image(wnd.anchor, 0, 0);
		end

		if (wnd.fullscreen) then
			move_image(wnd.canvas, math.floor(0.5*(wnd.wm.width - wnd.effective_w)),
				math.floor(0.5*(wnd.wm.height - wnd.effective_h)));
		end
	else
		move_image(wnd.anchor, wnd.x, wnd.y,
			wnd_animation_time(wnd, wnd.anchor, false, true));
	end
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
	if (wnd.in_drag_rz and not force or not valid_vid(wnd.canvas)
		or not wnd.space) then
		return false;
	end

-- first clamp
	neww = wnd.wm.min_width > neww and wnd.wm.min_width or neww;
	newh = wnd.wm.min_height > newh and wnd.wm.min_height or newh;
	if (not force) then
		neww = wnd.max_w > neww and neww or wnd.max_w;
		newh = wnd.max_h > newh and newh or wnd.max_h;
	end

	local props = image_storage_properties(wnd.canvas);

-- to save space for border width, statusbar and other properties
	local decw = wnd.pad_left + wnd.pad_right;
	local dech = wnd.pad_top + wnd.pad_bottom;

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

	force = force and force or (wnd.space.mode == "float" and true) or false;

-- now we know dimensions of the window in regards to its current tiling cell
-- etc. so we can resize the border accordingly (or possibly cascade weights)
	if (force) then
		wnd.effective_w, wnd.effective_h = apply_scalemode(wnd,
			wnd.scalemode, wnd.canvas, props, neww, newh,
			force
		);
		wnd.width = neww + decw;
		wnd.height = newh + dech;
	else
		wnd.effective_w, wnd.effective_h = apply_scalemode(wnd,
			wnd.scalemode, wnd.canvas, props, wnd.max_w-decw, wnd.max_h-dech,
			force
		);
		wnd.width = wnd.effective_w + decw;
		wnd.height = wnd.effective_h + dech;
	end

-- update decoration
	local bw = wnd.border_w;
	local tbh = tbar_geth(wnd);
	local size_decor = function(w, h)
		local interp = nil;
		resize_image(wnd.anchor, w, h);
		wnd.titlebar:move(bw, bw);
		wnd.titlebar:resize(w - bw - bw, tbh,
			wnd_animation_time(wnd, wnd.anchor, true, false));
		resize_image(wnd.border, w, h,
			wnd_animation_time(wnd, wnd.border, true, false));
	end

-- still up for experimentation, but this method favors the canvas size rather
-- than the allocated tile size
	size_decor(wnd.effective_w + bw + bw, wnd.effective_h + tbh + bw + bw);
	wnd.pad_top = bw + tbh;
	move_image(wnd.canvas, wnd.pad_left, wnd.pad_top);
	wnd:reposition();

-- delegate resize event to allow some "white lies"
	if (wnd.space.layouter and wnd.space.layouter.block_rzevent) then
		wnd.space.layouter.resize(wnd.space, nil, true, wnd,
			function(neww, newh, effw, effh)
				run_event(wnd, "resize", neww, newh, effw, effh);
			end
		);
	elseif (not maskev) then
		run_event(wnd, "resize", neww, newh, wnd.effective_w, wnd.effective_h);
	end
end

-- sweep all windows, calculate center-point distance,
-- and weight based on desired direction (no diagonals)
local function find_nearest(wnd, wx, wy, rec)
	if (not wnd.space) then
		return;
	end

	local lst = linearize(wnd.space);
	local ddir = {};

	local cp_xy = function(vid)
		local props = image_surface_resolve_properties(vid);
		return (props.x + 0.5 * props.width), (props.y + 0.5 * props.height);
	end

	local bp_x, bp_y = cp_xy(wnd.canvas);

-- only track distances for windows in the desired direction (wx, wy)
	local shortest;

	for k,v in ipairs(lst) do
		if (v ~= wnd) then
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

local function wnd_next(mw, level)
	if (mw.fullscreen or not mw.space) then
		return;
	end

	local mwm = mw.space.mode;
	if (mwm == "float") then
		wnd = level and find_nearest(mw, 0, 1) or find_nearest(mw, 1, 0);
		if (wnd) then
			wnd:select();
			return;
		end

	elseif (mwm == "tab" or mwm == "vtab") then
		local lst = linearize(mw.space);
		local ind = table.find_i(lst, mw);
		ind = ind == #lst and 1 or ind + 1;
		lst[ind]:select();
		return;
	end

	if (level) then
		if (#mw.children > 0) then
			mw.children[1]:select();
			return;
		end
	end

	local i = 1;
	while (i < #mw.parent.children) do
		if (mw.parent.children[i] == mw) then
			break;
		end
		i = i + 1;
	end

	if (i == #mw.parent.children) then
		if (mw.parent.parent ~= nil) then
			return wnd_next(mw.parent, false);
		else
			i = 1;
		end
	else
		i = i + 1;
	end

	mw.parent.children[i]:select();
end

local function wnd_prev(mw, level)
	if (mw.fullscreen or not mw.space) then
		return;
	end

	local mwm = mw.space.mode;
	if (mwm == "float") then
		wnd = level and find_nearest(mw, 0, -1) or find_nearest(mw, -1, 0);
		if (wnd) then
			wnd:select();
			return;
		end

	elseif (mwm == "tab" or mwm == "vtab" or mwm == "float") then
		local lst = linearize(mw.space);
		local ind = table.find_i(lst, mw);
		ind = ind == 1 and #lst or ind - 1;
		lst[ind]:select();
		return;
	end

	if (level or mwm == "tab" or mwm == "vtab") then
		if (mw.parent.select) then
			mw.parent:select();
			return;
		end
	end

	local ind = 1;
	for i,v in ipairs(mw.parent.children) do
		if (v == mw) then
			ind = i;
			break;
		end
	end

	if (ind == 1) then
		if (mw.parent.parent) then
			mw.parent:select();
		else
			mw.parent.children[#mw.parent.children]:select();
		end
	else
		ind = ind - 1;
		mw.parent.children[ind]:select();
	end
end

local function wnd_reassign(wnd, ind, ninv)
-- for reassign by name, resolve to index
	local newspace = nil;
	local wm = wnd.wm;
	if (not wnd.space) then
		return;
	end

	if (type(ind) == "string") then
		for k,v in pairs(wm.spaces) do
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
				wm.selected = nil;
			end
		end
	end
-- create if it doesn't exist
	local oldspace_ind = wm.active_space;
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

	if (oldspace.reassign_hook and newspace.mode ~= oldspace.mode) then
		oldspace:reassign_hook(wnd);
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
	wm.active_space = oldspace_ind;
	if not (oldspace.layouter and oldspace.layouter.lost(oldspace, wnd)) then
		oldspace:resize();

-- protect against layouter breaking selection
		if ((not oldspace.selected or not wm.selected
			or wm.selected ~= oldspace.selected) and #oldspace.children > 0) then
			oldspace.children[#oldspace.children]:select();
		end
	end
end

local function wnd_move(wnd, dx, dy, align, abs, now)
	if (not wnd.space or wnd.space.mode ~= "float") then
		return;
	end

	local time = now and 0 or wnd_animation_time(wnd, wnd.anchor, false, true);

	if (abs) then
		move_image(wnd.anchor, dx, dy, time);
		return;
	end

	if (align) then
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
		move_image(wnd.anchor, wnd.x, wnd.y, time);
	else
		nudge_image(wnd.anchor, dx, dy, time);
	end
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
		anchor = null_surface(1, 1)
	};
	res.canvas = res.anchor;

	if (not valid_vid(res.anchor)) then
		return;
	end
	local dst = wnd;

	if (chain) then
		if (#wnd.popups > 0) then
			dst = wnd.popups[#wnd.popups];
		end
	end

-- destroying an earlier popup should cascade down the chain
	res.destroy = function(pop)
		delete_image(vid);
		mouse_droplistener(pop);
		for i=#wnd.popups, pop.index, -1 do
			wnd:drop_popup();
		end
	end

-- we chain onwards so the res table exposes mostly the same entry points
-- as a norml window
	res.add_popup = function(pop, source, dcb)
		return wnd:add_popup(source, dcb);
	end

	res.focus = function(pop, state)
		wnd.input_focus = pop;
	end

	res.show = function(pop)
		blend_image(vid, 1.0, gconfig_get("animation"));
	end

	res.hide = function(pop)
		blend_image(vid, 0.0, gconfig_get("animation"));
	end

-- FIXME: take window constraints into account, can test with mouse cursor
	res.reposition = function(pop, x1, y1, x2, y2, bias, chain)
		local ap = bias == 0 and (#wnd.popups > 0 and 3 or 1) or bias;
			ap = bias_lut[ap] and bias_lut[ap] or ANCHOR_UL;
		link_image(vid, res.anchor, ap);
		move_image(res.anchor, x1, y1);
	end

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

	return res;
end

local function wnd_droppopup(wnd, all)
	if (all) then
		for i=#wnd.popups,1,-1 do
			v = wnd.popups[i];
			if (v.on_destroy) then
				v:on_destroy();
			end
			delete_image(v.anchor);
			mouse_droplistener(v);
		end
		wnd.popups = {};
		wnd.input_focus = nil;

	elseif (#wnd.popups > 0) then
		local pop = wnd.popups[#wnd.popups];
		if (pop.on_destroy) then
			pop:on_destroy();
		end
		expire_image(pop.anchor, gconfig_get("animation"));
		blend_image(pop.anchor, 0.0, gconfig_get("animation"));
		mouse_droplistener(pop);
		table.remove(wnd.popups, #wnd.popups);
		if (wnd.input_focus == pop) then
			wnd.input_focus = wnd.popups[#wnd.popups];
		end
	end
end

--
-- re-adjust each window weight, they are not allowed to go down to negative
-- range and the last cell will always pad to fit
--
local function wnd_grow(wnd, w, h)
	if (not wnd.space or wnd.space.mode == "float") then
		wnd:resize(wnd.width + (wnd.wm.width*w),
			wnd.height + (wnd.wm.height*h), true);
		return;
	end

-- "grow" in float mode is different as it doesn't affect weights
	if (wnd.space.mode ~= "tile" or (wnd.space.layouter and
		wnd.space.layouter.block_grow)) then
		return;
	end

-- vertical weight is simpler, only got "parent" and "me", rest is subdivided
	if (h ~= 0) then
		wnd.vweight = wnd.vweight + h;
		wnd.parent.vweight = wnd.parent.vweight - h;
	end

	if (w ~= 0) then
		wnd.weight = wnd.weight + w;
-- re-balance weight among siblings, take/give what wnd just gained / lost
		if (#wnd.parent.children > 1) then
			local ws = w / (#wnd.parent.children - 1);
			for i=1,#wnd.parent.children do
				if (wnd.parent.children[i] ~= wnd) then
					wnd.parent.children[i].weight = wnd.parent.children[i].weight - ws;
				end
			end
		end
	end

	wnd.space:resize();
end

local function wnd_title(wnd, title)
	if (title) then
		wnd.title = title;
	end

-- based on new title/ font, apply pattern and set to fill region
	local dsttbl = {gconfig_get("tbar_textstr")};
	wnd.title_text = suppl_ptn_expand(dsttbl, gconfig_get("titlebar_ptn"), wnd);
	wnd.titlebar:update("center", 1, dsttbl);

-- override if the mode requires it
	local hide_titlebar = wnd.hide_titlebar;

	if (wnd.space and not tbar_mode(wnd.space.mode)) then
		hide_titlebar = false;
	end

-- reflect titlebar state in position / padding
	if (hide_titlebar) then
		wnd.titlebar:hide();
		wnd.pad_top = wnd.border_w;
		wnd:resize(wnd.width, wnd.height);
	else
		wnd.pad_top = wnd.border_w + tbar_geth(wnd);
		wnd.titlebar:show();
	end

-- not all windows have  a workspace, but if we do, we might need relayouting
	if (wnd.space) then
		wnd.space:resize(true);
	end
end

local function convert_mouse_xy(wnd, x, y, rx, ry)
-- note, this should really take viewport into account (if provided), when
-- doing so, move this to be part of fsrv-resize and manual resize as this is
-- rather wasteful.

-- first, remap coordinate range (x, y are absolute)
	local aprop = image_surface_resolve_properties(wnd.canvas);
	local locx = x - aprop.x;
	local locy = y - aprop.y;

	if (wnd.mouse_remap_range) then
		locx = (wnd.mouse_remap_range[1] * aprop.width) +
			locx * wnd.mouse_remap_range[3];
		locy = (wnd.mouse_remap_range[2] * aprop.height) +
			locy * wnd.mouse_remap_range[4];
	end

-- take server-side scaling into account
	local res = {};
	local sprop = image_storage_properties(
		valid_vid(wnd.external) and wnd.external or wnd.canvas);
	local sfx = sprop.width / aprop.width;
	local sfy = sprop.height / aprop.height;
	local lx = sfx * locx;
	local ly = sfy * locy;

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

local function wnd_mousebutton(ctx, ind, pressed, x, y)
	local wnd = ctx.tag;
	if (wnd.wm.selected ~= wnd) then
		return;
	elseif (#wnd.popups > 0) then
		wnd:drop_popup(true);
		return;
	end

	output_mouse_devent({
		active = pressed, devid = 0, subid = ind}, wnd);
end

local function wnd_mouseclick(ctx, vid)
	local wnd = ctx.tag;

	if (wnd.wm.selected ~= wnd and
		gconfig_get("mouse_focus_event") == "click") then
		wnd:select(nil, true);
		return;
	elseif (#wnd.popups > 0) then
		wnd:drop_popup(true);
		return;
	end

	if (not (vid == wnd.canvas and
		valid_vid(wnd.external, TYPE_FRAMESERVER))) then
		return;
	end

	output_mouse_devent({
		active = true, devid = 0, subid = 0, gesture = true, label = "click"}, wnd);
end

local function wnd_toggle_maximize(wnd)
	if (wnd.float_dim) then
		wnd.x = wnd.float_dim.x * wnd.wm.width;
		wnd.y = wnd.float_dim.y * wnd.wm.height;
		move_image(wnd.anchor, wnd.x, wnd.y,
			wnd_animation_time(wnd, wnd.anchor, false, true));
		wnd:resize(wnd.float_dim.w * wnd.wm.width,
			wnd.float_dim.h * wnd.wm.height, true);
		wnd.float_dim = nil;
	else
		local cur = {};
		local props = image_surface_resolve_properties(wnd.anchor);
		cur.x = props.x / wnd.wm.width;
		cur.y = props.y / wnd.wm.height;
		cur.w = wnd.width / wnd.wm.width;
		cur.h = wnd.height / wnd.wm.height;
		wnd.float_dim = cur;
		wnd.x = 0;
		wnd.y = 0;
		move_image(wnd.anchor, wnd.x, wnd.y,
			wnd_animation_time(wnd, wnd.anchor, false, true));
		wnd:resize(wnd.wm.width, wnd.wm.height, true);
	end
end

local function wnd_mousedblclick(ctx)
	local wnd = ctx.tag;

	if (#wnd.popups > 0) then
		wnd:drop_popup(true);
		return;
	end

	output_mouse_devent({
		active = true, devid = 0, subid = 0,
		label = "dblclick", gesture = true}, ctx.tag
	);
end

local function wnd_mousepress(ctx)
	local wnd = ctx.tag;

	if (wnd.wm.selected ~= wnd) then
		if (gconfig_get("mouse_focus_event") == "click") then
			wnd:select(nil, true);
		end
		return;
	end

	if (not wnd.space or wnd.space.mode ~= "float") then
		return;
	end
end

local function wnd_mousemotion(ctx, x, y, rx, ry)
	local wnd = ctx.tag;
	if (wnd.mouse_lock_center) then
		local rt = {
			kind = "analog",
			mouse = true,
			relative = true,
			devid = 0,
			subid = 0;
			samples = {rx}
		};
		target_input(wnd.external, rt);
		rt.subid = 1;
		rt.samples = {ry};
		target_input(wnd.external, rt);
		return;
	end

	local mv = convert_mouse_xy(wnd, x, y, rx, ry);
	local iotbl = {
		kind = "analog",
		mouse = true,
		devid = 0,
		subid = 0,
		samples = {mv[1], mv[2]}
	};
	local iotbl2 = {
		kind = "analog",
		mouse = true,
		devid = 0,
		subid = 1,
		samples = {mv[3], mv[4]}
	};

	if (not valid_vid(wnd.external, TYPE_FRAMESERVER)) then
		return;
	end

-- with rate limited mouse events (those 2khz gaming mice that likes
-- to saturate things even when not needed), we accumulate relative samples
	if (not wnd.rate_unlimited) then
		local ep = EVENT_SYNCH[wnd.external] and EVENT_SYNCH[wnd.external].pending;
		if (ep) then
			ep[1].samples[1] = mv[1];
			ep[1].samples[2] = ep[1].samples[2] + mv[2];
			ep[2].samples[1] = mv[3];
			ep[2].samples[2] = ep[2].samples[2] + mv[4];
		else
			EVENT_SYNCH[wnd.external].pending = {iotbl, iotbl2};
		end
	else
		target_input(wnd.external, iotbl);
		target_input(wnd.external, iotbl2);
	end
end

local function dist(x, y)
	return math.sqrt(x * x + y * y);
end

-- returns: [ul, u, ur, r, lr, l, ll, l]
local function wnd_borderpos(wnd)
	local x, y = mouse_xy();
	local props = image_surface_resolve_properties(wnd.anchor);

-- hi-clamp radius, select corner by distance (priority)
	local cd_ul = dist(x-props.x, y-props.y);
	local cd_ur = dist(props.x + props.width - x, y - props.y);
	local cd_ll = dist(x-props.x, props.y + props.height - y);
	local cd_lr = dist(props.x + props.width - x, props.y + props.height - y);

	local lim = 16 < (0.5 * props.width) and 16 or (0.5 * props.width);
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

local function wnd_mousehover(ctx, vid)
	local wnd = ctx.tag;
-- this event can be triggered slightly deferred and race against destroy
	if (not wnd.wm) then
		return;
	end

	if (wnd.wm.selected ~= ctx.tag and
		gconfig_get("mouse_focus_event") == "hover") then
		wnd:select(nil, true);
	end
-- good place for tooltip hover hint
end

local function wnd_mouseover(ctx, vid)
--focus follows mouse
	local wnd = ctx.tag;

	if (wnd.wm.selected ~= ctx.tag and
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
	shader_setup(wnd.border, "ui", "border", "alert");
end

local function wnd_prefix(wnd, prefix)
	wnd.prefix = prefix and prefix or "";
	wnd:set_title();
end

local function wnd_ident(wnd, ident)
	wnd.ident = ident and ident or "";
	wnd:set_title();
end

local function wnd_addhandler(wnd, ev, fun)
	assert(ev);
	if (wnd.handlers[ev] == nil) then
		warning("tried to add handler for unknown event: " .. ev);
		return;
	end
	table.remove_match(wnd.handlers[ev], fun);
	table.insert(wnd.handlers[ev], fun);
end

local function wnd_drophandler(wnd, ev, fun)
	assert(ev);
	if (wnd.handlers[ev] == nil) then
		warning("tried to add handler for unknown event: " .. ev);
		return;
	end
	table.remove_match(wnd.handlers[ev], fun);
end

local function wnd_dispmask(wnd, val, noflush)
	wnd.dispmask = val;

	if (not noflush and valid_vid(wnd.external, TYPE_FRAMESERVER)) then
		target_displayhint(wnd.external, 0, 0, wnd.dispmask);
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

-- select next in line
	wnd:prev();
	if (wnd.wm.selected == wnd) then
		if (wnd.children[1] ~= nil) then
			wnd.children[1]:select();
		else
			wnd.wm.selected = nil;
		end
	end

-- switch rendertarget
	for i,v in ipairs(get_hier(wnd.anchor)) do
		rendertarget_attach(tiler.rtgt_id, v, RENDERTARGET_DETACH);
	end
	rendertarget_attach(tiler.rtgt_id, wnd.anchor, RENDERTARGET_DETACH);

-- change association with wm and relayout old one
	if (not wnd.space) then
		return;
	end

	local oldsp = wnd.space;
	table.remove_match(wnd.wm.windows, wnd);
	wnd.wm = tiler;
	oldsp:resize();

-- make sure titlebar sizes etc. match
	wnd:rebuild_border(gconfig_get("borderw"));

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
	if (disptbl and valid_vid(wnd.external, TYPE_FRAMESERVER)) then
		target_displayhint(wnd.external,
			0, 0, wnd.dispmask, get_disptbl(wnd, disptbl));
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
		suspend_target(wnd.external);
		wnd.suspended = true;
		shader_setup(wnd.border, "ui", "border", "suspended");
		wnd.titlebar:switch_state("suspended", true);
	else
		resume_target(wnd.external);
		wnd.suspended = nil;
		shader_setup(wnd.border, "ui", "border", sel and "active" or "inactive");
		wnd.titlebar:switch_state(sel and "active" or "inactive");
	end
end

local function wnd_tofront(wnd)
	if (not wnd.space) then
		return;
	end

	local wm = wnd.wm;
	local wnd_i = table.find_i(wm.windows, wnd);
	if (wnd_i) then
		table.remove(wm.windows, wnd_i);
	end

	table.insert(wm.windows, wnd);
	for i=1,#wm.windows do
		order_image(wm.windows[i].anchor, i * WND_RESERVED);
	end

	order_image(wm.order_anchor, #wm.windows * 2 * WND_RESERVED);
end

local function wnd_rebuild(v, bw)
	local tbarh = tbar_geth(v);
	if (v.hide_border) then
		bw = 0;
		hide_image(v.border);
	else
		show_image(v.border);
	end

	v.pad_left = bw;
	v.pad_right = bw;
	v.pad_top = bw + tbarh;
	v.pad_bottom = bw;
	v.border_w = bw;

	if (v.space.mode == "tile" or v.space.mode == "float") then
		v.titlebar:move(v.border_w, v.border_w);
		v.titlebar:resize(v.width - v.border_w * 2, tbarh);
		link_image(v.canvas, v.anchor);
		move_image(v.canvas, v.pad_left, v.pad_top);
		resize_image(v.canvas, v.effective_w, v.effective_h);
	end
end

local titlebar_mh = {
	over = function(ctx)
		if (ctx.tag.space.mode == "float") then
			mouse_switch_cursor("grabhint");
		end
	end,
	out = function(ctx)
		mouse_switch_cursor("default");
	end,
	press = function(ctx)
		ctx.tag:select();
		if (ctx.tag.space.mode == "float") then
			mouse_switch_cursor("drag");
		end

		if (ctx.tag.space.mode == "tile") then
			mouse_switch_cursor("drag");
		end
	end,
	release = function(ctx)
		if (ctx.tag.space.mode == "tile") then
			mouse_switch_cursor("grabhint");
		end
	end,
	drop = function(bar)
	end,
	drag = function(ctx, vid, dx, dy)
		local tag = ctx.tag;
-- TODO: possible to drag outside client area
		if (tag.space.mode == "float") then
			tag.x = tag.x + dx;
			tag.y = tag.y + dy;
			move_image(tag.anchor, tag.x, tag.y);
		end
-- possibly check for other window in tile hierarchy based on
-- polling mouse cursor, and do a window swap
	end,
	click = function(ctx)
	end,
	dblclick = function(ctx)
		local tag = ctx.tag;
		if (tag.space.mode == "float") then
			tag:toggle_maximize();
		end
	end
};

local border_mh = {
	over = function(ctx)
		if (ctx.tag.space.mode == "float") then
			local p = wnd_borderpos(ctx.tag);
			local ent = dir_lut[p];
			ctx.mask = ent[2];
			mouse_switch_cursor(ent[1]);
		end
	end,
	out = function(ctx)
		mouse_switch_cursor("default");
	end,
	drag = function(ctx, vid, dx, dy)
		local wnd = ctx.tag;
		if (wnd.space.mode == "float" and ctx.mask) then
			wnd.in_drag_rz = true;
			wnd.x = wnd.x + dx * ctx.mask[3];
			wnd.y = wnd.y + dy * ctx.mask[4];
			move_image(wnd.anchor, wnd.x, wnd.y);
			wnd:resize(wnd.width+dx*ctx.mask[1], wnd.height+dy*ctx.mask[2], true, false);
		end
	end,
	drop = function(ctx)
		local wnd = ctx.tag;
		if (wnd.sz_delta) then
			wnd:resize_effective(
				wnd.effective_w + (wnd.effective_w % wnd.sz_delta[1]),
				wnd.effective_h + (wnd.effective_h % wnd.sz_delta[2]), true);
		else
			wnd:resize(wnd.width, wnd.height, true);
		end
		ctx.tag.in_drag_rz = false;
	end
};

local canvas_mh = {
	motion = function(ctx, vid, ...)
		if (valid_vid(ctx.tag.external, TYPE_FRAMESERVER)) then
			wnd_mousemotion(ctx, ...);
		end
	end,

	press = wnd_mousepress,

	over = function(ctx)
		local tag = ctx.tag;
		if (tag.wm.selected ~= tag and gconfig_get(
			"mouse_focus_event") == "motion") then
			tag:select();
		end
		canvas_mouse_activate(ctx.tag);
	end,

	out = function(ctx)
		mouse_hidemask(true);
		mouse_show();
		mouse_switch_cursor();
		mouse_hidemask(false);
	end,

	button = function(ctx, vid, ...)
		if (valid_vid(ctx.tag.external, TYPE_FRAMESERVER)) then
			wnd_mousebutton(ctx, ...);
		end
	end,

	dblclick = function(ctx)
		if (valid_vid(ctx.tag.external, TYPE_FRAMESERVER)) then
			wnd_mousedblclick(ctx);
		end
	end
};

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
end

-- attach a window to the active workspace, this is a one-time
local function wnd_ws_attach(res)
	local wm = res.wm;
	res.ws_attach = nil;
	res.attach_time = CLOCK;

	if (wm.spaces[wm.space_ind] == nil) then
		wm.spaces[wm.space_ind] = create_workspace(wm);
	end

-- actual dimensions depend on the state of the workspace we'll attach to
	local space = wm.spaces[wm.space_ind];
	res.space_ind = wm.space_ind;
	res.space = space;
	link_image(res.anchor, space.anchor);

	if (space.mode == "float") then
-- this should be improved by allowing w/h/x/y overrides based on history
-- for the specific source or the class it belongs to
		local props = image_storage_properties(res.canvas);
		res.width = props.width;
		res.height = props.height;
		if (res.defer_x) then
			res.x = res.defer_x;
			res.y = res.defer_y;
			res.defer_x = nil;
			res.defer_y = nil;
		else
			res.x, res.y = mouse_xy();
		end
		move_image(res.anchor, res.x, res.y);
	else
	end

-- same goes for hierarchical position and relatives
	local insert = space.layouter and space.layouter.added(space,res);
	if (not insert) then
		if (not wm.selected or wm.selected.space ~= space) then
			table.insert(space.children, res);
			res.parent = space;
		elseif (space.insert == "h") then
			if (wm.selected.parent) then
				local ind = table.find_i(wm.selected.parent.children, wm.selected);
				table.insert(wm.selected.parent.children, ind+1, res);
				res.parent = wm.selected.parent;
			else
				table.insert(space.children, res, ind);
				res.parent = space;
			end
		else
			table.insert(wm.selected.children, res);
			res.parent = wm.selected;
		end
	end

	if (not(wm.selected and wm.selected.fullscreen)) then
		show_image(res.anchor);
		if (not insert) then
			res:select();
		end
		space:resize();
	else
		shader_setup(res.border, "ui", "border", "inactive");
	end

-- trigger the resize cascade now that we know the layout..
	if (res.space.mode == "float") then
		move_image(res.anchor, mouse_xy());
		res:resize(res.width, res.height);
	end

	wm:on_wnd_create(res);
	return res;
end

local function wnd_inputtable(wnd, iotbl, multicast)
	if valid_vid(wnd.external) then
		target_input(wnd.external, iotbl);
	end

	if (multicast or wnd.multicast) then
		for i,v in ipairs(wnd.children) do
			wnd_inputtable(v, iotbl, true);
		end
	end
end

--
-- very special kind of window, it should occupy the same size,
-- position as the dst but be tied together lifespan, block a number
-- of menu operations (reassign, etc.)
--
local function wnd_forcedep(src, dst)
	src.parent = dst;
	src.space = dst.space;
	src.dependent = true;
	dst:add_handler("resize", function() end);
	dst:add_handler("move", function() end);

-- all that uses selected.children and selected.parent matter
end

-- build an orphaned window that isn't connected to a real workspace yet,
-- but with all the expected members setup-up and in place. This means that
-- some operations will be no-ops and the window will not appear in normal
-- iterators.
local wnd_setup = function(wm, source, opts)
	if (opts == nil) then opts = {}; end
	local bw = gconfig_get("borderw");
	local res = {
		wm = wm,
		anchor = null_surface(1, 1),
-- we use fill surfaces rather than color surfaces to get texture coordinates
		border = fill_surface(1, 1, 255, 255, 255),
		canvas = source,
		gain = 1.0 * gconfig_get("global_gain"),
		popups = {},

-- hierarchies used for tile layout
		children = {},

-- specific event / keysym bindings
		labels = {},
		dispatch = {},

-- dependent subwindows, these are by default hidden and share the same
-- confines / attachments as the main window (and thus receives the same hints)
-- but can be swapped / cycled
		dependents = {},

-- register:able event handlers to relate one window to another
		relatives = {},
		handlers = {
			destroy = {},
			register = {},
			resize = {},
			gained_relative = {},
			lost_relative = {},
			select = {},
			deselect = {},
			mouse = {}
		},

-- padding is split into a custom [variable] and a border- area [calculated]
-- based on which decorations are available and so on. The pad_[lrtd] are the
-- resolved values and will be updated when decorations are rebuilt etc.
		pad_left = bw,
		pad_right = bw,
		pad_top = bw,
		pad_bottom = bw,
		pad_custom = {0, 0, 0, 0},

-- note on multi-PPCM:
-- scale factor is manipulated by the display manager in order to take pixel
-- density into account, so when a window is migrated or similar -- scale
-- factor may well change. Sizes are primarily defined relative to self or
-- active default font size though, and display manager changes font-size
-- during migration and display setup.

-- properties that change visual behavior
		border_w = gconfig_get("borderw"),
		dispmask = 0,
		name = "wnd_" .. tostring(ent_count),

-- though the active values are defined by the anchor and canvas, these
-- values are used for tracking / budgets in the current layout mode
		effective_w = 0,
		effective_h = 0,
		max_w = wm.width,
		max_h = wm.height,
		x = 0,
		y = 0,
		weight = 1.0,
		vweight = 1.0,

		cursor = "default",
		cfg_prefix = "",
		hide_titlebar = gconfig_get("hide_titlebar"),
		centered = true,
		scalemode = opts.scalemode and opts.scalemode or "normal",

-- public events to manipulate the window
		alert = wnd_alert,
		hide = wnd_hide,
		assign_ws = wnd_reassign,
		destroy = wnd_destroy,
		set_message = wnd_message,
		set_title = wnd_title,
		set_prefix = wnd_prefix,
		set_ident = wnd_ident,
		add_handler = wnd_addhandler,
		drop_handler = wnd_drophandler,
		set_dispmask = wnd_dispmask,
		set_suspend = wnd_setsuspend,
		add_dependent = wnd_dependent,
		rebuild_border = wnd_rebuild,
		toggle_maximize = wnd_toggle_maximize,
		make_dependent = wnd_forcedep,
		to_front = wnd_tofront,
		update_font = wnd_font,
		resize = wnd_resize,
		migrate = wnd_migrate,
		reposition = wnd_repos,
		resize_effective = wnd_effective_resize,
		select = wnd_select,
		deselect = wnd_deselect,
		next = wnd_next,
		merge = wnd_merge,
		collapse = wnd_collapse,
		prev = wnd_prev,
		move = wnd_move,
		input_table = wnd_inputtable,
		mousebutton = wnd_mousebutton,
		mousemotion = wnd_mousemotion,
		display_table = get_disptbl,
		swap = wnd_swap,
		grow = wnd_grow,
		add_popup = wnd_popup,
		drop_popup = wnd_droppopup,
	};
	res.width = opts.width and opts.width or wm.min_width;
	res.height = opts.height and opts.height or wm.min_height;

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
	ent_count = ent_count + 1;

	res.titlebar = uiprim_bar(res.anchor, ANCHOR_UL,
		res.width - 2 * bw, tbar_geth(res), "titlebar", titlebar_mh);
	res.titlebar.tag = res;
	res.titlebar:move(bw, bw);

	res.titlebar:add_button("center", nil, "titlebar_text",
		" ", gconfig_get("sbar_tpad") * wm.scalef, res.wm.font_resfn);
	res.titlebar:hide();

-- order canvas so that it comes on top of the border for mouse events
	order_image(res.canvas, 2);

-- default is active, but should be inactive here
	res.titlebar:switch_state("inactive", true);
	shader_setup(res.border, "ui", "border", "inactive");
	show_image({res.border, res.canvas});

	res.handlers.mouse.border = {
		name = tostring(res.anchor) .. "_border",
		own = function(ctx, vid) return vid == res.border; end,
		tag = res
	};

	res.handlers.mouse.canvas = {
		name = tostring(res.anchor) .. "_canvas",
		own = function(ctx, vid) return vid == res.canvas; end,
		tag = res
	};

	local tl = {};
	for k,v in pairs(border_mh) do
		res.handlers.mouse.border[k] = v;
		table.insert(tl, k);
	end
	mouse_addlistener(res.handlers.mouse.border, tl);

	tl = {};
	for k,v in pairs(canvas_mh) do
		res.handlers.mouse.canvas[k] = v;
		table.insert(tl, k);
	end
	mouse_addlistener(res.handlers.mouse.canvas, tl);
	res.block_mouse = opts.block_mouse;
	res.ws_attach = wnd_ws_attach;
	return res;
end

local function wnd_create(wm, source, opts)
	local res = wnd_setup(wm, source, opts);
	if (res) then
		res:ws_attach();
	end
-- only valid for a hidden window
	res.make_dependent = nil;
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
	wm_update_mode(wm);

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
	wm_update_mode(wm);

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
	local s = {"active", "inactive", "alert", "default"};
	shader_update_uniform("border", "ui", "border", bw, s, "tiler-rebuild");
	shader_update_uniform("border", "ui", "thickness", tw, s, "tiler-rebuild");

	for i,v in ipairs(tiler.windows) do
		v:rebuild_border(bw);
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
		local quality = (API_VERSION_MAJOR == 0 and API_VERSION_MINOR < 11)
			and 1 or ALLOC_QUALITY_NORMAL;
		wm.rtgt_id = alloc_surface(wm.width, wm.height, true, quality);
		image_tracetag(wm.rtgt_id, "tiler_rt" .. wm.name);
		local pitem = null_surface(32, 32); --workaround for rtgt restriction
		image_tracetag(pitem, "rendertarget_placeholder");
		define_rendertarget(wm.rtgt_id, {pitem});
		for i,v in ipairs(list) do
			rendertarget_attach(wm.rtgt_id, v, RENDERTARGET_DETACH);
		end
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

local function wm_countspaces(wm)
	local r = 0;
	for i=1,10 do
		r = r + (wm.spaces[i] ~= nil and 1 or 0);
	end
	return r;
end

local function tiler_input_lock(wm, dst)
	wm.input_lock = dst;
end

local function tiler_resize(wm, neww, newh, norz)
-- special treatment for workspaces with float, we "fake" drop/set float
	for i=1,10 do
		if (wm.spaces[i] and wm.spaces[i].mode == "float") then
			drop_float(wm.spaces[i]);
		end
	end

	wm.width = neww;
	wm.height = newh;

	if (valid_vid(wm.rtgt_id)) then
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
end

local function tiler_activate(wm)
	if (wm.deactivated) then
		local deact = wm.deactivated;
		wm.deactivated = nil;
		mouse_absinput_masked(deact.mx, deact.my, true);
		if (deact.wnd) then
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

local function recalc_fsz(wm)
	local fsz = gconfig_get("font_sz") * wm.scalef - gconfig_get("font_sz");
	local int, fract = math.modf(fsz);
	int = int + ((fract > 0.75) and 1 or 0);
	if (int ~= int or int == 0/0 or int == -1/0 or int == 1/0) then
		int = 0;
	end

	wm.font_deltav = int;

-- since ascent etc. may be different at different sizes, render a test line
-- and set the "per tiler" shift here
	if (int > 0) then
		wm.font_delta = "\\f,+" .. tostring(int);
	elseif (int <= 0) then
		wm.font_delta = "\\f," .. tostring(int);
	end
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
	recalc_fsz(wm);
	wm:rebuild_border();

	for k,v in ipairs(wm.windows) do
		v:set_title();
		if (disptbl and valid_vid(v.external, TYPE_FRAMESERVER)) then
			target_displayhint(v.external, 0, 0, v.dispmask, get_disptbl(v, disptbl));
		end
	end

	wm:resize(wm.width, wm.height);

-- easier doing things like this than fixing the other dimensioning edgecases
	wm.statusbar:destroy();
	tiler_statusbar_build(wm);
	wm:tile_update();
end

local function tiler_fontres(wm)
	return wm.font_delta .. "\\#ffffff", wm.scalef * gconfig_get("sbar_tpad");
end

local function tiler_switchbg(wm, newbg)
	wm.background_name = newbg;
-- TODO: toggle rendertarget flag on/off on noclear

	if (valid_vid(wm.background_id)) then
		delete_image(wm.background_id);
		wm.background_id = nil;
	end

-- we need this synchronously unfortunately
	if ((type(newbg) == "string" and resource(newbg))) then
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

-- used when/if we have a RT, calctarget + reduction in size with
-- w * rel_w, h * rel_h and need some values about the aproximation
-- of the rendertarget. update and cache calculation when swapping ws.
--
-- [want_calc] is set if we want the built-in metrics and / or sample_chains
-- [rel_w, rel_h] are 0..1 multiplier of the RT contents
-- [update_rate] sets the amount of ticks between each update for the active
-- workspace
-- [sample_chain] is a list of callback functions that should be triggered
-- on the calctarget callback, to get custom measurements
--
local function tiler_estimator(want_calc,
	rel_w, rel_h, postproc_shader, update_rate, sample_chain)
end

local function toggle_preview(wm, on, scalef, rate, metrics, shader)
-- no rendertarget support
	if (not valid_vid(wm.rtgt_id)) then
		return;
	end

-- always reset
	if (valid_vid(wm.preview)) then
		for i=1,10 do
			if (wm.spaces[i] and valid_vid(wm.spaces[i].preview)) then
				delete_image(wm.spaces[i].preview);
				wm.spaces[i].preview = nil;
			end
		end
		wm.preview = nil;
		wm.preview_borders = nil;
	end

	if (not on) then
		return;
	end

-- our backing store, we need to change the update rate on this whenever
-- there's some overlay that should be included, like the lbar
	wm.preview = alloc_surface(wm.preview, wm.width * scalef,wm.height * scalef);
	if (not valid_vid(wm.preview)) then
		return;
	end

	local props = image_storage_properties(wm.preview);
	local tmp = null_surface(props.width, props.height);
	if (not valid_vid(tmp)) then
		delete_image(wm.preview);
		wm.preview = nil;
		return;
	end

	show_image(tmp);
	setup_shader(tmp, "basic", shader);
	image_sharestorage(wm.rtgt_id, tmp);

-- if we want to track average luminosity and have sample copies of the
-- border, metrics is set to true. this is used to reduce eyestrain in
-- setting switch times, backlight magnification factor
	if (metrics) then
		define_calctarget(wm.preview, {tmp}, RENDERTARGET_DETACH,
			RENDERTARGET_NOSCALE, rate,
			function(img, w, h)
				local ack_luma = 0;
				for y=0,h-1 do
					for x=0,w-1 do
						local r,g,b = img:get(x, y, 3);
						local lv = 0.299 * r + 0.587 * g + 0.114 * b;
						ack_luma = ack_luma + lv;
					end
				end
				local avg_luma = ack_luma / (w * h);
				wm.preview_border = {{}, {}, {}, {}};
				local dt = wm.preview_border[1];
				local db = wm.preview_border[2];
				for x=0,w-1 do
					local r,g,b = img:get(x, 0, 3);
					dt[x * 3 + 1] = r;
					dt[x * 3 + 2] = g;
					dt[x * 3 + 3] = b;
					r,g,b = img:get(x, h-1, 3);
					db[x * 3 + 1] = r;
					db[x * 3 + 2] = g;
					db[x * 3 + 3] = b;
				end
				dt = wm.preview_border[3];
				db = wm.preview_border[4];
				for y=0,h-1 do
					local r,g,b = img:get(0, y, 3);
					dt[y * 3 + 1] = r;
					dt[y * 3 + 2] = g;
					dt[y * 3 + 3] = b;
					r,g,b = img:get(w-1, y, 3);
					db[y * 3 + 1] = r;
					db[y * 3 + 2] = g;
					db[y * 3 + 3] = b;
				end
			end
		);
	else
		define_rendertarget(wm.preview,
			{tmp}, RENDERTARGET_DETACH, RENDERTARGET_NOSCALE, rate);
	end
end

function tiler_create(width, height, opts)
	opts = opts == nil and {} or opts;

	local res = {
-- null surfaces for clipping / moving / drawing
		name = opts.name and opts.name or "default",
		anchor = null_surface(1, 1),
		order_anchor = null_surface(1, 1),
		empty_space = workspace_empty,
		lbar = tiler_lbar,
		tick = tick_windows,

-- for multi-DPI handling
		font_delta = "\\f,+0",
		font_deltav = 0,
		font_sf = gconfig_get("font_defsf"),
		scalef = opts.scalef and opts.scalef or 1.0,
		disptbl = opts.disptbl and opts.disptbl or {ppcm = VPPCM},

-- management members
		spaces = {},
		windows = {},
		space_ind = 1,

-- debug

-- kept per/tiler in order to allow custom modes as well
		scalemodes = {"normal", "stretch", "aspect", "client"},

-- public functions
		set_background = tiler_switchbg,
		step_ws = tiler_stepws,
		switch_ws = tiler_switchws,
		swap_ws = tiler_swapws,
		swap_up = tiler_swapup,
		swap_down = tiler_swapdown,
		swap_left = tiler_swapleft,
		swap_right = tiler_swapright,
		active_spaces = wm_countspaces,
		activate = tiler_activate,
		deactivate = tiler_deactivate,
		set_rendertarget = tiler_rendertarget,
		add_window = wnd_create,
		add_hidden_window = wnd_setup,
		find_window = tiler_find,
		message = tiler_message,
		resize = tiler_resize,
		tile_update = tiler_statusbar_update,
		rebuild_border = tiler_rebuild_border,
		set_input_lock = tiler_input_lock,
		update_scalef = tiler_scalef,
		toggle_preview = toggle_preview,

-- unique event handlers
		on_wnd_create = function() end,
		on_preview_step = function() end
	};

	res.font_resfn = function() return tiler_fontres(res); end
	res.height = height;
	res.width = width;
-- to help with y positioning when we have large subscript,
-- this is manually probed during font-load
	recalc_fsz(res);
	tiler_statusbar_build(res);

	res.min_width = 32;
	res.min_height = 32;
	image_tracetag(res.anchor, "tiler_anchor");
	image_tracetag(res.order_anchor, "tiler_order_anchor");

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
	if (gconfig_get("ws_preview")) then
		res:toggle_preview(true, gconfig_get("ws_preview_scale"),
			gconfig_get("ws_preview_rate"), gconfig_get("ws_preview_metrics"),
			gconfig_get("ws_preview_shader")
		);
	end

	return res;
end

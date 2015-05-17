--
-- Copyright 2014-2015, Björn Ståhl
-- License: 3-Clause BSD.
-- Reference: http://arcan-fe.com
--
-- all functions are prefixed with mouse_
--
-- setup (takes control of vid):
--  setup_native(vid, hs_x, hs_y) or
--  setup(vid, layer, pickdepth, cachepick, hidden)
--   layer : order value
--   pickdepth : number of stacked vids to check (typically 1)
--   cachepick : cache results to reduce picking calls
--   hidden : start in hidden state
--
-- input:
--  button_input(ind, active)
--  input(x, y, state, mask_all_events)
--  absinput(x, y)
--
-- output:
--  mouse_xy()
--
-- tuning:
--  autohide() - true or false ; call to flip state, returns new state
--  acceleration(x_scale_factor, y_scale_factor) ;
--  dblclickrate(rate or nil) opt:rate ; get or set rate
--
-- state change:
--  hide, show
--  add_cursor(label, vid, hs_dx, hs_dy)
--  constrain(min_x, min_y, max_x, max_y)
--  switch_cursor(label) ; switch active cursor to label
--
-- use:
--  addlistener(tbl, {event1, event2, ...})
--   possible events: drag, drop, click, over, out
--    dblclick, rclick, press, release, motion
--
--   tbl- fields:
--    own (function, req, callback(tbl, vid)
--     return true/false for ownership of vid
--
--    + matching functions for set of events
--
--  droplistener(tbl)
--  tick(steps)
--   + input (above)
--
-- debug:
--  increase debuglevel > 2 and outputs activity
--

--
-- Mouse- gesture / collision triggers
--
local mouse_handlers = {
	click = {},
	over  = {},
	out   = {},
  drag  = {},
	press = {},
	release = {},
	drop  = {},
	hover = {},
	motion = {},
	dblclick = {},
	rclick = {}
};

local mstate = {
-- tables of event_handlers to check for match when
	handlers = mouse_handlers,
	eventtrace = false,
	btns = {false, false, false, false, false},
	cur_over = {},
	hover_track = {},
	autohide = false,
	hide_base = 40,
	hide_count = 40,
	hidden = true,

-- mouse event is triggered
	accel_x      = 1,
	accel_y      = 1,
	dblclickstep = 12, -- maximum number of ticks between clicks for dblclick
	drag_delta   = 8,  -- wiggle-room for drag
	hover_ticks  = 30, -- time of inactive cursor before hover is triggered
	hover_thresh = 12, -- pixels movement before hover is released
	click_timeout= 14; -- maximum number of ticks before we won't emit click
	click_cnt    = 0,
	counter      = 0,
	hover_count  = 0,
	x_ofs        = 0,
	y_ofs        = 0,
	last_hover   = 0,
	x = 0,
	y = 0,
	min_x = 0,
	min_y = 0,
	max_x = VRESW,
	max_y = VRESH,
	hotspot_dx = 0,
	hotspot_dy = 0
};

local cursors = {
};

local function mouse_cursorupd(x, y)
	if (mstate.hidden and (x ~= 0 or y ~= 0)) then

		if (mstate.native == nil) then
			instant_image_transform(mstate.cursor);
			blend_image(mstate.cursor, 1.0, 10);
			mstate.hidden = false;
		end

	elseif (mstate.hidden) then
		return 0, 0;
	end

	x = x * mstate.accel_x;
	y = y * mstate.accel_y;

	lmx = mstate.x;
	lmy = mstate.y;

	mstate.x = mstate.x + x;
	mstate.y = mstate.y + y;

	mstate.x = mstate.x < 0 and 0 or mstate.x;
	mstate.y = mstate.y < 0 and 0 or mstate.y;
	mstate.x = mstate.x > VRESW and VRESW-1 or mstate.x;
	mstate.y = mstate.y > VRESH and VRESH-1 or mstate.y;
	mstate.hide_count = mstate.hide_base;

	if (mstate.native) then
		move_cursor(mstate.x, mstate.y);
	else
		move_image(mstate.cursor, mstate.x + mstate.x_ofs,
			mstate.y + mstate.y_ofs);
	end
	return (mstate.x - lmx), (mstate.y - lmy);
end

-- global event handlers for things like switching cursor on press
mstate.lmb_global_press = function()
		mstate.y_ofs = 2;
		mstate.x_ofs = 2;
		mouse_cursorupd(0, 0);
	end

mstate.lmb_global_release = function()
		mstate.x_ofs = 0;
		mstate.y_ofs = 0;
		mouse_cursorupd(0, 0);
	end

-- this can be overridden to cache previous queries
mouse_pickfun = pick_items;

local function linear_find(table, label)
	for a,b in pairs(table) do
		if (b == label) then return a end
	end

	return nil;
end

local function insert_unique(tbl, key)
	for key, val in ipairs(tbl) do
		if val == key then
			tbl[key] = val;
			return;
		end
	end

	table.insert(tbl, key);
end

local function linear_ifind(table, val)
	for i=1,#table do
		if (table[i] == val) then
			return true;
		end
	end

	return false;
end

local function linear_find_vid(table, vid, state)
-- we filter here as some scans (over, out, ...) may query state
-- for objects that no longer exists
	if (not valid_vid(vid)) then
		return;
	end

	for a,b in pairs(table) do
		if (b:own(vid, state)) then
			return b;
		end
	end
end

local function cached_pick(xpos, ypos, depth, nitems)
	if (mouse_lastpick == nil or CLOCK > mouse_lastpick.tick or
		xpos ~= mouse_lastpick.x or ypos ~= mouse_lastpick.y) then
		local res = pick_items(xpos, ypos, depth, nitems);

		mouse_lastpick = {
			tick = CLOCK,
			x = xpos,
			y = ypos,
			count = nitems,
			val = res
		};

		return res;
	else
		return mouse_lastpick.val;
	end
end

function mouse_cursor()
	return mstate.cursor;
end

function mouse_state()
	return mstate;
end

function mouse_destroy()
	mouse_handlers = {};
	mouse_handlers.click = {};
  mouse_handlers.drag  = {};
	mouse_handlers.drop  = {};
	mouse_handlers.over = {};
	mouse_handlers.out = {};
	mouse_handlers.motion = {};
	mouse_handlers.dblclick = {};
	mouse_handlers.rclick = {};
	mstate.handlers = mouse_handlers;
	mstate.eventtrace = false;
	mstate.btns = {false, false, false, false, false};
	mstate.cur_over = {};
	mstate.hover_track = {};
	mstate.autohide = false;
	mstate.hide_base = 40;
	mstate.hide_count = 40;
	mstate.hidden = true;
	mstate.accel_x = 1;
	mstate.accel_y = 1;
	mstate.dblclickstep = 6;
	mstate.drag_delta = 8;
	mstate.hover_ticks = 30;
	mstate.hover_thresh = 12;
	mstate.counter = 0;
	mstate.hover_count = 0;
	mstate.x_ofs = 0;
	mstate.y_ofs = 0;
	mstate.last_hover = 0;
	toggle_mouse_grab(MOUSE_GRABOFF);

	for k,v in pairs(cursors) do
		delete_image(v.vid);
	end
	cursors = {};

	if (valid_vid(mstate.cursor)) then
		delete_image(mstate.cursor);
		mstate.cursor = BADID;
	end
end

function mouse_setup(cvid, clayer, pickdepth, cachepick, hidden)
	mstate.hidden = false;
	mstate.x = math.floor(VRESW * 0.5);
	mstate.y = math.floor(VRESH * 0.5);

	mstate.cursor = null_surface(1, 1);
	image_mask_set(mstate.cursor, MASK_UNPICKABLE);
	mouse_add_cursor("default", cvid, 0, 0);
	mouse_switch_cursor();

	if (hidden ~= nil and hidden ~= true) then
	else
		show_image(mstate.cursor);
	end

	move_image(mstate.cursor, mstate.x, mstate.y);
	mstate.pickdepth = pickdepth;
	order_image(mstate.cursor, clayer);
	image_mask_set(cvid, MASK_UNPICKABLE);
	if (cachepick) then
		mouse_pickfun = cached_pick;
	else
		mouse_pickfun = pick_items;
	end

	mouse_cursorupd(0, 0);
end

function mouse_setup_native(resimg, hs_x, hs_y)
	mstate.native = true;
	if (hs_x == nil) then
		hs_x = 0;
		hs_y = 0;
	end

-- wash out any other dangling properties in resimg
	local tmp = null_surface(1, 1);
	local props = image_surface_properties(resimg);
	image_sharestorage(resimg, tmp);
	delete_image(resimg);

	mouse_add_cursor("default", tmp, hs_x, hs_y);
	mouse_switch_cursor("default");

	mstate.x = math.floor(mstate.max_x * 0.5);
	mstate.y = math.floor(mstate.max_y * 0.5);
	mstate.pickdepth = 1;
	mouse_pickfun = cached_pick;

	resize_cursor(props.width, props.height);

	mouse_cursorupd(0, 0);
end

--
-- Some devices just give absolute movements, convert
-- these to relative before moving on
--
function mouse_absinput(x, y)

	mstate.rel_x = x - mstate.x;
	mstate.rel_y = y - mstate.y;

	mstate.x = x;
	mstate.y = y;

	if (mstate.native) then
		move_cursor(mstate.x, mstate.y);
	else
		move_image(mstate.cursor, mstate.x + mstate.x_ofs,
			mstate.y + mstate.y_ofs);
	end

	mouse_input(x, y, nil, true);
end

function mouse_xy()
	if (mstate.native) then
		local x, y = cursor_position();
		return x, y;
	else
		local props = image_surface_resolve_properties(mstate.cursor);
		return props.x, props.y;
	end
end

local function mouse_drag(x, y)
	if (mstate.eventtrace) then
		warning(string.format("mouse_drag(%d, %d)", x, y));
	end

	for key, val in pairs(mstate.drag.list) do
		local res = linear_find_vid(mstate.handlers.drag, val, "drag");
		if (res) then
			res:drag(val, x, y);
		end
	end
end

local function rmbhandler(hists, press)
	if (press) then
		mstate.rpress_x = mstate.x;
		mstate.rpress_y = mstate.y;
	else
		if (mstate.eventtrace) then
			warning("right click");
		end

		for key, val in pairs(hists) do
			local res = linear_find_vid(mstate.handlers.rclick, val, "rclick");
			if (res) then
				res:rclick(val, mstate.x, mstate.y);
			end
		end
	end
end

local function lmbhandler(hists, press)
	if (press) then
		mstate.press_x = mstate.x;
		mstate.press_y = mstate.y;
		mstate.predrag = {};
		mstate.predrag.list = hists;
		mstate.predrag.count = mstate.drag_delta;
		mstate.click_cnt = mstate.click_timeout;
		mstate.lmb_global_press();

		for key, val in pairs(hists) do
			local res = linear_find_vid(mstate.handlers.press, val, "press");
			if (res) then
				if (res:press(val, mstate.x, mstate.y)) then
					break;
				end
			end
		end

	else -- release
		mstate.lmb_global_release();

		for key, val in pairs(hists) do
			local res = linear_find_vid(mstate.handlers.release, val, "release");
			if (res) then
				if (res:release(val, mstate.x, mstate.y)) then
					break;
				end
			end
		end

		if (mstate.eventtrace) then
			warning(string.format("left click: %s", table.concat(hists, ",")));
		end

		if (mstate.drag) then -- already dragging, check if dropped
			if (mstate.eventtrace) then
				warning("drag");
			end

			for key, val in pairs(mstate.drag.list) do
				local res = linear_find_vid(mstate.handlers.drop, val, "drop");
				if (res) then
					if (res:drop(val, mstate.x, mstate.y)) then
						return;
					end
				end
			end
-- only click if we havn't started dragging or the button was released quickly
		else
			if (mstate.click_cnt > 0) then
				for key, val in pairs(hists) do
					local res = linear_find_vid(mstate.handlers.click, val, "click");
					if (res) then
						if (res:click(val, mstate.x, mstate.y)) then
							break;
						end
					end
				end
			end

-- double click is based on the number of ticks since the last click
			if (mstate.counter > 0 and mstate.counter <= mstate.dblclickstep) then
				if (mstate.eventtrace) then
					warning("double click");
				end

				for key, val in pairs(hists) do
					local res = linear_find_vid(mstate.handlers.dblclick, val,"dblclick");
					if (res) then
						if (res:dblclick(val, mstate.x, mstate.y)) then
							break;
						end
					end
				end
			end
		end

		mstate.counter   = 0;
		mstate.predrag   = nil;
		mstate.drag      = nil;
	end
end

--
-- we kept mouse_input that supported both motion and
-- button update at once for backwards compatibility.
--
function mouse_button_input(ind, active)
	if (ind < 1 or ind > 3) then
		return;
	end

	local hists = mouse_pickfun(
		mstate.x + mstate.hotspot_x,
		mstate.y + mstate.hotspot_y, mstate.pickdepth, 1);

	if (DEBUGLEVEL > 2) then
		local res = {};
		print("button matches:");
		for i, v in ipairs(hists) do
			print("\t" .. tostring(v) .. ":" .. (image_tracetag(v) ~= nil
				and image_tracetag(v) or "unknown"));
		end
		print("\n");
	end

	if (ind == 1 and active ~= mstate.btns[1]) then
		lmbhandler(hists, active);
	end

	if (ind == 3 and active ~= mstate.btns[3]) then
		rmbhandler(hists, active);
	end

	mstate.btns[ind] = active;
end

local function mbh(hists, state)
-- change in left mouse-button state?
	if (state[1] ~= mstate.btns[1]) then
		lmbhandler(hists, state[1]);

	elseif (state[3] ~= mstate.btns[3]) then
		rmbhandler(hists, state[3]);
	end

-- remember the button states for next time
	mstate.btns[1] = state[1];
	mstate.btns[2] = state[2];
	mstate.btns[3] = state[3];
end

function mouse_input(x, y, state, noinp)
	if (noinp == nil or noinp == false) then
		x, y = mouse_cursorupd(x, y);
	else
		x = mstate.rel_x;
		y = mstate.rel_y;
	end

	mstate.hover_count = 0;

	if (#mstate.hover_track > 0) then
		local dx = math.abs(mstate.hover_x - mstate.x);
		local dy = math.abs(mstate.hover_y - mstate.y);

		if (dx + dy > mstate.hover_thresh) then
			for i,v in ipairs(mstate.hover_track) do
				if (v.state.hover and
					v.state:hover(v.vid, mstate.x, mstate.y, false)) then
					break;
				end
			end

			mstate.hover_track = {};
			mstate.hover_x = nil;
			mstate.last_hover = CLOCK;
		end
	end

-- look for new mouse over objects
-- note that over/out do not filter drag/drop targets, that's up to the owner
	local hists = mouse_pickfun(mstate.x, mstate.y, mstate.pickdepth, 1);

	if (mstate.drag) then
		mouse_drag(x, y);
		if (state ~= nil) then
			mbh(hists, state);
		end
		return;
	end

	for i=1,#hists do
		if (linear_find(mstate.cur_over, hists[i]) == nil) then
			table.insert(mstate.cur_over, hists[i]);
			local res = linear_find_vid(mstate.handlers.over, hists[i], "over");
			if (res) then
				res:over(hists[i], mstate.x, mstate.y);
			end
		end
	end

-- drop ones no longer selected
	for i=#mstate.cur_over,1,-1 do
		if (not linear_ifind(hists, mstate.cur_over[i])) then
			local res = linear_find_vid(mstate.handlers.out,mstate.cur_over[i],"out");
			if (res) then
				res:out(mstate.cur_over[i], mstate.x, mstate.y);
			end
			table.remove(mstate.cur_over, i);
		else
			local res = linear_find_vid(mstate.handlers.motion,
				mstate.cur_over[i], "motion");
			if (res) then
				res:motion(mstate.cur_over[i], mstate.x, mstate.y);
			end
		end
	end

	if (mstate.predrag) then
			mstate.predrag.count = mstate.predrag.count -
				(math.abs(x) + math.abs(y));

		if (mstate.predrag.count <= 0) then
			mstate.drag = mstate.predrag;
			mstate.predrag = nil;
		end
	end

	if (state == nil) then
		return;
	end

	mbh(hists, state);
end

mouse_motion = mouse_input;

--
-- triggers callbacks in tbl when desired events are triggered.
-- expected members of tbl;
-- own (function(vid)) true | tbl / false if tbl is considered
-- the owner of vid
--
function mouse_addlistener(tbl, events)
	if (tbl == nil) then
		warning("mouse_addlistener(), refusing to add empty table.\n");
		warning( debug.traceback() );
		return;
	end

	if (tbl.own == nil) then
		warning("mouse_addlistener(), missing own function in argument.\n");
	end

	if (tbl.name == nil) then
		warning(" -- mouse listener missing identifier -- ");
		warning( debug.traceback() );
	end

	for ind, val in ipairs(events) do
		if (mstate.handlers[val] ~= nil and
			linear_find(mstate.handlers[val], tbl) == nil and tbl[val] ~= nil) then
			insert_unique(mstate.handlers[val], tbl);
		elseif (tbl[val] ~= nil) then
			warning("mouse_addlistener(), unknown event function: "
				.. val ..".\n");
		end
	end
end

function mouse_dumphandlers()
	warning("mouse_dumphandlers()");

	for ind, val in pairs(mstate.handlers) do
		warning("\t" .. ind .. ":");
			for key, vtbl in ipairs(val) do
				warning("\t\t" ..
					(vtbl.name and vtbl.name or tostring(vtbl)));
			end
	end

	warning("/mouse_dumphandlers()");
end

function mouse_droplistener(tbl)
	for key, val in pairs( mstate.handlers ) do
		for ind, vtbl in ipairs( val ) do
			if (tbl == vtbl) then
				table.remove(val, ind);
				break;
			end
		end
	end
end

function mouse_add_cursor(label, img, hs_x, hs_y)
	if (label == nil or type(label) ~= "string") then
		if (valid_vid(img)) then
			delete_image(img);
		end
		return warning("mouse_add_cursor(), missing label or wrong type");
	end

	if (cursors[label] ~= nil) then
		delete_image(cursors[label].vid);
	end

	if (not valid_vid(img)) then
		return warning(string.format(
			"mouse_add_cursor(%s), missing image", label));
	end

	local props = image_storage_properties(img);
	cursors[label] = {
		vid = img,
		hotspot_x = hs_x,
		hotspot_y = hs_y,
		width = props.width,
		height = props.height
	};
end

function mouse_switch_cursor(label)
	if (label == nil or cursors[label] == nil) then
		label = "default";
	end

	if (label == mstate.active_label) then
		return;
	end

	if (cursors[label] == nil) then
		if (mstate.native) then
			cursor_setstorage(WORLDID);
		else
			hide_image(mstate.cursor);
		end
		return;
	end

	local ct = cursors[label];
	mstate.active_label = label;

	if (mstate.native) then
		cursor_setstorage(ct.vid);
		resize_cursor(ct.width, ct.height);
	else
		image_sharestorage(ct.vid, mstate.cursor);
		resize_image(mstate.cursor, ct.width, ct.height);
	end

	mstate.hotspot_x = ct.hotspot_x;
	mstate.hotspot_y = ct.hotspot_y;
end

function mouse_hide()
	if (mstate.native) then
		mouse_switch_cursor(nil);
	else
		instant_image_transform(mstate.cursor);
		blend_image(mstate.cursor, 0.0, 20, INTERP_EXPOUT);
	end
end

function mouse_autohide()
	mstate.autohide = not mstate.autohide;
	return mstate.autohide;
end

function mouse_show()
	if (mstate.native) then
		mouse_switch_cursor(mstate.active_label);
	else
		instant_image_transform(mstate.cursor);
		blend_image(mstate.cursor, 1.0, 20, INTERP_EXPOUT);
	end
end

function mouse_tick(val)
	mstate.counter = mstate.counter + val;
	mstate.hover_count = mstate.hover_count + 1;
	mstate.click_cnt = mstate.click_cnt > 0 and mstate.click_cnt - 1 or 0;

	if (mstate.autohide and mstate.hidden == false) then
		mstate.hide_count = mstate.hide_count - val;
		if (mstate.hide_count <= 0 and mstate.native == nil) then
			mstate.hidden = true;
			instant_image_transform(mstate.cursor);
			mstate.hide_count = mstate.hide_base;
			blend_image(mstate.cursor, 0.0, 20, INTERP_EXPOUT);
		end
	end

	local hval = mstate.hover_ticks;
	if (CLOCK - mstate.last_hover < 200) then
		hval = 2;
	end

	if (mstate.hover_count > hval) then
		if (hover_reset) then
			local hists = mouse_pickfun(mstate.x, mstate.y, mstate.pickdepth, 1);
			for i=1,#hists do
				local res = linear_find_vid(mstate.handlers.hover, hists[i], "hover");
				if (res) then
					if (mstate.hover_x == nil) then
						mstate.hover_x = mstate.x;
						mstate.hover_y = mstate.y;
					end

					res:hover(hists[i], mstate.x, mstate.y, true);
					table.insert(mstate.hover_track, {state = res, vid = hists[i]});
				end
			end
		end

		hover_reset = false;
	else
		hover_reset = true;
	end
end

function mouse_dblclickrate(newr)
	if (newr == nil) then
		return mstate.dblclickstep;
	else
		mstate.dblclickstep = newr;
	end
end

function mouse_acceleration(newvx, newvy)
	if (newvx == nil) then
		return mstate.accel_x, mstate.accel_y;

	elseif (newvy == nil) then
		mstate.accel_x = math.abs(newvx);
		mstate.accel_y = math.abs(newvx);
	else
		mstate.accel_x = math.abs(newvx);
		mstate.accel_y = math.abs(newvy);
	end
end


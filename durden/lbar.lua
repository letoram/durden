-- Copyright: 2015, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: lbar- is an input dialog- style bar intended for durden that
-- supports some completion as well. It is somewhat messy as it grew without a
-- real idea of what it was useful for then turned out to become really
-- important.
--
-- The big flawed design stem from all the hoops you have to go through to
-- retain state after accepting/cancelling, and that it was basically designed
-- to chain through itself (create -> [ok press] -> destroy [ok handler] ->
-- call create again) etc. It worked OK when we didn't consider
-- launch-for-binding, path helpers, tooltip hints and meta up/down navigation
-- but is now just ugly.
--

local function inp_str(ictx, valid)
	return {
		valid and gconfig_get("lbar_textstr") or gconfig_get("lbar_alertstr"),
		ictx.inp.view_str()
	};
end

local pending = {};

local function update_caret(ictx, mask)
	local pos = ictx.inp.caretpos - ictx.inp.chofs;
	if (pos == 0) then
		move_image(ictx.caret, ictx.textofs, ictx.caret_y);
	else
		local msg = ictx.inp:caret_str();
		if (mask) then
			msg = string.rep("*", string.len(msg));
		end

		local w, h = text_dimensions({gconfig_get("lbar_textstr"),  msg});
		move_image(ictx.caret, ictx.textofs+w, ictx.caret_y);
	end
end

local active_lbar = nil;
local function destroy(wm, ictx)
	for i,v in ipairs(pending) do
		mouse_droplistener(v);
	end
	pending = {};
	active_lbar = nil;
	iostatem_restore(ictx.iostate);
	if (not wm.hidden_sb) then
		wm.statusbar:show();
	end

-- our lbar
	local time = gconfig_get("transition");
	if (ictx.on_step and ictx.cb_ctx) then
		ictx.on_step(ictx, -1);
	end

	blend_image(ictx.text_anchor, 0.0, time, INTERP_EXPOUT);
	blend_image(ictx.anchor, 0.0, time, INTERP_EXPOUT);

	if (time > 0) then
		PENDING_FADE = ictx.anchor;
		expire_image(ictx.anchor, time + 1);
		tag_image_transform(ictx.anchor, MASK_OPACITY, function()
			PENDING_FADE = nil;
		end);
	else
		delete_image(ictx.anchor);
	end

	if (wm.debug_console) then
		wm.debug_console:system_event(string.format(
			"lbar(%s) returned %s", sym, ictx.inp.msg));
	end

	wm.input_ctx = nil;
	wm:set_input_lock();
end

local function accept_cancel(wm, accept)
	local ictx = wm.input_ctx;
	local inp = ictx.inp;
	destroy(wm, ictx);

	if (accept) then
		local base = inp.msg;
		if (ictx.force_completion or string.len(base) == 0) then
			if (inp.set and inp.set[inp.csel]) then
				base = type(inp.set[inp.csel]) == "table" and
					inp.set[inp.csel][3] or inp.set[inp.csel];
			end
		end
-- save set as well
		ictx.get_cb(ictx.cb_ctx, base, true, inp.set, inp);
	else
		if (ictx.on_cancel) then
			ictx:on_cancel();
		end
	end
end

-- Build chain of single selectable strings, move and resize the marker to each
-- of them, chain their positions to an anchor so they are easy to delete, and
-- track an offset for drawing. We rebuild / redraw each cursor modification to
-- ignore scrolling and tracking details.
--
-- Set can contain the set of strings or a table of [colstr, selcolstr, text]
-- This is incredibly wasteful in the sense that the list, cursor and handlers
-- are reset and rebuilt- on every change. Should split out the cursor stepping
-- and callback for "just change selection" scenario, and verify that set ~=
-- last set. This dates back to the poor design of lbar/completion_cb. It's only
-- saving grace is that 'n' is constrained by wm.width and label sizes so in
-- 1..~20 or so- range.
--
local function update_completion_set(wm, ctx, set)
	if (not set) then
		return;
	end
	local pad = gconfig_get("lbar_tpad") * wm.scalef;
	if (ctx.canchor) then
		delete_image(ctx.canchor);
		for i,v in ipairs(pending) do
			mouse_droplistener(v);
		end
		pending = {};
		ctx.canchor = nil;
		ctx.citems = nil;
	end

-- track if set changes as we will need to reset
	if (not ctx.inp.cofs or not ctx.inp.set or #set ~= #ctx.inp.set) then
		ctx.inp.cofs = 1;
		ctx.inp.csel = 1;
	end
	ctx.inp.set = set;

	local on_step = wm.input_ctx.on_step;
-- clamp and account for paging
	if (ctx.clastc ~= nil and ctx.inp.csel < ctx.inp.cofs) then
		local ocofs = ctx.inp.cofs;
		ctx.inp.cofs = ctx.inp.cofs - ctx.clastc;
		ctx.inp.cofs = ctx.inp.cofs <= 0 and 1 or ctx.inp.cofs;

		if (ocofs ~= ctx.inp.cofs and on_step) then on_step(ctx); end
	end

-- limitation with this solution is that we can't wrap around negative
-- without forward stepping through due to variability in text length
	ctx.inp.csel = ctx.inp.csel <= 0 and ctx.clim or ctx.inp.csel;

-- wrap around if needed
	if (ctx.inp.csel > #set) then
		if (on_step and ctx.inp.cofs > 1) then on_step(ctx); end
		ctx.inp.csel = 1;
		ctx.inp.cofs = 1;
	end

-- very very messy positioning, relinking etc. can probably replace all
-- this mess with just using uiprim_bar and buttons in center area
	local regw = image_surface_properties(ctx.text_anchor).width;
	local step = math.ceil(0.5 + regw / 3);
	local ctxw = 2 * step;
	local textw = valid_vid(ctx.text) and (
		image_surface_properties(ctx.text).width) or ctxw;
	local lbarsz = gconfig_get("lbar_sz") * wm.scalef;

	ctx.canchor = null_surface(wm.width, lbarsz);
	image_tracetag(ctx.canchor, "lbar_anchor");

	move_image(ctx.canchor, step, 0);
	if (not valid_vid(ctx.ccursor)) then
		ctx.ccursor = color_surface(1, 1, unpack(gconfig_get("lbar_seltextbg")));
		image_tracetag(ctx.ccursor, "lbar_cursor");
	end

	local ofs = 0;
	local maxi = #set;

	ctx.clim = #set;

	local slide_window = function(i)
		ctx.clastc = i - ctx.inp.cofs;
		ctx.inp.cofs = ctx.inp.csel;
		if (on_step) then on_step(ctx); end
		return update_completion_set(wm, ctx, set);
	end

	for i=ctx.inp.cofs,#set do
		local msgs = {};
		local str;
		if (type(set[i]) == "table") then
			table.insert(msgs, wm.font_delta ..
				(i == ctx.sel and set[i][2] or set[i][1]));
			table.insert(msgs, set[i][3]);
		else
			table.insert(msgs, wm.font_delta .. (i == ctx.sel
				and gconfig_get("lbar_seltextstr") or gconfig_get("lbar_textstr")));
			table.insert(msgs, set[i]);
		end

		local w, h = text_dimensions(msgs);
		local exit = false;
		local crop = false;

-- special case, w is too large to fit, just crop to acceptable length
-- maybe improve this by adding support for a shortening, have full-name
-- in some cursor relative hint
		if (w > 0.3 * ctxw) then
			w = math.floor(0.3 * ctxw);
			crop = true;
		end

-- outside display? show ..., if that's our index, slide page
		if (i ~= ctx.inp.cofs and ofs + w > ctxw - 10) then
			str = "..."; -- string.char(0xe2, 0x86, 0x92);
			exit = true;

			if (i == ctx.inp.csel) then
				return slide_window(i);
			end
		end

		local txt, lines, txt_w, txt_h, asc = render_text(
			str and str or (#msgs > 0 and msgs or ""));

		image_tracetag(txt, "lbar_text" ..tostring(i));
		link_image(ctx.canchor, ctx.text_anchor);
		link_image(txt, ctx.canchor);
		link_image(ctx.ccursor, ctx.canchor);
		image_inherit_order(ctx.canchor, true);
		image_inherit_order(ctx.ccursor, true);
		image_inherit_order(txt, true);
		order_image(txt, 2);
		image_clip_on(txt, CLIP_SHALLOW);
		order_image(ctx.ccursor, 1);

-- try to avoid very long items from overflowing their slot,
-- should "pop up" a copy when selected instead where the full
-- name is shown
		if (crop) then
			crop_image(txt, w, h);
		end

-- allow (but sneer!) mouse for selection and activation, missing
-- an entry to handle "last-page back to first" though
		local mh = {
			name = "lbar_labelsel",
			own = function(mctx, vid)
				return vid == txt or vid == mctx.child;
			end,
			motion = function(mctx)
				if (ctx.inp.csel == i) then
					return;
				end
				if (on_step) then
					on_step(ctx, i, set, ctx.text_anchor,
						mctx.mofs + mctx.mstep, mctx.mwidth, mctx);
				end
				ctx.inp.csel = i;
				resize_image(ctx.ccursor, w, lbarsz);
				move_image(ctx.ccursor, mctx.mofs, 0);
			end,
			click = function()
				if (exit) then
					return slide_window(i);
				else
					accept_cancel(wm, true);
				end
			end,
-- need copies of these into returned context for motion handler
			mofs = ofs,
			mstep = step,
			mwidth = w
		};

		mouse_addlistener(mh, {"motion", "click"});
		table.insert(pending, mh);
		show_image({txt, ctx.ccursor, ctx.canchor});

		if (i == ctx.inp.csel) then
			move_image(ctx.ccursor, ofs, 0);
			resize_image(ctx.ccursor, w, lbarsz);
			if (on_step) then
				on_step(ctx, i, set, ctx.text_anchor, ofs + step, w, mh);
			end
		end

		move_image(txt, ofs, pad);
		ofs = ofs + (crop and w or txt_w) + gconfig_get("lbar_itemspace");
-- can't fit more entries, give up
		if (exit) then
			ctx.clim = i-1;
			break;
		end
	end
end

local function setup_string(wm, ictx, str)
	local tvid, heights, textw, texth = render_text(str);
	if (not valid_vid(tvid)) then
		return ictx;
	end

	local pad = gconfig_get("lbar_tpad") * wm.scalef;

	ictx.text = tvid;
	image_tracetag(ictx.text, "lbar_inpstr");
	show_image(ictx.text);
	link_image(ictx.text, ictx.text_anchor);
	image_inherit_order(ictx.text, true);

	move_image(ictx.text, ictx.textofs, pad);

	return tvid;
end

local function lbar_istr(wm, ictx, res)
-- other option would be to run ictx.inp:undo, which was the approach earlier,
-- but that prevented the input of more complex values that could go between
-- valid and invalid. Now we just visually indicate.
	local str = inp_str(ictx, not (res == false or res == nil));
	if (ictx.mask_text) then
		str[2] = string.rep("*", string.len(str[2]));
	end

	if (valid_vid(ictx.text)) then
		ictx.text = render_text(ictx.text, str);
	else
		ictx.text = setup_string(wm, ictx, str);
	end

	update_caret(ictx, ictx.mask_text);
end

local function lbar_ih(wm, ictx, inp, sym, caret)
	if (caret ~= nil) then
		update_caret(ictx, ictx.mask_text);
		return;
	end
	inp.csel = inp.csel and inp.csel or 1;
	local res = ictx.get_cb(ictx.cb_ctx, ictx.inp.msg, false, ictx.inp.set, ictx.inp);

-- special case, we have a strict set to chose from
	if (type(res) == "table" and res.set) then
		update_completion_set(wm, ictx, res.set);
	end

	lbar_istr(wm, ictx, res);
end

-- used on spawn to get rid of crossfade effect
PENDING_FADE = nil;
local function lbar_input(wm, sym, iotbl, lutsym, meta)
	local ictx = wm.input_ctx;
	local m1, m2 = dispatch_meta();

	if (meta) then
		return;
	end

	if (not iotbl.active) then
		return;
	end

	if (m1 and (sym == ictx.cancel or sym == ictx.accept or
		sym == ictx.caret_left or sym == ictx.caret_right or
		sym == ictx.step_n or sym == ictx.step_p)) then
		if (ictx.meta_handler and
			ictx.meta_handler(wm, sym, iotbl, lutsym, meta)) then
			return;
			end
		end

		if (sym == ictx.cancel or sym == ictx.accept) then
			return accept_cancel(wm, sym == ictx.accept);
		end

		if ((sym == ictx.step_n or sym == ictx.step_p)) then
			ictx.inp.csel = (sym == ictx.step_n) and
				(ictx.inp.csel+1) or (ictx.inp.csel-1);
			update_completion_set(wm, ictx, ictx.inp.set);
			return;
		end

	-- special handling, if the user hasn't typed anything, map caret manipulation
	-- to completion navigation as well)
		if (ictx.inp and ictx.inp.csel) then
			local upd = false;
			if (ictx.invalid) then
				upd = true;
				ictx.invalid = false;
			end

			if (string.len(ictx.inp.msg) < ictx.inp.caretpos and
				sym == ictx.inp.caret_right) then
				ictx.inp.csel = ictx.inp.csel + 1;
				upd = true;
			elseif (ictx.inp.caretpos == 1 and ictx.inp.chofs == 1 and
				sym == ictx.inp.caret_left) then
				ictx.inp.csel = ictx.inp.csel - 1;
				upd = true;
			end
			ictx.invalid = false;
			if (upd) then
				update_completion_set(wm, ictx, ictx.inp.set);
				return;
			end
		end

	-- note, inp ulim can be used to force a sliding view window, not
	-- useful here but still implemented.
		ictx.inp = text_input(ictx.inp, iotbl, sym, function(inp, sym, caret)
			lbar_ih(wm, ictx, inp, sym, caret);
		end);

		ictx.ulim = 10;

	-- unfortunately the haphazard lbar design makes filtering / forced reverting
	-- to a previous state a bit clunky, get_cb -> nil? nothing, -> false? don't
	-- permit, -> tbl with set? change completion view

		local res = ictx.get_cb(ictx.cb_ctx, ictx.inp.msg, false, ictx.inp.set, ictx.inp);
	if (res == false) then
--		ictx.inp:undo();
	elseif (res == true) then
	elseif (res ~= nil and res.set) then
		update_completion_set(wm, ictx, res.set);
	end
end

local function lbar_label(lbar, lbl)
	if (valid_vid(lbar.labelid)) then
		delete_image(lbar.labelid);
		if (lbl == nil) then
			lbar.textofs = 0;
			return;
		end
	end

	local wm = active_display();

	local id, lines, w, h, asc = render_text({wm.font_delta ..
		gconfig_get("lbar_labelstr"), lbl});

	lbar.labelid = id;
	if (not valid_vid(lbar.labelid)) then
		return;
	end

	image_tracetag(id, "lbar_labelstr");
	show_image(id);
	link_image(id, lbar.text_anchor);
	image_inherit_order(id, true);
	order_image(id, 1);

	local pad = gconfig_get("lbar_tpad") * wm.scalef;
-- relinking / delinking on changes every time
	move_image(lbar.labelid, pad, pad);
	lbar.textofs = w + gconfig_get("lbar_spacing") * wm.scalef;

	if (valid_vid(lbar.text)) then
		move_image(lbar.text, lbar.textofs, pad);
	end
	update_caret(lbar);
end

-- construct a default lbar callback that triggers cb on an exact
-- content match of the tbl- table
function tiler_lbarforce(tbl, cb)
	return function(ctx, instr, done, last)
		if (done) then
			cb(instr);
			return;
		end

		if (instr == nil or string.len(instr) == 0) then
			return {set = tbl, valid = true};
		end

		local res = {};
		for i,v in ipairs(tbl) do
			if (string.sub(v,1,string.len(instr)) == instr) then
				table.insert(res, v);
			end
		end

-- want to return last result table so cursor isn't reset
		if (last and #res == #last) then
			return {set = last};
		end

		return {set = res, valid = true};
	end
end

local function lbar_helper(lbar, domain, arg)
	if (domain == lbar.HELPER_TOOLTIP) then
		warning("fixme: helper_tooltip");
-- tooltip, initial fade up, then grow / shrink, arg is vid or text
	elseif (domain == lbar.HELPER_REG1) then
-- return anchor point, expect callback in arg
		warning("fixme: helper_reg1");
	elseif (domain == lbar.HELPER_REG2) then
-- if botttom or top, return broken
		warning("fixme: helper_reg2");
	end
end

function tiler_lbar(wm, completion, comp_ctx, opts)
	opts = opts == nil and {} or opts;
	local time = gconfig_get("transition");
	if (valid_vid(PENDING_FADE)) then
		delete_image(PENDING_FADE);
		time = 0;
	end
	PENDING_FADE = nil;
	if (active_lbar) then
		warning("tried to spawn multiple lbars");
		print(debug.traceback());
		return;
	end

	local bg = fill_surface(wm.width, wm.height, 255, 0, 0);
	image_tracetag(bg, "lbar_bg");
	shader_setup(bg, "ui", "lbarbg");
	local ph = {
		name = "bg_cancel",
		own = function(ctx, vid) return vid == bg; end,
		click = function()
			accept_cancel(wm, false);
		end
	}
	mouse_addlistener(ph, {"click", "rclick"});
	table.insert(pending, ph);

	local barh = math.ceil(gconfig_get("lbar_sz") * wm.scalef);
	local bar = fill_surface(wm.width, barh, 255, 0, 0);
	shader_setup(bar, "ui", "lbar");

	link_image(bg, wm.order_anchor);
	link_image(bar, bg);
	image_inherit_order(bar, true);
	image_inherit_order(bg, true);
	image_mask_clear(bar, MASK_OPACITY);

	blend_image(bg, gconfig_get("lbar_dim"), time, INTERP_EXPOUT);
	order_image(bg, 1);
	order_image(bar, 3);
	blend_image(bar, 1.0, time, INTERP_EXPOUT);

	local car = color_surface(wm.scalef * gconfig_get("lbar_caret_w"),
		wm.scalef * gconfig_get("lbar_caret_h"),
		unpack(gconfig_get("lbar_caret_col"))
	);
	show_image(car);
	image_inherit_order(car, true);
	link_image(car, bar);
	local carety = gconfig_get("lbar_tpad") * wm.scalef;

-- we support up to 4 helper regions (depending on bar position):
-- h1 [ show current path, clickable to navigate back ]
-- h2 [ show selection overlay ]
-- h3 [ big region, above ]
-- h4 [ big region, below ]
	move_image(bar, 0, math.floor(0.5*(wm.height-barh)));

	wm:set_input_lock(lbar_input);
	local res = {
-- just expose the constants here instead of polluting something global
		HELPER_TOOLTIP = 1,
		HELPER_REG1 = 2,
		HELPER_REG2 = 3,
		anchor = bg,
		text_anchor = bar,
		mask_text = opts.password_mask,
-- we cache these per context as we don't want them changing mid- use
		accept = SYSTEM_KEYS["accept"],
		cancel = SYSTEM_KEYS["cancel"],
		step_n = SYSTEM_KEYS["next"],
		step_p = SYSTEM_KEYS["previous"],
		caret_left = SYSTEM_KEYS["caret_left"],
		caret_right = SYSTEM_KEYS["caret_right"],
		textstr = gconfig_get("lbar_textstr"),
		set_label = lbar_label,
		get_cb = completion,
		cb_ctx = comp_ctx,
		helpers = {{}, {}, {}},
		destroy = function()
			accept_cancel(wm, false);
		end,
		helper_tags = lbar_helper,
		cofs = 1,
		csel = 1,
		barh = barh,
		textofs = 0,
		caret = car,
		caret_y = carety,
		cleanup = opts.cleanup,
		on_step = opts.on_step,
		iostate = iostatem_save(),
-- if not set, default to true
		force_completion = opts.force_completion == false and false or true
	};
	wm.input_ctx = res;

-- restore from previous population / selection
	if (opts.restore and opts.restore.msg) then
		if (string.len(opts.restore.msg) > 1 and
			opts.restore.cofs == 1 and opts.restore.csel == 1) then
-- we treat this case as new as it left with many prefix+1 res that had to be
-- erased to get to the set the user actually wanted
		else
			res.inp = opts.restore;
			res.invalid = true;
		end
	end

	lbar_input(wm, "", {active = true,
		kind = "digital", translated = true, devid = 0, subid = 0});
	lbar_istr(wm, res, true);

-- don't want this one running here as there might be actions bounnd that
-- alter bar state, breaking synch between data model and user
	wm.statusbar:hide();

	if (opts.label) then
		res:set_label(opts.label);
	end

	if (wm.debug_console) then
		wm.debug_console:system_event("lbar activated");
	end

	active_lbar = res;
	return res;
end

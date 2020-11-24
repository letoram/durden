-- Copyright: 2015-2020, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
--
-- Description: lbar- is an input dialog- style bar intended for durden that
-- supports some completion as well. It is somewhat messy as it grew without a
-- real idea of what it was useful for then turned out to become really
-- important.
--
-- The big flawed design stem from all the hoops you have to go through to
-- retain state after accepting/cancelling, and that it was basically designed
-- to chain through itself (create -> [ok press] -> destroy [ok handler] ->
-- call create again) etc. It worked OK when we didn't consider
-- launch-for-binding, tooltip hints and meta up/down navigation
-- but is now just ugly.
--
-- the worst 'sin' is all the mixed/nested contexts, rough estimate:
--
-- ictx = mapped to wm.input_ctx:
--       wm matching active_display that may have an active lbar already (chain)
--
-- ictx.inp = input state management for the text input, this uses the readline
--            implementation from suppl.lua - but we first do our own input mgmt
--            before forwarding
--
-- ictx.cb_ctx = comp_ctx which is actually provided for the input callbacks
--
-- where ictx.get_cb is the more important one here as it triggers the menu
-- update but also when something has been input and selected correctly
--
local function inp_str(ictx, valid)
	local prefix = active_display():font_resfn();
	return {
		prefix .. (
		valid and gconfig_get("lbar_textstr") or gconfig_get("lbar_alertstr")),
		ictx.inp:view_str()
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

		local prefix = active_display():font_resfn();
		local w, h = text_dimensions({prefix .. gconfig_get("lbar_textstr"),  msg});
		move_image(ictx.caret, ictx.textofs+w, ictx.caret_y);
	end
end

local active_lbar = nil;
local function destroy(wm, ictx)
	if (ictx.on_destroy) then
		ictx:on_destroy();
	end

	for i,v in ipairs(pending) do
		mouse_droplistener(v);
	end
	pending = {};
	mouse_droplistener(ictx.bg_mh);
	active_lbar = nil;

-- if the statusbar is attached to the HUD (that we are on), reanchor it to the
-- desktop so it doesn't get destroyed, then hide it so that it is not visible
	if (gconfig_get("sbar_visible") == "hud") then
		wm.statusbar:reanchor(wm.order_anchor, 2, wm.width, wm.statusbar.height);
		wm.statusbar:hide();

-- if the statusbar is hidden entirely, force-hide it here again as the option
-- might have changed in-flight
	elseif (wm.hidden_sb) then
		wm.statusbar:hide();
	else

-- or make it visible again, the reason we hide it on hud activation is the
-- blend-layer shining through and mixing with the widgets
		wm.statusbar:show();
	end

-- our lbar
	local time = gconfig_get("transition");
	if (ictx.on_step and ictx.cb_ctx) then
		ictx.on_step(ictx, -1);
	end

	blend_image(ictx.text_anchor, 0.0, time, INTERP_EXPOUT);
	blend_image(ictx.anchor, 0.0, time, INTERP_EXPOUT);

-- the 'time == 0' tend to be if animations are disabled entirely, or if
-- we want to switch immediately to a different kind of bar - the use of
-- PENDING_FADE here should be refactored entirely
	if (time > 0) then
		PENDING_FADE = ictx.anchor;
		expire_image(ictx.anchor, time + 1);
		tag_image_transform(ictx.anchor, MASK_OPACITY, function()
			PENDING_FADE = nil;
		end);
	else
		delete_image(ictx.anchor);
	end

-- now other components are free to grab input from the window manager
	wm.input_ctx = nil;
	wm:set_input_lock();
end

local function accept_cancel(wm, accept, nofwd, m1)
	local ictx = wm.input_ctx;
	local inp = ictx.inp;
	if (ictx.on_accept) then
		ictx:on_accept(accept);
	end

	destroy(wm, ictx);

-- the [nofwd] option is used to reset / trigger without causing
-- the outer component to activate some cancellation action
	if (not accept) then
		if (ictx.on_cancel and not nofwd) then
			ictx:on_cancel(m1);
		end
		return;
	end

	local base = inp.msg;
	if (ictx.force_completion or string.len(base) == 0) then
		if (inp.set and inp.set[inp.csel]) then
			base = type(inp.set[inp.csel]) == "table" and
				inp.set[inp.csel][3] or inp.set[inp.csel];
		end
	end

	ictx.get_cb(ictx.cb_ctx, base, true, inp.set, inp);
end

--
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
	ctx.ucount = ctx.ucount + 1;
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
	local on_item = wm.input_ctx.on_item;

-- clamp and account for paging
	if (ctx.inp.clastc ~= nil and ctx.inp.csel < ctx.inp.cofs) then
		local ocofs = ctx.inp.cofs;
		ctx.inp.cofs = ctx.inp.cofs - ctx.inp.clastc;
		ctx.inp.cofs = ctx.inp.cofs <= 0 and 1 or ctx.inp.cofs;
		if (ocofs ~= ctx.inp.cofs and on_step) then
			on_step(ctx);
		end
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
	local lbarsz = math.ceil(gconfig_get("lbar_sz") * wm.scalef);

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
		ctx.inp.clastc = i - ctx.inp.cofs;
		ctx.inp.cofs = ctx.inp.csel;
		if (on_step) then on_step(ctx); end
		return update_completion_set(wm, ctx, set);
	end

	local sel_fmt = wm.font_delta .. gconfig_get("lbar_seltextstr");
	local txt_fmt = wm.font_delta .. gconfig_get("lbar_textstr");

	for i=ctx.inp.cofs,#set do
-- figure out the format string and the message based on selection status
-- and if the provided entry has a custom override or we should use def.
		local selected = i == ctx.inp.csel;
		local msgs;

		if (type(set[i]) == "table") then
			msgs = {wm.font_delta .. (set[i][selected and 2 or 1]), set[i][3]};
		else
			msgs = {selected and sel_fmt or txt_fmt, set[i]};
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

-- outside display? show ->, if that's our index, slide page. Tacitly assume
-- that the normal arrow glyphs are indeed present in the way that even the
-- builtin- pixel font accepts.
		if (i ~= ctx.inp.cofs and ofs + w > ctxw - 10) then
			msgs = {txt_fmt, gconfig_get("lbar_nextsym")};
			exit = true;
			ctx.last_cell = i

			if (i == ctx.inp.csel) then
				return slide_window(i);
			end
		end

-- render, attach, position, order
		local txt, lines, txt_w, txt_h, asc = render_text(msgs);

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
-- name is shown as part of the description helper
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
					on_step(ctx, i, msgs[2], ctx.text_anchor,
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

-- update cursor for the selected item, and optionally forward to a
-- caller provided hook (from context setup)
		if (selected) then
			move_image(ctx.ccursor, ofs, 0);
			resize_image(ctx.ccursor, w, lbarsz);
			if (on_step) then
				on_step(ctx, i, msgs[2], ctx.text_anchor, ofs + step, w, mh);
			end
		end

-- forward setup so that content relative helpers can be pruned / updated
		if (on_item) then
			on_item(
				ctx, i, msgs[2], selected, ctx.text_anchor, ofs + step, w,
				exit or i == #set
			);
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

local function lbar_readline_input(wm, ictx, sym, m1)
-- ctrl+p to up
	if sym == "p" or sym == "UP" then
		sym = ictx.cancel
		return true, sym, true
	end

-- ctrl+a to home
	if sym == "a" then
		ictx.inp:caret_home()
		return
	end

-- ctrl+e to end
	if sym == "e" then
		ictx.inp:caret_end()
		return
	end

-- ctrl+l to clear
	if sym == "l" then
		ictx.inp:clear()
		update_completion_set(wm, ictx, ictx.inp.set)
		return
	end

-- try to step a page forward
	if sym == "k" then
		ictx.inp.csel = ictx.inp.csel + 2
		if ictx.last_cell then
			ictx.inp.csel = ictx.last_cell
			ictx.inp.clastc = ictx.last_cell - ictx.inp.cofs
			update_completion_set(wm, ictx, ictx.inp.set)
		end
		return
	end

	return false, sym, m1
end

-- used on spawn to get rid of crossfade effect
PENDING_FADE = nil;
function lbar_input(wm, sym, iotbl, lutsym, meta)
	local ictx = wm.input_ctx;
	local m1, m2 = dispatch_meta();

-- some old wm:input_lock handler, just ignore here
	if (meta) then
		return;
	end

-- and only trigger on rising edge
	if (not iotbl.active) then
		return;
	end

-- also remap control to modifier for readline-esque behaviors
	if iotbl.modifiers and iotbl.modifiers > 0 then
		local ms = decode_modifiers(iotbl.modifiers, "_")

		if ms == "lctrl" or ms == "rctrl" then
			local cont
			cont, sym, m1 = lbar_readline_input(wm, ictx, sym, m1)
			if not cont then
				return
			end
		end
	end

-- first allow whatever thing that is using the lbar to override the
-- meta + accept/l/r/n/p in order to implement more advanced actions
--
-- this was dropped from not being used and making certain operations even more
-- complicated, primary one being page left/right
--
--if (m1 and (sym == ictx.cancel or sym == ictx.accept or
--		sym == ictx.caret_left or sym == ictx.caret_right or
--		sym == ictx.step_n or sym == ictx.step_p)) then
--		if (ictx.meta_handler and ictx:meta_handler(sym, iotbl, lutsym, meta)) then
--			return
--		end
--	end

-- meta held means commit and relaunch at our current position,
-- this is problematic due to a. caching and b. path mutating
	if (sym == ictx.cancel or sym == ictx.accept) then
		return accept_cancel(wm, sym == ictx.accept, false, m1);
	end

	if ((sym == ictx.step_n or sym == ictx.step_p)) then
		if (ictx.inp and ictx.inp.csel) then
			ictx.inp.csel = (sym == ictx.step_n) and
				(ictx.inp.csel+1) or (ictx.inp.csel-1);
		end
		update_completion_set(wm, ictx, ictx.inp.set);
		return;
	end

-- special handling, if the user hasn't typed anything, map caret
-- manipulation to completion navigation as well)
		if (ictx.inp and ictx.inp.csel) then
			local upd = false;
			if (ictx.invalid) then
				upd = true;
				ictx.invalid = false;
			end

			if (string.len(ictx.inp.msg) < ictx.inp.caretpos and
				sym == ictx.caret_right) then
				ictx.inp.csel = ictx.inp.csel + 1;
				upd = true;

			elseif (ictx.inp.caretpos == 1 and ictx.inp.chofs == 1 and
				sym == ictx.caret_left) then
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
		local keys = {
			k_left   = SYSTEM_KEYS["left"],
			k_right  = SYSTEM_KEYS["right"],
			k_home   = SYSTEM_KEYS["home"],
			k_end    = SYSTEM_KEYS["end"],
			k_delete = SYSTEM_KEYS["delete"],
			k_erase  = SYSTEM_KEYS["erase"]
		};

-- forward to the read/edit-line like tool
		ictx.inp = suppl_text_input(
			ictx.inp, iotbl, sym,
			function(inp, sym, caret)
				lbar_ih(wm, ictx, inp, sym, caret);
			end,
			{
				bindings = keys
			}
		);
		ictx.ucount = 0;
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

local function lbar_helper(lbar, lbl)
	local wm = active_display();
	local barh = math.ceil(gconfig_get("lbar_sz") * wm.scalef);

	local dst;
	if (type(lbl) == "table") then
		dst = lbl;
	else
		if (not lbl or string.len(lbl) == 0) then
			if (valid_vid(lbar.helper_bg)) then
				hide_image(lbar.helper_bg);
			end
			return;
		end
		dst = {wm.font_delta .. gconfig_get("lbar_helperstr"), lbl};
	end

-- don't repeat ourselves
	if (lbl == lbar.last_helper) then
		return;
	end
	lbar.last_helper = lbl;

-- build text and bar
	local pad = gconfig_get("lbar_tpad") * wm.scalef;
	if (not lbar.helper_bg) then
		lbar.helper_bg = color_surface(64, barh, unpack(gconfig_get("lbar_helperbg")));
		shader_setup(lbar.helper_bg, "ui", "rounded");
		image_inherit_order(lbar.helper_bg, true);
		link_image(lbar.helper_bg, lbar.text_anchor);
		show_image(lbar.helper_bg);
		local w;
		lbar.helper_lbl, _, w = render_text(dst);
		image_inherit_order(lbar.helper_lbl, true);
		link_image(lbar.helper_lbl, lbar.helper_bg);
		show_image(lbar.helper_lbl);
		move_image(lbar.helper_lbl, 2, pad);
		nudge_image(lbar.helper_bg, 0, -barh);
		resize_image(lbar.helper_bg, w + 4, barh);

-- just re-render text and show bar
	else
		local w;
		show_image(lbar.helper_bg);
		_, _, w = render_text(lbar.helper_lbl, dst);
		move_image(lbar.helper_lbl, 2, pad);
		resize_image(lbar.helper_bg, w + 4, barh);
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

function tiler_lbar_isactive(ref)
	if (ref) then
		return active_lbar;
	else
		return active_lbar ~= nil;
	end
end

function tiler_lbar_setactive(slot)
	if (active_lbar) then
		active_lbar:destroy()
	end

	active_lbar = slot;
end

local function lbar_destroy(lbar, nofwd)
	accept_cancel(lbar.wm, false, nofwd);
end

function tiler_lbar(wm, completion, comp_ctx, opts)
	opts = opts == nil and {} or opts;
	local time = gconfig_get("transition");

-- hack around animation-out when something suddenly triggers a new lbar
-- during an ongoing fade'
	if (valid_vid(PENDING_FADE)) then
		delete_image(PENDING_FADE);
		time = 0;
	end

	PENDING_FADE = nil;
	if (active_lbar) then
		warning("tried to spawn multiple lbars");
		active_lbar:destroy();
	end

-- the bg is mainly input capture
	local bg = color_surface(wm.width, wm.height, 255, 0, 0);
	image_tracetag(bg, "lbar_bg");
	shader_setup(bg, "ui", "lbarbg");
	image_tracetag(bg, "lbar_bg");

--actual completion bar, gconfig- controled base color
	local barh = math.ceil(gconfig_get("lbar_sz") * wm.scalef);
	local bar = color_surface(wm.width, barh, unpack(gconfig_get("lbar_bg")));
	shader_setup(bar, "ui", "lbar");
	image_tracetag(bar, "lbar_text");

-- the wm order anchor is a null surface expected to be in the Z order above
-- the last visibile desktop item
	link_image(bg, wm.order_anchor);
	link_image(bar, bg);
	image_inherit_order(bar, true);
	image_inherit_order(bg, true);
	image_mask_clear(bar, MASK_OPACITY);

	blend_image(bg, gconfig_get("lbar_dim"), time, INTERP_EXPOUT);
	order_image(bg, 1);
	order_image(bar, 3);
	blend_image(bar, 1.0, time, INTERP_EXPOUT);

-- caret, size in pixels and scaled based on relative to base- density -
-- when we get a surface based on tui- instead this could be moved to simply
-- using the cursor attribute and move that around
	local car = color_surface(
		wm.scalef * gconfig_get("lbar_caret_w"),
		wm.scalef * gconfig_get("lbar_caret_h"),
		unpack(gconfig_get("lbar_caret_col"))
	);
	show_image(car);
	image_inherit_order(car, true);
	link_image(car, bar);
	local carety = gconfig_get("lbar_tpad") * wm.scalef;

	move_image(bar, 0, math.floor(0.5*(wm.height-barh)));

-- grab all input that gets routed through the WM
	wm:set_input_lock(lbar_input, "bbar");

	local res = {
		anchor = bg,
		text_anchor = bar,
		mask_text = opts.password_mask,

-- we cache these per context as we don't want them changing mid- use,
-- which can practically happen if binding is activated, even though suppl_input
-- also tracks these bindings, we want them here for the overloaded navigation
-- we have based on caret realative state
		accept = SYSTEM_KEYS["accept"],
		cancel = SYSTEM_KEYS["cancel"],
		step_n = SYSTEM_KEYS["next"],
		step_p = SYSTEM_KEYS["previous"],
		caret_left = SYSTEM_KEYS["left"],
		caret_right = SYSTEM_KEYS["right"],

		textstr = gconfig_get("lbar_textstr"),
		set_label = lbar_label,
		set_helper = lbar_helper,
		get_cb = completion,
		cb_ctx = comp_ctx,
		destroy = lbar_destroy,

-- own caret tracking, should probably just be moved to using suppl_input
		cofs = 1,
		csel = 1,
		ucount = 0,
		barh = barh,
		textofs = 0,
		caret = car,
		caret_y = carety,

-- hooks for implementing separate behavior, biggest use is file- browser like
-- behavior where previews need to be loaded, cached and aligne based on actual
-- item state
		on_step = opts.on_step,
		on_destroy = opts.on_destroy,
		on_item = opts.on_item,
		in_preview = opts.in_preview,
		on_accept = opts.on_accept,
		on_create = opts.on_create,
		on_entry = opts.on_entry,
		wm = wm,
	};

-- if not set, default to true, determines if results should be forwarded to the
-- caller as they are typed or based on the selected item (if any)
	if (opts.force_completion == false) then
		res.force_completion = false;
	else
		res.force_completion = true;
	end

	wm.input_ctx = res;

	local bg_mh = {
		name = "bg_cancel",
		own = function(ctx, vid) return vid == bg; end,
		click = function()
			accept_cancel(wm, true);
		end,
		rclick = function()
			accept_cancel(wm, false);
		end,
		button = function(ctx, vid, ind, act)
			if (not act or ind > MOUSE_WHEELNX or ind < MOUSE_WHEELPY) then
				return;
			end
			local d = (ind == MOUSE_WHEELNX or ind == MOUSE_WHEELNY) and 1 or -1;
			if (res.inp and res.inp.csel) then
				res.inp.csel = res.inp.csel + d;
				update_completion_set(wm, res, res.inp.set);
			end
		end
	}
	mouse_addlistener(bg_mh, {"click", "rclick", "button"});
	res.bg_mh = bg_mh;

-- arbitrary overrides hack, see menu.lua but used for previews
	if (opts.overlay) then
		for k,v in pairs(opts.overlay) do
			res[k] = v;
		end
	end

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

	if (res.on_create) then
		res:on_create(opts.restore);
	end

-- send a fake, empty keypress to seed input state
	lbar_input(wm, "", {
		active = true,
		kind = "digital",
		translated = true,
		devid = 0, subid = 0
	});
	lbar_istr(wm, res, true);

-- don't want this one running here as there might be actions bound that
-- alter bar state, breaking synch between data model and user
	if (gconfig_get("sbar_visible") == "hud") then
		wm.statusbar:show();
		move_image(wm.statusbar.anchor, 0, gconfig_get("sbar_pos") == "top"
			and 0 or wm.height - image_surface_resolve(wm.statusbar.anchor).height);
	else
		wm.statusbar:hide();
	end

-- label is suggested context indicator, used for hint in value input
	if (opts.label) then
		res:set_label(opts.label);
	end

	active_lbar = res;
	return res;
end

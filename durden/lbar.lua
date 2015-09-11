-- Copyright: 2015, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: lbar- is an input dialog- style bar intended for
-- durden that supports some completion as well.

local function inp_str(ictx, ul)
	return gconfig_get("lbar_textstr") .. ictx.inp.view_str();
end

local pending = nil;

-- Build chain of single selectable strings, move and resize the marker to each
-- of them, chain their positions to an anchor so they are easy to delete, and
-- track an offset for drawing. We rebuild / redraw each cursor modification to
-- ignore scrolling and tracking details.
--
-- Set can contain the set of strings or a table of [colstr, selcolstr, text]
--
local function update_completion_set(wm, ctx, set)
	if (ctx.canchor) then
		delete_image(ctx.canchor);
		ctx.canchor = nil;
		ctx.citems = nil;
	end

-- track if set changes as we will need to reset
	if (set ~= ctx.set) then
		ctx.cofs = 1;
		ctx.csel = 1;
	end
	ctx.set = set;

-- clamp and account for paging
	if (ctx.clastc ~= nil and ctx.csel < ctx.cofs) then
		ctx.cofs = ctx.cofs - ctx.clastc;
		ctx.cofs = ctx.cofs <= 0 and 1 or ctx.cofs;
	end

-- limitation with this solution is that we can't wrap around negative
-- without forward stepping through due to variability in text length
	ctx.csel = ctx.csel <= 0 and 1 or ctx.csel;

-- wrap around if needed
	if (ctx.csel > #set) then
		ctx.csel = 1;
		ctx.cofs = 1;
	end

	local regw = image_surface_properties(ctx.text_anchor).width;
	local step = math.ceil(0.5 + regw / 3);
	local ctxw = 2 * step;
	local textw = valid_vid(ctx.text) and (
		image_surface_properties(ctx.text).width) or ctxw;

	ctx.canchor = null_surface(wm.width, gconfig_get("lbar_sz"));
	image_tracetag(ctx.canchor, "lbar_anchor");

	move_image(ctx.canchor, step, 0);
	if (not valid_vid(ctx.ccursor)) then
		ctx.ccursor = color_surface(1, 1, unpack(gconfig_get("lbar_seltextbg")));
		image_tracetag(ctx.ccursor, "lbar_cursor");
	end

	local ofs = 0;

	for i=ctx.cofs,#set do
		local txt;
		if (type(set[i]) == "table") then
			txt = set[i][i == ctx.csel and 2 or 1] .. set[i][3];
		else
			if (i == ctx.csel) then
				txt = gconfig_get("lbar_seltextstr") .. set[i];
			else
				txt = gconfig_get("lbar_textstr") .. set[i];
			end
		end

		local w, h = text_dimensions(txt);
		local exit = false;

		if (ofs + w > ctxw - 10) then
			txt = "...";
			if (i == ctx.csel) then
				ctx.clastc = i - ctx.cofs;
				ctx.cofs = ctx.csel;
				return update_completion_set(wm, ctx, set);
			end
			exit = true;
		end

		txt = render_text(txt);
		image_tracetag(txt, "lbar_text" ..tostring(i));

		local cw = image_surface_properties(txt).width;
		link_image(ctx.canchor, ctx.text_anchor);
		link_image(txt, ctx.canchor);
		link_image(ctx.ccursor, ctx.canchor);
		image_inherit_order(ctx.canchor, true);
		image_inherit_order(ctx.ccursor, true);
		image_inherit_order(txt, true);
		order_image(txt, 2);
		order_image(ctx.ccursor, 1);
		image_clip_on(txt, CLIP_SHALLOW);

		show_image({txt, ctx.ccursor, ctx.canchor});

		local carety = math.floor(0.5*(
			gconfig_get("lbar_sz") - gconfig_get("lbar_textsz")));

		if (i == ctx.csel) then
			move_image(ctx.ccursor, ofs, 0);
			resize_image(ctx.ccursor, cw, gconfig_get("lbar_sz"));
		end

		move_image(txt, ofs, carety);
		ofs = ofs + cw + gconfig_get("lbar_itemspace");
-- can't fit more entries, give up
		if (exit) then
			break;
		end
	end

	local txanchor = 0;
end

local function update_caret(ictx)
	local pos = ictx.inp.caretpos - ictx.inp.chofs;
	if (pos == 0) then
		move_image(ictx.caret, ictx.textofs, ictx.caret_y);
	else
		local msg = ictx.inp:caret_str();
		local w, h = text_dimensions(gconfig_get("lbar_textstr") .. msg);
		move_image(ictx.caret, ictx.textofs+w, ictx.caret_y);
	end
end

local function lbar_ih(wm, ictx, inp, sym, caret)
	if (caret == nil) then
		local res = ictx.get_cb(ictx.cb_ctx, ictx.inp.msg, false, ictx.set);
		if (res == false) then
			ictx.inp:undo();
		elseif (res == true) then
		elseif (res ~= nil and res.set) then
			update_completion_set(wm, ictx, res.set);
		end

		if (valid_vid(ictx.text)) then
			delete_image(ictx.text);
		end

		ictx.text = render_text(inp_str(ictx));
		image_tracetag(ictx.text, "lbar_inpstr");
		show_image(ictx.text);
		link_image(ictx.text, ictx.text_anchor);
		image_inherit_order(ictx.text, true);
		move_image(ictx.text, ictx.textofs, math.floor(0.5*(
			gconfig_get("lbar_sz") - gconfig_get("lbar_textsz"))));
	end

	update_caret(ictx);
end

-- used on spawn to get rid of crossfade effect
PENDING_FADE = nil;
local function lbar_input(wm, sym, iotbl, lutsym, meta)
	local ictx = wm.input_ctx;

	if (meta) then
		return;
	end

	if (not iotbl.active) then
		return;
	end

	if (sym == ictx.cancel or sym == ictx.accept) then
		local time = gconfig_get("lbar_transition");
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
		iostatem_restore(ictx.iostate);
		wm.input_ctx = nil;
		wm:set_input_lock();
		if (sym == ictx.accept) then
			local base = ictx.inp.msg;

			if (ictx.force_completion or string.len(base) == 0) then
				if (ictx.set[ictx.csel]) then
					base = type(ictx.set[ictx.csel]) == "table" and
						ictx.set[ictx.csel][3] or ictx.set[ictx.csel];
				end
			end
			ictx.get_cb(ictx.cb_ctx, base, true, ictx.set);
		end
		return;
	end

	if ((sym == ictx.step_n or sym == ictx.step_p)) then
		ictx.csel = (sym == ictx.step_n) and (ictx.csel+1) or (ictx.csel-1);
		update_completion_set(wm, ictx, ictx.set);
		return;
	end

-- special handling, if the user hasn't typed anything, map caret manipulation
-- to completion navigation as well)
--	if (ictx.inp) then
--		if (ictx.inp.caretpos == 1 and ictx.inp.chofs == 1 and (
--			sym == ictx.inp.caret_left or sym == ictx.inp.caret_right)) then
--			ictx.csel = (sym==ictx.inp.caret_right) and (ictx.csel+1) or (ictx.csel-1);
--			update_completion_set(wm, ictx, ictx.set);
--			return;
--		end
--	end

-- note, inp ulim can be used to force a sliding view window, not
-- useful here but still implemented.
	ictx.inp = text_input(ictx.inp, iotbl, sym, function(inp, sym, caret)
		lbar_ih(wm, ictx, inp, sym, caret);
	end);

	ictx.ulim = 10;

-- unfortunately the haphazard lbar design makes filtering / forced reverting
-- to a previous state a bit clunky, get_cb -> nil? nothing, -> false? don't
-- permit, -> tbl with set? change completion view
	local res = ictx.get_cb(ictx.cb_ctx, ictx.inp.msg, false, ictx.set);
	if (res == false) then
		ictx.inp:undo();
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

	lbar.labelid = render_text(gconfig_get("lbar_labelstr")..lbl);
	if (not valid_vid(lbar.labelid)) then
		return;
	end

	image_tracetag(lbar.labelid, "lbar_labelstr");
	show_image(lbar.labelid);
	link_image(lbar.labelid, lbar.text_anchor);
	image_inherit_order(lbar.labelid, true);
	order_image(lbar.labelid, 1);

-- relinking / delinking on changes every time
	local props = image_surface_properties(lbar.labelid);
	move_image(lbar.labelid, 1, 1);
	lbar.textofs = props.width + gconfig_get("lbar_sz") + 1;
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

function tiler_lbar(wm, completion, comp_ctx, opts)
	opts = opts == nil and {} or opts;

	local time = gconfig_get("lbar_transition");
	if (valid_vid(PENDING_FADE)) then
		delete_image(PENDING_FADE);
		time = 0;
	end
	PENDING_FADE = nil;

	local bg = color_surface(wm.width, wm.height, 0, 0, 0);
	local bar = color_surface(wm.width, gconfig_get("lbar_sz"),
		unpack(gconfig_get("lbar_bg")));
	link_image(bg, wm.order_anchor);
	link_image(bar, bg);
	image_inherit_order(bar, true);
	image_inherit_order(bg, true);
	image_mask_clear(bar, MASK_OPACITY);

-- when navigating menus the bar is created and destroyed rapidly, a
-- global timer on des
	blend_image(bar, 1.0, time, INTERP_EXPOUT);
	blend_image(bg, gconfig_get("lbar_dim"), time, INTERP_EXPOUT);

	local car = color_surface(gconfig_get("lbar_caret_w"),
		gconfig_get("lbar_caret_h"), unpack(gconfig_get("lbar_caret_col")));
	show_image(car);
	image_inherit_order(car, true);
	link_image(car, bar);
	local carety = gconfig_get("lbar_sz") - gconfig_get("lbar_caret_h");

	local pos = gconfig_get("lbar_position");
	if (pos == "bottom") then
		move_image(bar, 0, wm.height - gconfig_get("lbar_sz"));
	elseif (pos == "center") then
		move_image(bar, 0, math.floor(0.5*(wm.height-gconfig_get("lbar_sz"))));
	else
	end
	wm:set_input_lock(lbar_input);
	wm.input_ctx = {
		anchor = bg,
		text_anchor = bar,
-- we cache these per context as we don't want them changing mid- use
		accept = SYSTEM_KEYS["accept"],
		cancel = SYSTEM_KEYS["cancel"],
		step_n = SYSTEM_KEYS["next"],
		step_p = SYSTEM_KEYS["previous"],
		textstr = gconfig_get("lbar_textstr"),
		set_label = lbar_label,
		get_cb = completion,
		cb_ctx = comp_ctx,
		ch_sz = lbar_textsz,
		cofs = 1,
		csel = 1,
		textofs = 0,
		caret = car,
		caret_y = carety,
		cleanup = opts.cleanup,
		iostate = iostatem_save(),
		force_completion = opts.force_completion and true or false
	};
	lbar_input(wm, "", {active = true,
		kind = "digital", translated = true, devid = 0, subid = 0});

	if (opts.label) then
		wm.input_ctx:set_label(opts.label);
	end

	if (wm.debug_console) then
		wm.debug_console:system_event("lbar activated");
	end
	return wm.input_ctx;
end

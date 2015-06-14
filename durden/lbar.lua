-- Copyright: 2015, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: lbar- is an input dialog- style bar intended for
-- durden that supports some completion as well.

-- Since we have kerning and other fun properties to consider, the caret pos is
-- calculated by internally rendering a sliced substring to the proper
-- character offset and then counting pixels.
local function clip_msg(msg, low, ulim)
	local uc = string.utf8ralign(msg, ulim)
	return string.gsub(string.sub(msg, low, uc), "\\", "\\\\");
end

local function inp_str(ictx, ul)
	return gconfig_get("lbar_textstr") .. clip_msg(
		ictx.inp.msg, ictx.inp.chofs, ictx.inp.chofs + (ul and ul or ictx.inp.ulim) );
end

-- Build chain of single selectable strings, move and resize the marker
-- to each of them, chain their positions to an anchor so they are easy
-- to delete, and track an offset for drawing. We rebuild / redraw each
-- cursor modification to ignore scrolling and tracking details.
local function update_completion_set(wm, ctx, set)
	if (ctx.canchor) then
		delete_image(ctx.canchor);
		ctx.canchor = nil;
		ctx.citems = nil;
	end

-- track if set changes
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

	ctx.csel = ctx.csel <= 0 and 1 or ctx.csel;
	ctx.csel = ctx.csel > #set and #set or ctx.csel;

	local regw = image_surface_properties(ctx.anchor).width;
	local step = math.ceil(0.5 + regw / 3);
	local ctxw = 2 * step;
	local textw = valid_vid(ctx.text) and (
		image_surface_properties(ctx.text).width) or ctxw;

	ctx.canchor = null_surface(wm.width, gconfig_get("lbar_sz"));
	move_image(ctx.canchor, step, 0);
	if (not valid_vid(ctx.ccursor)) then
		ctx.ccursor = color_surface(1, 1, unpack(gconfig_get("lbar_seltextbg")));
	end

	local ofs = 0;

	for i=ctx.cofs,#set do
		local txt;
		if (i == ctx.csel) then
			txt = gconfig_get("lbar_seltextstr")..set[i];
		else
			txt = gconfig_get("lbar_textstr")..set[i];
		end

		local w, h = text_dimensions(txt);
		local exit = false;

		if (ofs + w > ctxw - 10) then
			txt = "...";
			if (i == ctx.csel) then
				ctx.cofs = ctx.csel;
				ctx.clastc = i;
				return update_completion_set(wm, ctx, set);
			end
			exit = true;
		end

		txt = render_text(txt);

		local cw = image_surface_properties(txt).width;
		link_image(ctx.canchor, ctx.anchor);
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
		move_image(ictx.caret, 0, ictx.caret_y);
	else
		local w, h = text_dimensions(inp_str(ictx, pos-1));
		move_image(ictx.caret, w, ictx.caret_y);
	end
end

local function lbar_input(wm, sym, iotbl)
	local ictx = wm.input_ctx;

	if (iotbl.active and (sym == ictx.cancel or sym == ictx.accept)) then
		delete_image(ictx.anchor);
		wm.input_ctx = nil;
		wm.input_lock = nil;
		if (sym == ictx.accept) then
			ictx.get_cb(ictx.cb_ctx, ictx.force_completion and
				ictx.set[ictx.csel] or ictx.inp.msg, true, ictx.set);
		end
		return;
	end

	if (iotbl.active and (sym == ictx.step_n or sym == ictx.step_p)) then
		ictx.csel = (sym == ictx.step_n) and (ictx.csel+1) or (ictx.csel-1);
		update_completion_set(wm, ictx, ictx.set);
		return;
	end

-- note, inp ulim can be used to force a sliding view window, not
-- useful here but still implemented.
	ictx.inp = text_input(ictx.inp, iotbl, sym, function(inp, caret)
		if (caret == nil) then
			if (valid_vid(ictx.text)) then
				delete_image(ictx.text);
			end

			ictx.text = render_text(inp_str(ictx));
			show_image(ictx.text);
			link_image(ictx.text, ictx.anchor);
			image_inherit_order(ictx.text, true);
			move_image(ictx.text, 0, math.floor(0.5*(
				gconfig_get("lbar_sz") - gconfig_get("lbar_textsz"))));
			local res = ictx.get_cb(ictx.cb_ctx, ictx.inp.msg, false, ictx.set);
			if (res ~= nil and res.set) then
				update_completion_set(wm, ictx, res.set);
			end
		end
		update_caret(ictx);
	end);

	local res = ictx.get_cb(ictx.cb_ctx, ictx.inp.msg, false, ictx.set);
	if (res ~= nil and res.set) then
		update_completion_set(wm, ictx, res.set);
	end
end

function tiler_lbar(wm, completion, comp_ctx, opts)
	opts = opts == nil and {} or opts;

	local bar = color_surface(wm.width, gconfig_get("lbar_sz"),
		unpack(gconfig_get("lbar_bg")));
	show_image(bar);
	link_image(bar, wm.anchor);
	image_inherit_order(bar, true);
	order_image(bar, 10);

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
	wm.input_lock = lbar_input;
	wm.input_ctx = {
		anchor = bar,
		accept = gconfig_get("ok_sym"),
		cancel = gconfig_get("cancel_sym"),
		step_n = gconfig_get("step_next"),
		step_p = gconfig_get("step_previous"),
		textstr = gconfig_get("lbar_textstr"),
		get_cb = completion,
		cb_ctx = comp_ctx,
		ch_sz = lbar_textsz,
		cofs = 1,
		csel = 1,
		caret = car,
		caret_y = carety,
		force_completion = opts.force_completion and true or false
	};
	lbar_input(wm, "", {active = true, kind = "digital", translated = true,
		devid = 0, subid = 0});
end

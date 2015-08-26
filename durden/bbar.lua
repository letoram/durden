-- Copyright: 2015, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: b(inding)bar is an input dialog for binding / rebinding inputs.
-- it only supports digital inputs, analog need some better illustration that
-- combines other mechanics (filtering, ...).

PENDING_FADE = nil;
local function drop_bbar(wm)
	_G[APPLID .. "_clock_pulse"] = wm.input_ctx.clock_fwd;
	wm:set_input_lock();
	local time = gconfig_get("transition");
	local bar = wm.input_ctx.bar;
	blend_image(bar, 0.0, time, INTERP_EXPINOUT);
	if (time > 0) then
		PENDING_FADE = bar;
		expire_image(bar, time + 1);
		tag_image_transform(bar, MASK_OPACITY, function()
			PENDING_FADE = nil;
		end);
	else
		delete_image(bar);
	end
	if (wm.input_ctx.on_cancel) then
		wm.input_ctx:on_cancel();
	end
	iostatem_restore(wm.input_ctx.iostate);
	wm.input_ctx = nil;
end

local function bbar_input_key(wm, sym, iotbl, lutsym)
	local ctx = wm.input_ctx;

	if (ctx.cancel and sym == ctx.cancel) then
		return drop_bbar(wm);
	end

	if (ctx.ok and sym == ctx.ok and ctx.psym) then
		drop_bbar(wm);
		ctx.cb(ctx.psym, true);
	end

	if (iotbl.active) then
		if (not ctx.psym or ctx.psym ~= sym) then
			local res = ctx.cb(lutsym, false);
			if (type(res) == "string") then
				ctx.psym = nil;
				ctx:label(string.format("%s%s\\t%s%s", gconfig_get("lbar_errstr"),
					res, gconfig_get("lbar_labelstr"), ctx.message));
			else
				ctx.psym = sym;
				ctx:data(ctx.psym);
				ctx.clock = ctx.clock_start;
			end
		end
	else
		ctx:set_progress(0);
		ctx:data("");
		ctx.psym = nil;
		ctx.clock = nil;
	end
end

-- enforce meta + other key for bindings
local function bbar_input_combo(wm, sym, iotbl, lutsym, mstate)
	if (mstate) then
		return;
	end

	if (string.match(lutsym, "m%d_") ~= nil or sym == wm.input_ctx.cancel) then
		return bbar_input_key(wm, lutsym, iotbl, lutsym);
	else
		wm.input_ctx:set_progress(0);
		wm.input_ctx.clock = nil;
	end
end

local function set_label(ctx, msg)
	if (valid_vid(ctx.lid)) then
		delete_image(ctx.lid);
	end

	ctx.lid = render_text(gconfig_get("lbar_labelstr") .. msg);
	show_image(ctx.lid);
	link_image(ctx.lid, ctx.bar);
	image_inherit_order(ctx.lid, true);
	order_image(ctx.lid, 2);
	local props = image_surface_properties(ctx.lid);
	move_image(ctx.lid, math.floor(0.5 * (ctx.bar_w - props.width)), 1);
end

local function set_data(ctx, data)
	if (valid_vid(ctx.did)) then
		delete_image(ctx.did);
	end

	ctx.did = render_text(gconfig_get("lbar_textstr") .. data);
	show_image(ctx.did);
	link_image(ctx.did, ctx.bar);
	image_inherit_order(ctx.did, true);
	order_image(ctx.did, 2);
	local props = image_surface_properties(ctx.did);
	move_image(ctx.did, math.floor(0.5 * (ctx.bar_w - props.width)),
		ctx.data_y + 1);
end

local function set_progress(ctx, pct)
	if (0 == pct) then
		hide_image(ctx.progress);
		return;
	end

	blend_image(ctx.progress, 0.2);
	resize_image(ctx.progress, ctx.bar_w * pct, ctx.data_y * 2);
end

--
-- msg: default prompt
-- key: if true, bind a single key, not a combination
-- time: number of ticks of continous press to accept (nil or 0 to disable)
-- ok: sym to bind last immediately (nil to disable)
-- cancel: sym to abort (call cb with nil, true), (nil to disable)
-- cb will be invoked with ((symbol or symstr), done) where done. Expected
-- to return (false) to abort, true if valid or an error string.
--
function tiler_bbar(wm, msg, key, time, ok, cancel, cb)
	local lbsz = gconfig_get("lbar_sz") * 2;
	local bar = color_surface(wm.width, lbsz, unpack(gconfig_get("lbar_bg")));
	local progress = color_surface(1, lbsz, unpack(gconfig_get("lbar_caret_col")));

	local ctx = {
		clock_fwd = _G[APPLID .. "_clock_pulse"],
		cb = cb,
		cancel = cancel,
		ok = ok,
		clock_start = time,
		bar = bar,
		label = set_label,
		data = set_data,
		bar_w = wm.width,
		progress = progress,
		set_progress = set_progress,
		message = msg,
		iostate = iostatem_save(),
		data_y = gconfig_get("lbar_sz")
	};

	local time = gconfig_get("transition");
	if (valid_vid(PENDING_FADE)) then
		delete_image(PENDING_FADE);
		time = 0;
	end
	PENDING_FADE = nil;

	image_tracetag(bar, "bar");
	link_image(bar, wm.order_anchor);
	link_image(progress, bar);
	image_inherit_order(bar, true);
	image_inherit_order(progress, true);
	order_image(progress, 1);
	blend_image(bar, 1.0, time, INTERP_EXPOUT);

	local pos = gconfig_get("lbar_position");

	if (pos == "bottom") then
		move_image(bar, 0, wm.height - lbsz);
	elseif (pos == "center") then
		move_image(bar, 0, math.floor(0.5*(wm.height-lbsz*2)));
	else
	end

-- intercept tick callback to implement the "hold then bind" approach
-- for single keys.

	_G[APPLID .. "_clock_pulse"] = function(a, b)
		if (ctx.clock) then
			ctx.clock = ctx.clock - 1;
			set_progress(ctx, 1.0 - ctx.clock / ctx.clock_start);
			if (ctx.clock == 0) then
				drop_bbar(wm);
				ctx.cb(ctx.psym, true);
			end
		end
		ctx.clock_fwd(a, b);
	end

	iostatem_repeat(0, 0);
	wm:set_input_lock(key and bbar_input_key or bbar_input_combo);
	wm.input_ctx = ctx;
	ctx:label(msg);
	return ctx;
end

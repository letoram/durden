-- Copyright: 2015, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: b(inding)bar is an input dialog for binding / rebinding inputs.
-- it only supports translated inputs, analog need some better illustration that
-- combines other mechanics (filtering, ...). Much of this is hack'n'patch and
-- is high up on the list for rewrite as the requirements were not at all clear
-- when this began.

PENDING_FADE = nil;
local function drop_bbar(wm)
	_G[APPLID .. "_clock_pulse"] = wm.input_ctx.clock_fwd;
	wm:set_input_lock();
	local time = gconfig_get("transition");
	local bar = wm.input_ctx.bar;
	local anchor = wm.input_ctx.anchor;
	blend_image(bar, 0.0, time, INTERP_EXPINOUT);
	blend_image(anchor, 0.0, time, INTERP_EXPINOUT);
	if (time > 0) then
		PENDING_FADE = bar;
		expire_image(bar, time + 1);
		expire_image(anchor, time + 1);
		tag_image_transform(bar, MASK_OPACITY, function()
			PENDING_FADE = nil;
		end);
	else
		delete_image(bar);
		delete_image(anchor);
	end
	if (wm.input_ctx.on_cancel) then
		wm.input_ctx:on_cancel();
	end
	iostatem_restore(wm.input_ctx.iostate);
	if (not wm.hidden_sb) then
		wm.statusbar:show();
	end
	wm.input_ctx = nil;
end

local function bbar_input_key(wm, sym, iotbl, lutsym, mwm, lutsym2)
	local ctx = wm.input_ctx;

	if (ctx.cancel and sym == ctx.cancel) then
		return drop_bbar(wm);
	end

	if (ctx.ok and sym == ctx.ok and ctx.psym) then
		drop_bbar(wm);
		ctx.cb(ctx.psym, true, lutsym2, iotbl);
		return;
	end

	if (iotbl.active) then
		if (not ctx.psym or ctx.psym ~= sym) then
			local res = ctx.cb(lutsym, false, lutsym2, iotbl);
-- allow handle hook to show invalid or conflicting input
			if (type(res) == "string") then
				ctx.psym = nil;
				ctx:label(string.format("%s%s\\t%s%s", gconfig_get("lbar_errstr"),
					res, gconfig_get("lbar_labelstr"), ctx.message));
			else
				ctx.psym = sym;
				ctx.psym2 = lutsym2;
				ctx.iotbl = iotbl;
				ctx.rpress_c = ctx.rpress;
				ctx:data(ctx.psym .. (lutsym2 and '+' .. lutsym2 or ""));
				ctx.clock = ctx.clock_start;
				ctx:set_progress(0);
			end
		end
	else
		local cdiff = (ctx.clock and ctx.clock_start)
			and ctx.clock_start - ctx.clock or 0;

		if (cdiff < 10 and ctx.rpress and ctx.psym and ctx.psym == sym) then
			ctx.rpress_c = ctx.rpress_c - 1;
			if (ctx.rpress_c == 0) then
				drop_bbar(wm);
				ctx.cb(ctx.psym, true, lutsym2, iotbl);
			else
				ctx:set_progress((ctx.rpress - ctx.rpress_c) / ctx.rpress);
			end
		else
			ctx:set_progress(0);
			ctx:data("");
			ctx.psym = nil;
		end
		ctx.clock = nil;
	end
end

-- for the cases where we accept both a meta - key binding or a regular press
local function bbar_input_keyorcombo(wm, sym, iotbl, lutsym, mstate)
	if (sym == SYSTEM_KEYS["meta_1"] or sym == SYSTEM_KEYS["meta_2"]) then
		return;
	end

-- this needs to propagate both the m1_m2 and the possible modifiers
-- altgr etc. which may or may not collide (really bad design)
	local mods = table.concat(decode_modifiers(iotbl.modifiers), "_");
	local lutsym2 = string.len(mods) > 0 and (mods .."_" .. sym) or nil;
	bbar_input_key(wm, lutsym, iotbl, lutsym, nil, lutsym2);
end

-- enforce meta + other key for bindings
local function bbar_input_combo(wm, sym, iotbl, lutsym, mstate)
	if (mstate) then
		return;
	end

-- only require +meta+ for translated devices
	if (not iotbl.translated or
		string.match(lutsym, "m%d_") ~= nil or sym == wm.input_ctx.cancel) then
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

	ctx.did = render_text({gconfig_get("lbar_textstr"), data});
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
		if (valid_vid(ctx.progress)) then
			hide_image(ctx.progress);
		end
		return;
	end

	blend_image(ctx.progress, 0.2);
	resize_image(ctx.progress, ctx.bar_w * pct, ctx.data_y * 2);
end

local function setup_vids(wm, ctx, lbsz, time)
	local bar = color_surface(wm.width, lbsz, unpack(gconfig_get("lbar_bg")));
	local progress = color_surface(1, lbsz, unpack(gconfig_get("lbar_caret_col")));

	ctx.bar = bar;
	ctx.progress = progress;
	local time = gconfig_get("transition");
	local bg = fill_surface(wm.width, wm.height, 255, 0, 0);
	shader_setup(bg, "ui", "lbarbg");
	link_image(bg, wm.order_anchor);
	image_inherit_order(bg, true);
	blend_image(bg, gconfig_get("lbar_dim"), time, INTERP_EXPOUT);
	order_image(bg, 1);
	ctx.anchor = bg;

	image_tracetag(bar, "bar");
	link_image(bar, bg);
	link_image(progress, bar);
	image_inherit_order(bar, true);
	image_inherit_order(progress, true);
	image_inherit_order(ctx.anchor, true);
	order_image(progress, 1);
	order_image(ctx.anchor, 1);
	blend_image(bar, 1.0, time, INTERP_EXPOUT);

	move_image(bar, 0, math.floor(0.5*(wm.height-lbsz)));
end

--
-- msg: default prompt
-- key: if true, bind a single key, not a combination
-- time: number of ticks of continous press to accept (nil or 0 to disable)
-- ok: sym to bind last immediately (nil to disable)
-- cancel: sym to abort (call cb with nil, true), (nil to disable)
-- cb: will be invoked with ((symbol or symstr), done) where done. Expected
-- to return (false) to abort, true if valid or an error string.
-- rpress: if set, hold time can be circumvented by repeated press-releasing
-- rpress number of times (number >0 to enable), used for binding buttons that
-- can't be held.
--
function tiler_bbar(wm, msg, key, time, ok, cancel, cb, rpress)
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
		rpress = rpress,
		iostate = iostatem_save(),
		data_y = gconfig_get("lbar_sz") * wm.scalef
	};
	local time = gconfig_get("transition");
	if (valid_vid(PENDING_FADE)) then
		delete_image(PENDING_FADE);
		time = 0;
	end
	PENDING_FADE = nil;
	setup_vids(wm, ctx,
		gconfig_get("lbar_sz") * 2 * wm.scalef, time);

-- intercept tick callback to implement the "hold then bind" approach
-- for single keys.

	_G[APPLID .. "_clock_pulse"] = function(a, b)
		if (ctx.clock) then
			ctx.clock = ctx.clock - 1;
			set_progress(ctx, 1.0 - ctx.clock / ctx.clock_start);
			if (ctx.clock == 0) then
				drop_bbar(wm);
				ctx.cb(ctx.psym, true, ctx.psym2, ctx.iotbl);
			end
		end
		ctx.clock_fwd(a, b);
	end

	iostatem_repeat(0, 0);
	wm:set_input_lock(key == true and bbar_input_key or
		((key == false or key == nil)) and bbar_input_combo or bbar_input_keyorcombo);
	wm.input_ctx = ctx;
	ctx:label(msg);
	wm.statusbar:hide();
	return ctx;
end

--
-- simplified bbar, used for recovering on failed metas
--
function tiler_tbar(wm, msg, timeout, action, cancel)
	local ctx = {
		clock_fwd = _G[APPLID .. "_clock_pulse"];
		timeout = timeout,
		message = msg,
		progress = progress,
		label = set_label,
		bar_w = wm.width,
		set_progress = set_progress,
		iostate = iostatem_save(),
		data_y = gconfig_get("lbar_sz") * wm.scalef
	};
	setup_vids(wm, ctx, gconfig_get("lbar_sz") * 2 *
		wm.scalef, gconfig_get("transition"));
	iostatem_repeat(0, 0);

	_G[APPLID .. "_clock_pulse"] = function(a, b)
		ctx.clock_fwd(a, b);
		ctx.timeout = ctx.timeout - 1;
		if (ctx.timeout == 0) then
			drop_bbar(wm);
			action();
		else
			ctx:set_progress(1.0 - ctx.timeout / timeout);
			ctx:label(string.format(msg, ctx.timeout / CLOCKRATE, cancel));
		end
	end

	wm:set_input_lock(function(wm, sym)
		if (sym == cancel) then
			drop_bbar(wm);
		end
	end);

	wm.input_ctx = ctx;
	ctx:set_progress(1.0);
	ctx:label(string.format(msg, timeout / CLOCKRATE, cancel));

	return ctx;
end

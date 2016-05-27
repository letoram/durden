-- Copyright 2016, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: First attempt of abstracting some of the primitive
-- UI elements that were incidentally developed as part of durden.
--
local function button_labelupd(btn, lbl, timeout, timeoutstr)
	local txt, lineh, w, h, asc;
	local fontstr, offsetf = btn.fontfn();

	if (timeout and timeout > 0) then
		btn.timeout = timeout;
		btn.timeout_lbl = timeoutstr and timeoutstr or "";
	end

-- keep this around so we can update if the fontfn changes
	local append = true;
	if (lbl == nil) then
		lbl = btn.last_lbl;
		append = false;
	end

	if (type(lbl) == "string" or type(lbl) == "table") then
		if (type(lbl) == "string") then
			lbl = {fontstr, lbl};
		elseif (append) then
			lbl[1] = fontstr .. lbl[1];
		end
		btn.last_lbl = lbl;

		if (btn.lbl) then
			txt, lineh, w, h, asc = render_text(btn.lbl, lbl);
		else
			txt, lineh, w, h, asc = render_text(lbl);
		end

		btn.last_label_w = w;

		if (not valid_vid(txt)) then
			warning("error updating button label");
			return;
-- switch from icon based label to text based
		elseif (txt ~= btn.lbl and valid_vid(btn.lbl)) then
			delete_image(btn.lbl);
		end
		btn.lbl = txt;

-- just resize / relayout
	else
		if (lbl == nil) then
			return;
		end
		if (valid_vid(btn.lbl) and btn.lbl ~= lbl) then
			delete_image(btn.lbl);
		end
		local props = image_surface_properties(lbl);
		btn.lbl = lbl;
		w = props.width;
		h = props.height;
	end

-- done with label, figure out new button size including padding and minimum
	local padsz = 2 * btn.pad;
	if (btn.minw and btn.minw > 0 and w < btn.minw) then
		w = btn.minw;
	else
		w = w + padsz;
	end

	if (btn.minh and btn.minh > 0 and h < btn.minh) then
		h = btn.minh;
	else
		h = h + padsz;
	end

	if (btn.maxw and btn.maxw > 0 and w > btn.maxw) then
		w = btn.maxw;
	end

	if (btn.maxh and btn.maxh > 0 and w > btn.maxh) then
		h = btn.maxh;
	end

	btn.w = w;
	btn.h = h;

-- finally make the visual changes
	image_tracetag(btn.lbl, btn.lbl_tag);
	resize_image(btn.bg, btn.w, btn.h);
	link_image(btn.lbl, btn.bg);
	image_mask_set(btn.lbl, MASK_UNPICKABLE);
	image_clip_on(btn.lbl, CLIP_SHALLOW);

-- for some odd cases (center area on bar for instance),
-- specific lalign on text may be needed
	local xofs = btn.align_left and 0 or
		(0.5 * (btn.w - image_surface_properties(btn.lbl).width));

	move_image(btn.lbl, xofs, offsetf);
	image_inherit_order(btn.lbl, true);
	order_image(btn.lbl, 1);
	show_image(btn.lbl);
	shader_setup(btn.lbl, "ui", btn.lblsh, btn.state);
end

local function button_destroy(btn, timeout)
-- if we havn't been cascade- deleted from the anchor
	if (valid_vid(btn.bg)) then
		if (timeout) then
			expire_image(btn.bg, timeout);
			blend_image(btn.bg, 0, timeout);
		else
			delete_image(btn.bg, timeout);
		end
	end

-- if we merged with a mouse-handler
	if (btn.own) then
		mouse_droplistener(btn);
	end

-- and drop all keys to make sure any misused aliases will crash
	for k,v in pairs(btn) do
		btn[k] = nil;
	end
end

local function button_state(btn, newstate)
	btn.state = newstate;
	if (btn.bgsh) then
		shader_setup(btn.bg, "ui", btn.bgsh, newstate);
	end
	shader_setup(btn.lbl, "ui", btn.lblsh, newstate);
end

local function button_hide(btn)
	btn.hidden = true;
	hide_image(btn.bg);
end

local function button_size(btn)
	if (btn.hidden) then
		return 0, 0;
	end
	return btn.w, btn.h;
end

local function button_show(btn)
	if (btn.hidden) then
		show_image(btn.bg);
		btn.hidden = nil;
	end
end

local function button_constrain(btn, pad, minw, minh, maxw, maxh)
	if (pad) then
		btn.pad = pad;
	end

	if (minw) then
		btn.minw = minw == 0 and nil or minw;
	end

	if (minh) then
		btn.minh = minh == 0 and nil or minh;
	end

	if (maxw) then
		btn.maxw = maxw == 0 and nil or maxw;
	end

	if (maxh) then
		btn.maxh = maxh == 0 and nil or maxh;
	end

	btn:update();
end

local evset = {"click", "rclick", "drag", "drop", "dblclick", "over", "out"};

local function button_mh(ctx, mh)
	if (not mh) then
		if (ctx.own) then
			mouse_droplistener(ctx);
			ctx.own = nil;
			for k,v in ipairs(evset) do
				ctx[v] = nil;
			end
		end
		image_mask_set(ctx.bg, MASK_UNPICKABLE);
		return;
	end

	if (ctx.own) then
		button_mh(ctx, nil);
	end

	local lbltbl = {};
	for k,v in ipairs(evset) do
		if (mh[v] and type(mh[v]) == "function") then
			ctx[v] = mh[v];
			table.insert(lbltbl, v);
		end
	end
	ctx.name = "uiprim_button_handler";
	ctx.own = function(ign, vid)
		return vid == ctx.bg;
	end
	image_mask_clear(ctx.bg, MASK_UNPICKABLE);
	mouse_addlistener(ctx, lbltbl);
end

local function button_tick(btn)
	if (btn.timeout) then
		btn.timeout = btn.timeout - 1;
		if (btn.timeout <= 0) then
			btn:update(btn.timeout_lbl);
			btn.timeout = nil;
		end
	end
end

-- [anchor] required vid to attach to for ordering / masking
-- [bshname, lblshname] shaders in ui group to use
-- [lbl] vid or text string to use asx label
-- [pad] added space (px) between label and border
-- [fontfn] callback that is expected to return formatstr for text size
-- (minw) button can't be thinner than this
-- (minh) button can't be shorter than this
-- (mouseh) keyed table of functions to event handler
local ind = 0;
function uiprim_button(anchor, bgshname, lblshname, lbl,
	pad, fontfn, minw, minh, mouseh)
	ind = ind + 1;
	assert(pad);
	local res = {
		lblfmt = "\\f,0\\#ffffff",
		bgsh = bgshname,
		lblsh = lblshname,
		fontfn = fontfn,
		state = "active",
		minw = 0,
		minh = 0,
		yshift = 0,
		pad = pad,
		name = "uiprim_btn_" .. tostring(ind),
-- exposed methods
		update = button_labelupd,
		destroy = button_destroy,
		switch_state = button_state,
		dimensions = button_size,
		hide = button_hide,
		show = button_show,
		tick = button_tick,
		update_mh = button_mh,
		constrain = button_constrain
	};
	res.lbl_tag = res.name .. "_label";
	if (not bgshname) then
		res.bg = null_surface(1, 1);
	else
		res.bg = fill_surface(1, 1, 255, 0, 0);
	end

	if (minw and minw > 0) then
		res.minw = minw;
	end

	if (minh and minh > 0) then
		res.minh = minh;
	end

	link_image(res.bg, anchor);
	image_tracetag(res.bg, res.name .. "_bg");
	image_inherit_order(res.bg, true);
	order_image(res.bg, 2);
	show_image(res.bg);

	res:update(lbl);

	image_mask_set(res.lbl, MASK_UNPICKABLE);
	res:update_mh(mouseh);
	res:switch_state("active");
	return res;
end

local function bar_resize(bar, neww, newh)
	if (not neww or neww <= 0 or not newh or newh <= 0) or
		(neww == bar.width and newh == bar.height) then
		return;
	end

	local domupd = newh ~= bar.height;
	bar.width = neww;
	bar.height = newh;
	resize_image(bar.anchor, bar.width, bar.height);

	if (domupd) then
		bar:invalidate();
	else
		bar:relayout();
	end
end

local function bar_relayout_horiz(bar)
	resize_image(bar.anchor, bar.width, bar.height);

-- first figure out area allocations, ignore center if they don't fit
-- currently don't handle left/right not fitting, return min-sz. also
-- Center area is fill-fair at the moment, no weights are considered.

	local relay = function(afn)
		local lx = 0;
		for k,v in ipairs(bar.buttons.left) do
			local w, h = v:dimensions();
			local yp = h ~= bar.height and math.floor(0.5 * (bar.height) - h) or 0;
			yp = yp < 0 and 0 or yp;
			afn(v.bg, lx, yp);
			lx = lx + w;
		end

		local rx = bar.width;
		for k,v in ipairs(bar.buttons.right) do
			local w, h = v:dimensions();
			rx = rx - w;
			local yp = h ~= bar.height and math.floor(0.5 * (bar.height) - h) or 0;
			yp = yp < 0 and 0 or yp;
			afn(v.bg, rx, yp);
		end
		return lx, rx;
	end

	local ca = 0;
	for k,v in ipairs(bar.buttons.center) do
		local w, h = v:dimensions();
		ca = ca + w;
	end

-- we have an overflow, abort
	local lx, rx = relay(function() end);
	if (lx > rx) then
		return lx - rx;
	end

	local lx, rx = relay(move_image);

	if (ca == 0) then
		return 0;
	end

	local nvis = #bar.buttons.center;
	for i,v in ipairs(bar.buttons.center) do
		if (v.hidden) then
			nvis = nvis - 1;
		end
	end

	local fair_sz = nvis > 0 and math.floor((rx -lx)/nvis) or 0;
	for k,v in ipairs(bar.buttons.center) do
		if (not v.hidden) then
			v.minw = fair_sz;
			v.maxw = fair_sz;
			v.minh = bar.height;
			v.maxh = bar.height;
			button_labelupd(v, nil, v.timeout, v.timeout_str);
			move_image(v.bg, lx, 0);
			lx = lx + fair_sz;
		end
	end

	return 0;
end

-- note that this kills multiple returns
local function chain_upd(bar, fun, tag)
	return function(...)
		local rv = fun(...);
		bar:relayout();
		return rv;
	end
end

-- add some additional parameters to the normal button construction,
-- align defines size behavior in terms of under/oversize. left/right takes
-- priority, center is fill and distribute evenly (or limit with minw/minh)
local function bar_button(bar, align, bgshname, lblshname,
	lbl, pad, fontfn, minw, minh, mouseh)
	assert(bar.buttons[align] ~= nil);
	assert(type(fontfn) == "function");

-- autofill in the non-dominant axis
	local fill = false;
	if (not minh) then
		minh = bar.height;
		fill = true;
	end

	local btn = uiprim_button(bar.anchor, bgshname, lblshname,
		lbl, pad, fontfn, minw, minh, mouseh);

	if (not btn) then
		warning("couldn't create button");
		return;
	end
	btn.autofill = true;

	table.insert(bar.buttons[align], btn);
-- chain to the destructor so we get removed immediately
	btn.destroy = function()
		local ind;
		for i,v in ipairs(bar.buttons[align]) do
			if (v == btn) then
				ind = i;
				break;
			end
		end
		assert(ind ~= nil);
		table.remove(bar.buttons[align], ind);
		button_destroy(btn);
		bar:relayout();
	end
	btn.update = chain_upd(bar, btn.update, "update");
	btn.hide = chain_upd(bar, btn.hide, "hide");
	btn.show = chain_upd(bar, btn.show, "show");

	if (align == "center") then
		btn:constrain(pad);
		btn.constrain = function() end
	end

	bar:relayout();
	return btn;
end

local function bar_state(bar, state, cascade)
	assert(state);
	if (bar.shader) then
		bar.state = state;
		shader_setup(bar.anchor, "ui", bar.shader, state);
	end

-- may want to forward some settings to all buttons (titlebar is one case)
	if (cascade) then
		for a, b in pairs(bar.buttons) do
			for i, j in ipairs(b) do
				j:switch_state(state);
			end
		end
	end
end

local function bar_destroy(bar)
	if (valid_vid(bar.anchor)) then
		delete_image(bar.anchor);
	end

	if (bar.name) then
		mouse_droplistener(bar);
	end

	for a,b in pairs(bar.buttons) do
		for i,j in ipairs(b) do
			button_destroy(j);
		end
	end

	for k,v in pairs(bar) do
		bar[k] = nil;
	end
end

local function bar_hide(bar)
	hide_image(bar.anchor);
end

local function bar_show(bar)
	show_image(bar.anchor);
end

local function bar_move(bar, newx, newy, time, interp)
	move_image(bar.anchor, newx, newy, time, interp);
end

local function bar_update(bar, group, index, ...)
	assert(bar.buttons[group] ~= nil);
	assert(bar.buttons[group][index] ~= nil);
	bar.buttons[group][index]:update(...);
end

local function bar_invalidate(bar, minw, minh)
	for k,v in pairs(bar.buttons) do
		for i,j in ipairs(v) do

			if (j.autofill) then
				j.minh = bar.height;
			else
				if (minw and j.minw and j.minw > 0) then
					j.minw = minw;
				end
				if (minh and j.minh and j.minh > 0) then
					j.minh = minh;
				end
			end

			j:update();
		end
	end
	bar:relayout();
end

local function bar_reanchor(bar, anchor, order, xpos, ypos, anchorp)
	link_image(bar.anchor, anchor, anchorp);
	move_image(bar.anchor, xpos, ypos);
	order_image(bar.anchor, order);
end

local function bar_iter(bar)
	local tbl = {};
	for k,v in pairs(bar.buttons) do
		for i,r in ipairs(v) do
			table.insert(tbl, r);
		end
	end

	local c = #tbl;
	local i = 0;

	return function()
		i = i + 1;
		if (i <= c) then
			return tbl[i];
		else
			return nil;
		end
	end
end

local function bar_tick(bar)
	for i in bar_iter(bar) do
		i:tick();
	end
end

-- work as a horizontal stack of uiprim_buttons,
-- manages allocation, positioning, animation etc.
function uiprim_bar(anchor, anchorp, width, height, shdrtgt, mouseh)
	assert(anchor);
	assert(anchorp);
	width = width > 0 and width or 1;
	height = height > 0 and height or 1;

	local res = {
		anchor = fill_surface(width, height, 255, 0, 0),
		shader = shdrtgt,
		buttons = {
			left = {},
			right = {},
			center = {}
		},
		state = "active",
		shader = shdrtgt,
		width = width,
		height = height,
		resize = bar_resize,
		invalidate = bar_invalidate,
		relayout = bar_relayout_horiz,
		switch_state = bar_state,
		add_button = bar_button,
		update = bar_update,
		reanchor = bar_reanchor,
		all_buttons = bar_iter,
		hide = bar_hide,
		show = bar_show,
		move = bar_move,
		tick = bar_tick,
		destroy = bar_destroy
	};

	link_image(res.anchor, anchor, anchorp);
	show_image(res.anchor, anchor);
	image_inherit_order(res.anchor, true);
	order_image(res.anchor, 1);

	res:resize(width, height);
	res:switch_state("active");

	if (mouseh) then
		res.own = function(ctx, vid)
			return vid == res.anchor;
		end

		local lsttbl = {};
		res.name = "uiprim_bar_handler";
		for k,v in pairs(mouseh) do
			res[k] = function(ctx, ...)
				v(res, ...);
			end
			table.insert(lsttbl, k);
		end

		mouse_addlistener(res, lsttbl);
	else
		image_mask_set(res.anchor, MASK_UNPICKABLE);
	end

	return res;
end

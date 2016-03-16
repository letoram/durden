-- Copyright 2016, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: First attempt of abstracting some of the primitive
-- UI elements that were incidentally developed as part of durden.
--
local function button_labelupd(btn, lbl)
	local txt, lineh, w, h, asc;
	local fontstr, offsetf = btn.fontfn();

-- keep this around so we can update if the fontfn changes
	if (lbl == nil) then
		lbl = btn.last_lbl;
	else
		btn.last_lbl = lbl;
	end

-- allow string or prerendered, only update lbl on new content
	if (type(lbl) == "string" or type(lbl) == "table") then
		if (type(lbl) == "string") then
			lbl = {fontstr, lbl};
		else
			lbl[1] = fontstr .. lbl[1];
		end

		if (btn.lbl) then
			txt, lineh, w, h, asc = render_text(btn.lbl, lbl);
		else
			txt, lineh, w, h, asc = render_text(lbl);
		end

		if (not valid_vid(txt)) then
			warning("error updating button label");
			return;
-- switch from icon based label to text based
		elseif (txt ~= btn.lbl and valid_vid(btn.lbl)) then
			delete_image(btn.lbl);
		end
		btn.lbl = txt;
		btn.yshift = -offsetf;

-- just resize / relayout
	elseif (not valid_vid(lbl)) then
		if (not btn.lbl) then
			warning("button_labelupd() with broken lbl");
			return;
		end

		local props = image_surface_properties(btn.lbl);
		w = props.width;
		h = props.height;

	else
		if (valid_vid(btn.lbl) and btn.lbl ~= lbl) then
			delete_image(btn.lbl);
		end
		local props = image_surface_properties(lbl);
		btn.lbl = lbl;
		btn.yshift = 0;
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
	image_tracetag(btn.lbl, btn.name .. "_label");
	resize_image(btn.bg, btn.w, btn.h);
	link_image(btn.lbl, btn.bg);
	image_mask_set(btn.lbl, MASK_UNPICKABLE);
	image_clip_on(btn.lbl, CLIP_SHALLOW);
	center_image(btn.lbl, btn.bg, ANCHOR_C, 0, btn.yshift);
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
	assert(pad);

	btn.pad = pad;
	btn.minw = minw;
	btn.minh = minh;
	btn.maxw = maxw;
	btn.maxh = maxh;

	btn:update();
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
		constrain = button_constrain
	};

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
	if (mouseh) then
		res.own = function(ctx, vid)
			return vid == res.bg;
		end

		local lsttbl = {};
		res.name = "uiprim_button_handler";
		for k,v in pairs(mouseh) do
			res[k] = function(ctx, ...)
				v(res, ...);
			end
			table.insert(lsttbl, k);
		end

		mouse_addlistener(res, lsttbl);
	else
		image_mask_set(res.bg, MASK_UNPICKABLE);
	end

	res:switch_state("active");
	return res;
end

local function bar_resize(bar, neww, newh)
	assert(neww and neww > 0);
	assert(newh and newh > 0);
	if (neww == bar.width and newh == bar.height) then
		return;
	end

	local domupd = (bar.vertical and neww ~= bar.width) or
		(not bar.vertical and newh ~= bar.height);

	bar.width = neww;
	bar.height = newh;
	resize_image(bar.anchor, bar.width, bar.height);

	if (domupd) then
		bar:invalidate();
	end

	bar:relayout();
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
			afn(v.bg, lx, yp);
			lx = lx + w;
		end

		local rx = bar.width;
		for k,v in ipairs(bar.buttons.right) do
			local w, h = v:dimensions();
			rx = rx - w;
			local yp = h ~= bar.height and math.floor(0.5 * (bar.height) - h) or 0;
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

	local fair_sz = math.floor((rx -lx)/ #bar.buttons.center);
	for k,v in ipairs(bar.buttons.center) do
		v.minw = fair_sz;
		v.maxw = fair_sz;
		v.minh = bar.height;
		v.maxh = bar.height;
		button_labelupd(v);
		move_image(v.bg, lx, 0);
		lx = lx + fair_sz;
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
	if (not bar.vertical) then
		if (not minh) then
			minh = bar.height;
			fill = true;
		end
	else
		if (not minw) then
			minw = bar.width;
			fill = true;
		end
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

local function bar_invalidate(bar)
	for k,v in pairs(bar.buttons) do
		for i,j in ipairs(v) do

			if (j.autofill) then
				if (bar.vertical) then
					j.minw = bar.width;
				else
					j.minh = bar.height;
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

-- work as a vertical or horizontal stack of uiprim_buttons,
-- manages allocation, positioning, animation etc.
function uiprim_bar(anchor, anchorp, width, height, shdrtgt, mouseh)
	assert(anchor);
	assert(anchorp);
	assert(width > 0);
	assert(height > 0);

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
		hide = bar_hide,
		show = bar_show,
		move = bar_move,
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

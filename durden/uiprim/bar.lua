-- Copyright: 2015-2019, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: This is a rather messy implementation of a button
-- bar and it is used for both the statusbar, window titlebar and
-- possible docks and so on.
--
-- A reason for this mess is also that is was written before dpi-
-- awareness on the rendertarget level, so we stuck to one fixed
-- durden- dpi then patch the font-size accordingly. Just having
-- a relayout trigger on dpi swap should be enough these days.
--
--
local function btn_clamp(btn, w, h)
-- done with label, figure out new button size including padding and minimum
	if (btn.minw and btn.minw > 0 and w < btn.minw) then
		w = btn.minw;
	end

	if (btn.minh and btn.minh > 0 and h < btn.minh) then
		h = btn.minh;
	end

	if (btn.maxw and btn.maxw > 0 and w > btn.maxw) then
		w = btn.maxw;
	end

	if (btn.maxh and btn.maxh > 0 and w > btn.maxh) then
		h = btn.maxh;
	end
	return w,h;
end

local function button_labelupd(btn, lbl, timeout, timeoutstr)
	local txt, lineh, w, h, asc;
	local fontstr, offsetf = btn.fontfn();

-- fill area as notification may want a timeout
	if (timeout and timeout > 0) then
		btn.timeout = timeout;
		btn.timeout_lbl = timeoutstr and timeoutstr or "";
	end

-- if it just means to repeat the last label, then we just
-- prepend the new font-str
	local append = true;
	if (lbl == nil) then
		lbl = btn.last_lbl;
		append = false;
	end

-- keep this around so we can update if the fontfn changes
	if (type(lbl) == "string" or type(lbl) == "table") then
		if (type(lbl) == "string") then
			lbl = {fontstr, lbl};
		elseif (append) then
			lbl[1] = fontstr .. lbl[1];
		else
			lbl[1] = fontstr;
		end
		btn.last_lbl = lbl;

		if (valid_vid(btn.lbl)) then
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
		btn.w, btn.h = btn_clamp(btn, w, h);
-- just resize / relayout
	elseif type(lbl) == "function" then
		btn.last_lbl = lbl;

-- subtle on the sharing mechanics here, the ownership of the returned
-- vid should belong to the caller, as the linking and deleting will occur
-- here
		lbl = lbl(btn.minh);
		if (not valid_vid(lbl)) then
			return;
		end
		if (valid_vid(btn.lbl) and btn.lbl ~= lbl) then
			delete_image(btn.lbl);
		end
		local props = image_storage_properties(lbl);
		btn.lbl = lbl;
		btn.w, btn.h = btn_clamp(btn, props.width, props.height);
		resize_image(lbl, btn.w, btn.h);
		offsetf = 0;
	end

-- finally make the visual changes
	image_tracetag(btn.lbl, btn.lbl_tag);
	reset_image_transform(btn.bg);
	resize_image(btn.bg, btn.w, btn.h, btn.anim_time, btn.anim_func);
	link_image(btn.lbl, btn.bg);
	force_image_blend(btn.lbl, BLEND_FORCE);
	image_mask_set(btn.lbl, MASK_UNPICKABLE);
	image_clip_on(btn.lbl, CLIP_SHALLOW);

-- for some odd cases (center area on bar for instance),
-- specific lalign on text may be needed
	local xofs = btn.align_left and 0 or
		(0.5 * (btn.w - image_surface_properties(btn.lbl).width));

	reset_image_transform(btn.lbl);
	move_image(btn.lbl, xofs, offsetf, btn.anim_time, btn.anim_func);
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
function uiprim_button(anchor, bgshname,
	lblshname, lbl, pad, fontfn, minw, minh, mouseh)
	ind = ind + 1;
	assert(pad);

	local res = {
		lblfmt = "\\f,0",
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

-- only need anchor or we should have a real drawn node?
	if (not bgshname) then
		res.bg = null_surface(1, 1);
	else
		res.bg = color_surface(1, 1, 127, 127, 127);
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

local function bar_resize(bar, neww, newh, time, bar_parent)
	if (not neww or neww <= 0 or not newh or newh <= 0) then
		return;
	end

-- if we are running in nested mode, don't accept a resize from anyone
-- other than the parent or reanchor / resize / ... may occur
	if (bar.parent and not bar_parent) then
		return;
	end

	local domupd = newh ~= bar.height;
	bar.width = neww;
	bar.height = newh;
	resize_image(bar.anchor, bar.width, bar.height, time, INTERP_SMOOTHSTEP);

	bar.anim_time = time;
	bar.anim_func = INTERP_SMOOTHSTEP;

	if (domupd) then
		bar:invalidate();
	else
		bar:relayout();
	end

	if (bar.impostor_rz) then
		bar:impostor_rz(neww, newh, time, bar.anim_func);
	end

	bar.anim_time = nil;
end

local function bar_relayout_horiz(bar)
	reset_image_transform(bar.anchor);
	resize_image(bar.anchor,
		bar.width, bar.height, bar.anim_time, bar.anim_func);

-- default hide center as it will matter later
	local nvis = 0;
	for i,v in ipairs(bar.buttons.center) do
		if (not v.hidden) then
			nvis = nvis + 1;
		end
		hide_image(v.bg);
	end

-- first figure out area allocations, ignore center if they don't fit
-- currently don't handle left/right not fitting, return min-sz. also
-- Center area is fill-fair at the moment, no weights are considered.
	local relay = function(afn)
		local lx = 0;
		for k,v in ipairs(bar.buttons.left) do
			local w, h = v:dimensions();
			local yp = h ~= bar.height and math.floor(0.5 * (bar.height) - h) or 0;
			yp = yp < 0 and 0 or yp;
			reset_image_transform(v.bg);
			afn(v.bg, v, w, h, lx, yp, bar.anim_time, bar.anim_func);
			lx = lx + w;
		end

		local rx = bar.width;
		for k,v in ipairs(bar.buttons.right) do
			local w, h = v:dimensions();
			rx = rx - w;
			local yp = h ~= bar.height and math.floor(0.5 * (bar.height) - h) or 0;
			yp = yp < 0 and 0 or yp;
			reset_image_transform(v.bg);
			afn(v.bg, v, w, h, rx, yp, bar.anim_time, bar.anim_func);
		end
		return lx, rx;
	end

	local ca = 0;
	for k,v in ipairs(bar.buttons.center) do
		local w, h = v:dimensions();
		ca = ca + w;
	end

	local lx, rx = relay(
		function(vid, v, w, h, x, y, ...)
			if (x + w > bar.width) then
				hide_image(vid);
			elseif (not v.hidden) then
				show_image(vid);
			end
			move_image(vid, x, y, ...);
		end
	);

	if (ca == 0) then
		return 0;
	end

-- fill region doesn't need to deal with forced- button layout
	local fair_sz = nvis > 0 and math.floor((rx -lx)/nvis) or 0;
	if (fair_sz <= 0) then
-- and completely hide the nested bar instead of relayout
		if (bar.nested) then

-- but it might have been deleted elsewhere, so safeguard
			if (bar.nested.hide) then
				bar.nested:hide();
			else
				bar.nested = nil;
			end
		end

		return;
	end

-- if we are in nested mode, then just forward the layouting process there
	if (bar.nested) then
		if (bar.nested.relayout) then
			bar.nested:show();
			bar.nested:reanchor(bar.anchor, 1, lx, 0);
			bar.nested:resize(rx - lx, bar.height, bar.anim_time, bar);
			return;
		else
			bar.nested = nil;
		end
	end

-- otherwise, sweep the buttons and update labels etc. where appropriate
	for k,v in ipairs(bar.buttons.center) do
		if (not v.hidden) then
			v.minw = fair_sz;
			v.maxw = fair_sz;
			v.minh = bar.height;
			v.maxh = bar.height;
			v.anim_time = bar.anim_time;
			v.anim_func = bar.anim_func;
			button_labelupd(v, nil, v.timeout, v.timeout_str);
			v.anim_func = nil;
			v.anim_time = nil;
			if (lx + v.maxw <= bar.width) then
				show_image(v.bg);
			end
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

local function btn_insert(bar, align,
	bgshname, lblshname, lbl, pad, fontfn, minw, minh, mouseh, opts)

	local btn = uiprim_button(bar.anchor,
		bgshname, lblshname, lbl, pad, fontfn, minw, minh, mouseh);

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
	return btn;
end

-- mass-delete / mass-add grouped buttons
local function bar_group(bar, group, keep_center)
	local lst = {};

-- expensive, so early out on noop
	if (bar.group == group) then
		return;
	end

	local center = (keep_center and bar.buttons.center)
		and bar.buttons.center or {};

-- delete all buttons
	for d,g in pairs(bar.buttons) do
		if (not keep_center or d ~= "center") then
			for _,v in pairs(g) do
				if (valid_vid(v.bg)) then
					delete_image(v.bg);
				end
				if (v.own) then
					mouse_droplistener(v);
				end
				for k,_ in pairs(v) do
					v[k] = nil;
				end
			end
		end
	end

	bar.buttons = {
		left = {},
		right = {},
		center = center
	};

-- re-add from group and from catch-all 'default', don't use
-- bar:add_button as that would introduce recursion
	for i,v in ipairs(bar.groups["_default"]) do
		if (keep_center and v.align == "center") then
		else
			btn_insert(bar, v.align, v.bgshname, v.lblshname,
				v.lbl, v.pad, v.fontfn, v.minw, v.minh, v.mouseh, v.opts);
		end
	end

	if (bar.groups[group]) then
		for i,v in ipairs(bar.groups[group]) do
		if (keep_center and v.align == "center") then
			else
					btn_insert(bar, v.align, v.bgshname, v.lblshname,
					v.lbl, v.pad, v.fontfn, v.minw, v.minh, v.mouseh, v.opts);
			end
		end
	end

	bar.group = group;
	bar:relayout();
end

-- add some additional parameters to the normal button construction,
-- align defines size behavior in terms of under/oversize. left/right takes
-- priority, center is fill and distribute evenly (or limit with minw/minh)
local function bar_button(bar, align,
	bgshname, lblshname, lbl, pad, fontfn, minw, minh, mouseh, opts)
	opts = opts and opts or {};

	assert(bar.buttons[align] ~= nil);
	assert(type(fontfn) == "function");

-- autofill in the non-dominant axis
	local fill = false;
	if (not minh) then
		minh = bar.height;
		fill = true;
	end

-- defer creation until the group is set as active
	local gtbl = {
		bar = bar, align = align, bgshname = bgshname,
		lblshname = lblshname, lbl = lbl, pad = pad,
		fontfn = fontfn, minw = minw, minh = min, mouseh = mouseh,
		opts = opts
	};

	if (opts.group) then
		local group = opts.group;
		opts.group = nil;
		if (not bar.groups[group]) then
			bar.groups[group] = {};
		end
		table.insert(bar.groups[group], gtbl);

-- exit if the group is not already active
		if (group ~= bar.group) then
			return;
		end
	else
		table.insert(bar.groups["_default"], gtbl);
	end

	local btn = btn_insert(bar, align,
		bgshname, lblshname, lbl, pad, fontfn, minw, minh, mouseh, opts);

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
	if (bar.parent) then
		bar.parent:set_nested()
	end

	if (valid_vid(bar.anchor)) then
		delete_image(bar.anchor);
	end

	if (bar.impostor_mh) then
		mouse_droplistener(bar.impostor_mh);
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

-- key is used as a hack to forcibly block other bar hide management
local function bar_hide(bar, key)
	bar.hidekey = key;
	bar.hidden = true;
	hide_image(bar.anchor);
end

local function bar_show(bar, key)
	if (not bar.hidekey or (key and bar.hidekey == key)) then
		show_image(bar.anchor);
		bar.hidden = false;
	end
end

local function bar_move(bar, newx, newy, time, interp)
	move_image(bar.anchor, newx, newy, time, interp);
end

local function bar_update(bar, group, index, ...)
	assert(bar.buttons[group] ~= nil);
	assert(bar.buttons[group][index] ~= nil);
	bar.buttons[group][index].anim_time = bar.anim_time;
	bar.buttons[group][index].anim_func = bar.anim_func;
	bar.buttons[group][index]:update(...);
	bar.buttons[group][index].anim_time = 0;
	bar.buttons[group][index].anim_func = nil;
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

local function bar_updatemh(bar, mouseh)
	if (mouseh) then
		image_mask_clear(bar.anchor, MASK_UNPICKABLE);
		bar.own = function(ctx, vid)
			return vid == bar.anchor;
		end

		local lsttbl = {};
		bar.name = "uiprim_bar_handler";
		for k,v in pairs(mouseh) do
			bar[k] = function(ctx, ...)
				v(bar, ...);
			end
			table.insert(lsttbl, k);
		end

		mouse_addlistener(bar, lsttbl);
	else
		image_mask_set(bar.anchor, MASK_UNPICKABLE);
	end
end

-- [rz_fun] callback(ctx, w, h) on every resize
-- [mh_tbl] mousehandler qualifying table
local function bar_impostor(tbar, vid, rz_fun, mh_tbl)
	if (valid_vid(tbar.impostor)) then
		delete_image(tbar.impostor);
		mouse_droplistener(tbar.impostor_mh);
	end

	if (mh_tbl) then
		mh_tbl.own = function(ctx, vid)
			return tbar.impostor_active and vid == tbar.impostor_vid;
		end
		mh_tbl.name = "tbar_impostor";
		local list = {};
		for k,v in pairs(mh_tbl) do
			table.insert(list, k);
		end
		tbar.impostor_mh = mh_tbl;
		mouse_addlistener(tbar.impostor_mh, list);
	end
	tbar.impostor_vid = vid;
	tbar.impostor_rz = type(rz_fun) == "function" and rz_fun or nil;

-- let the impostor physicaly order higher than the bar, and
-- inherit the order so the two may 'slightly' coexist.
	link_image(vid, tbar.anchor, ANCHOR_LL);
	move_image(vid, 0, -(image_surface_properties(vid).height));
	image_inherit_order(vid, true);
	order_image(vid, 5);
	tbar.impostor_active = true;
end

-- swap back and forth between impostor managed and client managed
local function bar_impostor_swap(tbar)
	if (not valid_vid(tbar.impostor_vid)) then
		return;
	end

	if (tbar.impostor_active) then
		tbar.impostor_active = false;
		blend_image(tbar.impostor_vid, 0.0, gconfig_get("animation"));
	else
		tbar.impostor_active = true;
		blend_image(tbar.impostor_vid, 1.0, gconfig_get("animation"));
	end
end

local function bar_impostor_destroy(tbar)
	if (not valid_vid(tbar.impostor_vid)) then
		return;
	end

	delete_image(tbar.impostor_vid);
	mouse_droplistener(tbar.impostor_mh);
	tbar.impostor_active = nil;
	tbar.impostor_vid = BADID;
	tbar.impostor_rz = nil;
	tbar.impostor_mh = nil;
end

-- Setting a bar nested means unhooking the one that is there currently,
-- and determine if we should delete or simply relink and restore previous
-- hide and anchor state. If we inherit, the bar belongs to us and can
-- safely be :destroyed() when we are or when someone else replaces this
-- one.
local function bar_nested(bar, new, closure)
-- closure is responsible for restoring to old owner or destroying,
-- just forward the state if we are in destroy or simply replace
	if (bar.nested_closure) then
		if (bar.nested) then
			bar.nested.parent = nil;
		end
		bar.nested_closure(false);
	end

	bar.nested = nil;
	bar.nested_closure = nil;

-- if no reference is provided, short-out, otherwise assume the caller
-- provides a proper bar reference and not something else
	if (new) then
		new.parent = bar;
	end

	bar.nested = new;
	bar.nested_closure = closure;
	bar:invalidate();
end

-- work as a horizontal stack of uiprim_buttons,
-- manages allocation, positioning, animation etc.
function uiprim_bar(anchor, anchorp, width, height, shdrtgt, mouseh)
	assert(anchor);
	assert(anchorp);
	width = width > 0 and width or 1;
	height = height > 0 and height or 1;

	local res = {
-- normal visual tracking options, the scale-factor used comes
-- from the display we are attached to, a tiler- scale invokes
-- rebuild
		anchor = color_surface(width, height, unpack(gconfig_get("titlebar_color"))),
		shader = shdrtgt,
		width = width,
		height = height,

-- split the bar into three groups, left and right take priority,
-- while the center area act as 'fill'.
		buttons = {
			left = {},
			right = {},
			center = {}
		},

-- buttons can be grouped into sets that gets switched back and forth,
-- possibly rebuilding / saving the gpu- resources while doing so
		groups = {},
		group = "default",
		add_button = bar_button,
		all_buttons = bar_iter,
		hide_buttons = bar_buttons_hide,
		show_buttons = bar_buttons_show,
		switch_group = bar_group,

-- variations of resizing the bar, updating all state and relayouting
		resize = bar_resize,
		invalidate = bar_invalidate,
		relayout = bar_relayout_horiz,

-- used for animation invalidation and input handling switches
		update = bar_update,
		update_mh = bar_updatemh,

-- reanchor to another UI component, needed when switching titlebar mode
-- for something like tabbed mode
		reanchor = bar_reanchor,

-- an impostor is an external vid that takes the place of the bar
		set_impostor = bar_impostor,
		swap_impostor = bar_impostor_swap,
		destroy_impostor = bar_impostor_destroy,
		set_nested = bar_nested,

-- mark all buttons and the bar as having a specific state (e.g. alert)
		switch_state = bar_state,
		state = "active",

-- bar visibility / livecycle
		hide = bar_hide,
		show = bar_show,
		move = bar_move,
		tick = bar_tick,

		destroy = bar_destroy
	};

	res.groups["_default"] = {};
	link_image(res.anchor, anchor, anchorp);
	show_image(res.anchor, anchor);
	image_inherit_order(res.anchor, true);
	order_image(res.anchor, 1);

	res:resize(width, height);
	res:switch_state("active");
	res:update_mh(mouseh);

	return res;
end

local function lbar_props()
	local pos = gconfig_get("lbar_position");
	local dir = 1;
	local wm = active_display();
	local barh = gconfig_get("lbar_sz") * wm.scalef;
	local yp = 0;

	yp = math.floor(0.5*(wm.height-barh));

	return yp, barh, dir;
end

local function hlp_add_btn(ctx, helper, lbl)
	local yp, tileh, dir = lbar_props();
	local pad = gconfig_get("lbar_tpad") * active_display().scalef;

	local res = {};
	local dsti = #helper+1;
	local path = ctx:get_path();

-- click is iterate cancel the same amount of times as current count to index,
-- use of menu_cancel here is unfortunate - we should propagate the right esc-
-- handler for dependency management reasons.
	res.btn =
	uiprim_button(active_display().order_anchor,
		"lbar_tile", "lbar_tiletext", lbl, pad,
		active_display().font_resfn, 0, tileh,
		{
			click = function()
				local nstep = #helper - dsti;
				if (nstep > 0) then
					for i=1,nstep do
						ctx:on_cancel();
					end
				end
			end
		}
	);

-- if ofs + width, compact left and add a "grow" offset on pop
	res.ofs = #helper > 0 and helper[#helper].ofs or 0;
	res.yofs = (tileh + 1) * dir;
	move_image(res.btn.bg, res.ofs, res.yofs);
	move_image(res.btn.bg, res.ofs, yp); -- switch, lbar height
	nudge_image(res.btn.bg, 0, res.yofs, gconfig_get("animation") * 0.5, INTERP_SINE);
	if (#helper > 0) then
		helper[#helper].btn:switch_state("inactive");
	end
	res.ofs = res.ofs + res.btn.w + 5;
	table.insert(helper, res);
end

local function buttonlist_push(ctx, new, lbl, meta)
	table.insert(ctx.path, new);
	table.insert(ctx.meta, meta and meta or {});
	hlp_add_btn(ctx, ctx.helper, lbl);
	return ctx:get_path();
end

local function buttonlist_pop(ctx)
	local path = ctx.path;
	local helper = ctx.helper;
	table.remove(path, #path);
	local meta = table.remove(ctx.meta, #ctx.meta);
	local res = ctx:get_path();
	local as = gconfig_get("animation") * 0.5;
	local hlp = helper[#helper];
	if (not hlp) then
		return res, meta;
	end

	blend_image(hlp.btn.bg, 0.0, as);
	if (as > 0) then
		tag_image_transform(
			hlp.btn.bg, MASK_OPACITY,
			function()
				hlp.btn:destroy();
			end
		);
	else
		hlp.btn:destroy();
	end

	table.remove(helper, #helper);
	if (#helper > 0) then
		helper[#helper].btn:switch_state("active");
	end

	return res, meta;
end

--
-- Switch path for the buttonlist, apply push/pop accordingly,
-- uses query to get metadata (label, context tag)
--
local function buttonlist_set(ctx, path, query)
	if (not path or path == "/" or path == "") then
		ctx:reset();
		return;
	end

-- support both explicit first / and implicit
	local fch = string.sub(path, 1, 1);
	local lst = string.split(path, "/");
	if (fch == "/") then
		table.remove(lst, 1);
	end

-- retain valid prefix
	if (#lst == 0) then
		ctx:reset();
		return;
	end

-- check how many elements that are already in the prefix
	local count = 0;
	for i=1,#lst do
		if (not ctx.path[i]) then
			break;
		end

		if (ctx.path[i] == lst[i]) then
			count = count + 1;
		else
			break;
		end
	end

-- remove any superflous ones
	while (#ctx.path > count) do
		ctx:pop();
	end

-- now add buttons to match the new entries of the path
	local prepath = "";

	for i=count+1,#lst do
		prepath = prepath .. "/" .. lst[i];
		local name, tag;
		if (query) then
			name, tag = query(prepath, i, lst[i]);
		else
			name = lst[i];
			tag = {};
		end
		ctx:push(lst[i], name, tag);
	end
end

local function buttonlist_reset(ctx, prefix)
	for k,v in ipairs(ctx.helper) do
		v.btn:destroy();
	end
	ctx.helper = {};
	ctx.path = {};
	ctx.meta = {};
	iostatem_restore();
end

-- uglier than one might think, the whole 'concat' behavior will add ugly
-- edges for / and /node. If we prefix or suffix with '/', split operations
-- will be wrong - if we don't, the concat path gets // polution.
local function buttonlist_get_path(ctx, trail)
	if (#ctx.path == 0) then
		return "/";
	else
		return "/" .. table.concat(ctx.path, "/") .. (trail and "/" or "");
	end
end

function uiprim_buttonlist()
	return {
		helper = {}, -- for managing activated helpers etc.
		path = {}, -- track namespace path
		meta = {}, -- for meta-data history (input message, filter settings, pos)
		get_path = buttonlist_get_path,
		reset = buttonlist_reset,
		pop = buttonlist_pop,
		push = buttonlist_push,
		set_path = buttonlist_set,
		on_cancel = function() end -- override for click to escape
	};
end

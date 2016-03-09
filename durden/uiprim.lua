-- Copyright 2016, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: First attempt of abstracting some of the primitive
-- UI elements that were incidentally developed as part of durden.
--

local function button_labelupd(btn, lbl)
	local txt, lineh, w, h;
	local fontstr, offsetf = btn.fontfn();
	local yshift = 0;

-- allow string or prerendered, only update lbl on new content
	if (type(lbl) == "string") then
		if (btn.textlbl) then
			if (btn.textlbl == lbl) then
				local props = image_surface_properties(btn.lbl);
				w = props.width;
				h = props.height;
			else
				txt, lineh, w, h = render_text(btn.textlbl, {fontstr, lbl});
				if (not valid_vid(txt)) then
					warning("error updating button label");
					return;
				end
			end
-- need to render new
		else
			txt, lineh, w, h = render_text({fontstr, lbl});
			btn.textlbl = lbl;
			if (not valid_vid(txt)) then
				warning("error updating button label");
				return;
-- switch from icon based label to text based
			elseif (valid_vid(btn.lbl)) then
				delete_image(btn.lbl);
			end
			btn.lbl = txt;
		end
		yshift = h - (h * offsetf);
	elseif (not valid_vid(lbl)) then
		warning("button_labelupd() with broken lbl");
		return;
-- we adopt lbl and use as icon
	else
		btn.textlbl = nil;
		if (valid_vid(btn.lbl) and btn.lbl ~= lbl) then
			delete_image(btn.lbl);
		end
		local props = image_surface_properties(lbl);
		btn.lbl = lbl;
		w = props.width;
		h = props.height;
	end

-- figure out new size, including padding and minimums
	if (btn.minw > 0) then
		w = w < btn.minw and btn.minw or w;
	end
	if (btn.minh > 0) then
		h = h < btn.minh and btn.minh or h;
	end
	btn.w = w + 2 * btn.pad;
	btn.h = h + 2 * btn.pad;

-- finally make the visual changes
	image_tracetag(btn.lbl, btn.name .. "_label");
	resize_image(btn.bg, btn.w, btn.h);
	link_image(btn.lbl, btn.bg);
	center_image(btn.lbl, btn.bg, ANCHOR_C, 0, yshift);
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
	if (btn.state ~= newstate) then
		btn.state = newstate;
		shader_setup(btn.bg, "ui", btn.bgsh, newstate);
		shader_setup(btn.lbl, "ui", btn.lblsh, newstate);
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
	local res = {
		bg = fill_surface(1, 1, 255, 0, 0),
		lblfmt = "\\f,0\\#ffffff",
		bgsh = bgshname,
		lblsh = lblshname,
		fontfn = fontfn,
		state = "active",
		minw = 0,
		minh = 0,
		pad = pad,
		name = "uiprim_btn_" .. tostring(ind),
-- exposed methods
		update = button_labelupd,
		destroy = button_destroy,
		switch_state = button_state
	};

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
	shader_setup(res.bg, "ui", res.bgsh, "active");

	res:update(lbl);

	if (clickh) then
		res.own = function(ctx, vid)
			return vid == res.bg or vid == res.lbl
		end

		local lsttbl = {};
		res.name = "uiprim_button_handler";
		for k,v in pairs(mouseh) do
			res[k] = function(ctx, ...)
				v(res, unpack(arg));
			end
			table.insert(lsttbl, k);
		end

		mouse_addlistener(res, lsttbl);
	end

	return res;
end

-- work as a vertical or horizontal stack of uiprim_buttons,
-- manages allocation, positioning, animation etc.
function uiprim_buttongroup()

end

-- [quick and dirty dumb notification widget]
--
-- improvements:
--  layout / color controls
--  control buttons (dismiss, to clipboard, focus window, ...)
--  a hook to refill/update if new notifications arrive
--  while navigating the lbar
--

local bgc_def = {32, 32, 32};
local bgc_act = {16, 16, 16};
local bgc_hi = {64, 64, 64};

local queue = {};
local test_queue = {
	{
		source = "test",
		sym = fill_surface(64, 64, 127, 127, 0),
		short = "short text id",
		long = "this is a much longer text to make sure to see that " ..
			"we break properly (with english) at least ",
		urgency = 1,
	},
	{
		source = "test2",
		short = "short text, no sym, no long",
		urgency = 3
	},
	{
		source = "test3",
		sym = fill_surface(32, 32, 127, 127, 0),
		short = "third test, chaining",
		long = "this also has a longer on over description that we " ..
			"try to show whenever it is possible ",
		urgency = 1
	}
};

notification_register("notification_widget",
	function(source, sym, short, long, urgency)
		if (valid_vid(sym)) then
			local lsym = null_surface(sym, 64, 64);
			image_sharestorage(sym, lsym);
			sym = lsym;
		end
		table.insert(queue, {
			source = source,
			sym = sym,
			short = short,
			long = long,
			urgency = urgency
		});
	end
);

-- only ever consume 0 or 1 groups
local function probe(ctx, yh)
	return #queue > 0 and 1 or 0;
end

local old_over = {};

local function build_entry(anchor, ent, max_w)
	local backdrop = color_surface(32, 32, bgc_def[1], bgc_def[2], bgc_def[3]);
	if (not valid_vid(backdrop)) then
		return;
	end

	local res = {
		anchor = backdrop,
		destroy = function(ctx)
			mouse_droplistener(ctx);
		end,
		name = "notification_entry",

-- expand / collapse, clipping / linking does all the hard work
		over = function(ctx)
			if (old_over.vid ~= backdrop and ctx.long_height) then
				image_color(backdrop, bgc_hi[1], bgc_hi[2], bgc_hi[3]);
			end
		end,
		out = function(ctx)
			if (old_over.vid ~= backdrop) then
				image_color(backdrop, bgc_def[1], bgc_def[2], bgc_def[3]);
			end
		end,
		rclick = function(ctx)
			if (not ent.long or #ent.long == 0) then
				return;
			end
			CLIPBOARD:set_global(ent.long, backdrop);
		end,
		click = function(ctx)
			if (not ctx.long_height) then
				return;
			end
			if (valid_vid(old_over.vid)) then
				instant_image_transform(old_over.vid);
				resize_image(old_over.vid, max_w, old_over.height, 10);
				tag_image_transform(backdrop, MASK_SCALE, function()
					image_color(backdrop, bgc_def[1], bgc_def[2], bgc_def[3]);
				end);
				old_over.vid = nil;
				return;
			end
			instant_image_transform(backdrop);
			resize_image(backdrop, max_w, ctx.long_height, 10);
			image_color(backdrop, bgc_act[1], bgc_act[2], bgc_act[3]);
			old_over.vid = backdrop;
			old_over.height = ctx.short_height;
		end,
		own = function(ctx, vid)
			return vid == backdrop;
		end
	};

-- render both the normal and the short form, use clipping to hide long
	local fd = active_display().font_delta;

	local fmt = {
		fd .. HC_PALETTE[ent.urgency],
		string.format("%s %s%s", ent.source,
		ent.short,
		ent.long and " ... " or ""),
		"\\r\\n\\r\\n\\#ffffff"
	};
	local w, h = text_dimensions({fmt[1], fmt[2]});
	if (valid_vid(ent.sym)) then
		if (h < 32) then
			h = 32;
		end
		fmt[1] = string.format("\\e%d,%d,%d,  ", ent.sym, h - 4, h - 4) .. fmt[1];
		w, h = text_dimensions({fmt[1], fmt[2]});
	end
	res.short_height = h + 5;

-- Step word by word (until last) and split every time we overflow.
-- The results aren't very pretty and fails on internationalization,
-- but need to start somewhere.
	if (ent.long) then
		local words = string.split(ent.long, " ");
		local cstr = "";
		local wc = 0;
		repeat
			local newstr = cstr .. " " .. words[1];
			local w, h = text_dimensions({fmt[1], newstr});
			wc = wc + 1;
			if (w < max_w) then
				cstr = newstr;
				table.remove(words, 1);
				wc = wc + 1;
			else
-- new line or we need to repeat and chop up the word?
				if (wc > 1 or string.find(cstr, "\n")) then
					table.insert(fmt, string.trim(cstr));
					table.insert(fmt, "\\n\\r");
					cstr = "";
				else
					local len = string.len(words[1]);
					local hlen = math.floor(len * 0.5);
					local h1 = string.sub(words[1], 1, hlen);
					local h2 = string.sub(words[1], hlen+1);
					table.remove(words, 1);
					table.insert(words, 1, h1);
					table.insert(words, 2, h2);
				end
				wc = 0;
			end
		until #words == 0;
		table.insert(fmt, string.trim(cstr));
		local w, h = text_dimensions(fmt);
		res.long_height = h + 20;
	end

	mouse_addlistener(res, {"click", "over", "out", "rclick"});
	local vid, lines, w, h = render_text(fmt);

	if (not valid_vid(vid)) then
		delete_image(backdrop);
		return;
	end
	image_mask_set(vid, MASK_UNPICKABLE);

-- want the text to be naturally clipped, and have the long form
-- simply be clipped out in the default form
	image_inherit_order(vid, true);
	image_inherit_order(backdrop, true);
	order_image(backdrop, 1);
	link_image(vid, backdrop);
	show_image({vid, backdrop});
	image_clip_on(vid, CLIP_SHALLOW);
	order_image(vid, 1);
	link_image(backdrop, anchor, ANCHOR_LL);
	move_image(vid, 5, 5);
	res.width = w + 10;
	resize_image(backdrop, max_w, res.short_height);
	shader_setup(backdrop, "ui", "rounded", "active");

	return res;
end

-- flush as many as possible within the alloted budget
local function show(ctx, anchor, ofs, yh)
-- first-come / first-serve, should we force interactivity in order
-- to get rid of the more severe ones? right now they disappear after
-- being used once.
	local max_w = active_display().width * 0.3;
	local max_h = 0;
	local first = true;

	ctx.list = {};
	table.sort(queue, function(a, b)
		return a.urgency > b.urgency;
	end)

	while(#queue > 0) do
		local ent = build_entry(anchor, queue[1], max_w - 20);
		if (not ent) then
			break;
		end

		local new_h = max_h +
			(ent.long_height and ent.long_height or ent.short_height);
		if (new_h > yh and not first) then
			delete_image(ent.anchor);
			ent:destroy();
			break;
		end

-- The first check is to work around the 'expanded constraints'
-- problem where the long message is so long that it wouldn't
-- fit the group at all, preventing notifications to be visible.
-- This is a subpar solution until we have scrolling in the
-- widget or can split across multiple groups.
		max_h = new_h;
		anchor = ent.anchor;
		first = false;

		if (valid_vid(ent.sym)) then
			delete_image(ent.sym);
		end
		table.remove(queue, 1);
		table.insert(ctx.list, ent);
	end

	return max_w, max_h;
end

local function destroy(ctx)
	if (ctx.list) then
		for _,v in ipairs(ctx.list) do
			v:destroy();
		end
	end
	ctx.list = nil;
end

local function ident(ctx, pathid)
	return gconfig_get("notifications_enable") and #queue > 0;
end

return {
	name = "notification",
	paths = {ident},
	show = show,
	probe = probe,
	destroy = destroy
};

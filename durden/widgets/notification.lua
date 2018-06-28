-- [quick and dirty dumb notification widget]
-- improvements:
--  layout / color controls
--  clickable references
--
local tsupp = system_load("widgets/support/text.lua")();
local queue = {};
local test_queue = {
	{
		source = "test",
		sym = color_surface(64, 64, 127, 127, 0),
		short = "short text id",
		long = "this is a much longer text to make sure to see that " ..
			"we break properly (with english) at least ",
		urgency = 1,
	},
	{
		source = "test2",
		short = "short text, no sym, no long",
		urgency = 3
	}
};

notification_register("notification_widget",
	function(source, sym, short, long, severity)
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
			severity = severity
		});
	end
);

-- only ever consume 0 or 1 groups
local function probe(ctx, yh)
	return #queue > 0 and 1 or 0;
end
local function build_entry(anchor, ent, max_w)
	local backdrop = color_surface(32, 32, 64, 64, 64);
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
			if (not ctx.long_height) then
				return;
			end
			resize_image(backdrop, max_w, ctx.long_height, 10);
		end,
		out = function(ctx)
			if (not ctx.long_height) then
				return;
			end
			resize_image(backdrop, max_w, ctx.short_height, 10);
		end,
		own = function(ctx, vid)
			return vid == backdrop;
		end
	};

-- render both the normal and the short form, use clipping to hide long
	local fd = active_display().font_delta;

	local fmt = {
		fd .. HC_PALETTE[1] .. "\\b",
		string.format("%s %s", ent.source, ent.short)
	};
	local w, h = text_dimensions({fmt[1], fmt[2]});

-- Step word by word (until last) and split every time we overflow.
-- The results aren't very pretty and fails on internationalization,
-- but need to start somewhere.
	if (false and ent.long) then
		local words = string.split(ent.long, " ");
		local cstr = "";
		local i = 0;
		repeat
			local newstr = cstr .. words[i];
			local w, h = text_dimensions({fmt[1], newstr});
			if (w < max_w) then
				cstr = cstr .. " " .. words[i];
				table.remove(words[1]);
			end
		until #words == 0;
	end

	mouse_addlistener(res, {"over", "out"});
	local vid = render_text(fmt);
	if (not valid_vid(vid)) then
		print("render of ", fmt, "failed");
		delete_image(backdrop);
		return;
	end

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
	res.short_height = h + 10;
	resize_image(backdrop, res.width, res.short_height);
	shader_setup(backdrop, "ui", "rounded", "active");

	return res;
end

-- flush as many as possible within the alloted budget
local function show(ctx, anchor, ofs, yh)
-- first-come / first-serve, should we force interactivity in order
-- to get rid of the more severe ones? right now they disappear after
-- being used once.
	local max_w = 0;
	local max_h = 0;
	ctx.list = {};

	table.sort(queue, function(a, b)
		return a.urgency > b.urgency;
	end)

	while(#queue > 0) do
		local ent = build_entry(anchor, queue[1]);
		if (not ent) then
			break;
		end
		max_w = max_w > ent.width and ent.width or max_w;
		max_h = max_h + (ent.long_height and ent.long_height or ent.short_height);

		anchor = ent.anchor;
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
	return #queue > 0;
end

return {
	name = "notification",
	paths = {ident},
	show = show,
	probe = probe,
	destroy = destroy
};

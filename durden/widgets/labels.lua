--
-- label helper that shows the currently exposed labels,
-- current / default bindings and allow you to directly
-- input them by clicking
--

local tsupp = system_load("widgets/support/text.lua")();

local function probe(ctx, yh)
	local wnd = active_display().selected;
	if (not wnd.input_labels or #wnd.input_labels == 0) then
		return 0;
	end

-- preprocess / sort the list of known labels
	local linear = {};
	for k,v in pairs(wnd.input_labels) do
		if (#v[1] > 0) then
			table.insert(linear, v[1]);
		end
	end
	table.sort(linear,
		function(a, b)
			return a < b;
		end
	);

	ctx.mouseh = {};
	ctx.cursor_opa = 0.2;
	ctx.cursor = color_surface(16, 16, 255, 255, 255);
	if (valid_vid(ctx.cursor)) then
		image_inherit_order(ctx.cursor, true);
		image_mask_set(ctx.cursor, MASK_UNPICKABLE);
	end

	return tsupp.setup(ctx, {linear}, yh);
end

local function send_input(dst, lbl)
	local iotbl = {
		kind = "digital",
		label = lbl,
		translated = true,
		active = true,
		devid = 8,
		subid = 8
	};

	dst:input_table(iotbl);
	iotbl.active = false;
	dst:input_table(iotbl);
end

-- show, called with an anchor and a group ofs / position
local function show(ctx, anchor, ofs)
	local w, h, vid, heights = tsupp.show(
		ctx, anchor, ctx.group_cache[ofs], 1, #ctx.group_cache[ofs]);

	if (not valid_vid(vid)) then
		return w, h;
	end

	local lasti = 1;
	local find_index = function(vid, y)
		y = y - image_surface_resolve(vid).y;
		lasti = 1;
		while (lasti < #heights) do
			if (heights[lasti+1] > y) then
				break;
			end
			lasti = lasti + 1;
		end
		return y, lasti;
	end

	local mh = {
		name = "input_widget_" .. tostring(ofs),
		click = function(mctx, vid, x, y)
			local lbl = ctx.group_cache[ofs][lasti];
			local wnd = active_display().selected;
			lbl = table.find_key_i(wnd.input_labels, 1, lbl);
			if (lbl) then
				send_input(wnd, wnd.input_labels[lbl][1]);
				if (valid_vid(ctx.cursor)) then
					blend_image(ctx.cursor, ctx.cursor_opa * 3, 5);
					blend_image(ctx.cursor, ctx.cursor_opa, 5);
				end
			end
		end,
		hover = function(ctx, vid, x, y, active)
		end,
		motion = function(mctx, vid, x, y)
			if (not valid_vid(ctx.cursor)) then
				return;
			end
			local y, ind = find_index(vid, y);
			move_image(ctx.cursor, 0, heights[ind]);
			local sz = heights[ind+1] ~= nil and
				(heights[ind+1]-heights[ind]-1) or heights[2];
			if (sz == 0 or not sz) then
				sz = image_surface_resolve(vid).height;
			end

-- need to re-resolve as our list is sorted
			local wnd = active_display().selected;
			local lbar = tiler_lbar_isactive(true);
			if (not lbar) then
				return;
			end

			local lbl = ctx.group_cache[ofs][lasti];
			lbl = table.find_key_i(wnd.input_labels, 1, lbl);
			if (lbl) then
				lbl = wnd.input_labels[lbl][3];
				lbar:set_helper(lbl and lbl or "");
			end

			resize_image(ctx.cursor, w, sz);
			local props = image_surface_resolve(ctx.cursor);
		end,
		over = function()
			if (not valid_vid(ctx.cursor)) then
				return;
			end
			link_image(ctx.cursor, vid);
			blend_image(ctx.cursor, ctx.cursor_opa);
			order_image(ctx.cursor, 1);
		end,
		out = function()
			if (not valid_vid(ctx.cursor)) then
				return;
			end
--			hide_image(ctx.cursor);
		end,
		own = function(ctx, src)
			return src == vid;
		end
	};

	table.insert(ctx.mouseh, mh);
	mouse_addlistener(mh, {"click", "hover", "over", "out", "motion"});
	image_mask_clear(vid, MASK_UNPICKABLE);

-- also need handlers for click, motion and hover
	return w, h;
end

local function destroy(ctx)
	for i,v in ipairs(ctx.mouseh) do
		mouse_droplistener(v);
	end
	ctx.mouseh = nil;
	if (valid_vid(ctx.cursor)) then
		delete_image(ctx.cursor);
	end
	ctx.group_cache = nil;
end

return {
	name = "labels",
	paths = {"/target/input"},
	show = show,
	probe = probe,
	destroy = destroy
};

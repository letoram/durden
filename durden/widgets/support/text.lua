--
-- Simple support script to generate widgets that take a set of rows
-- and render / split out into groups.
--
-- For use, see ascii.lua
--

-- just cycle this to make it easier to distinguish individual lines
local neutral = "\\#999999";
local log, fmt = suppl_add_logfn("wm")

-- if requested, setup a mouse-handler that calls back on row- clicks
local function setup_mh(ctx, w, h, vid, heights, ofs)
	local lasti = 1;
	ctx.mouseh = {};
	ctx.cursor_opa = 0.2;
	ctx.cursor = color_surface(16, 16, 255, 255, 255);
	if (valid_vid(ctx.cursor)) then
		image_inherit_order(ctx.cursor, true);
		image_mask_set(ctx.cursor, MASK_UNPICKABLE);
	end

-- take a vid and the list of line heights and figure out which line
-- that the current y value best represents, clip so something always
-- gets returned.
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
		name = "input_widget_" .. ctx.name .. "_" .. tostring(ofs),

-- the lasti here in up-scope comes from the find_index call from motion
		click = function(mctx, vid, x, y)
			local lbl = ctx.group_cache[ofs][lasti];

-- debugging trick, dangling mouse handler, traceback will contain name
			if not ctx.group_cache then
				ctx[ctx.name] = nil;
				ctx[ctx.name]();
			end

			if (valid_vid(ctx.cursor)) then
				blend_image(ctx.cursor, ctx.cursor_opa * 3, 5);
				blend_image(ctx.cursor, ctx.cursor_opa, 5);
			end
			if (ctx.on_click) then
				ctx:on_click(lbl, lasti);
			end
		end,

-- have a line oriented selection cursor
		motion = function(mctx, vid, x, y)
			if (not valid_vid(ctx.cursor)) then
				return;
			end
			local y, ind = find_index(vid, y);
			move_image(ctx.cursor, 0, heights[ind]);

-- not each line has the same effective height
			local sz = heights[ind+1] ~= nil and
				(heights[ind+1]-heights[ind]-1) or heights[2];
			if (sz == 0 or not sz) then
				sz = image_surface_resolve(vid).height;
			end
			resize_image(ctx.cursor, ctx.text_w, sz);

-- resolve and forward
			if (ctx.on_motion) then
				local lbl = ctx.group_cache[ofs][lasti];
				ctx:on_motion(lbl, ind);
			end
		end,

-- whenever we enter the surface, relink to the specific group
		over = function()
			if (not valid_vid(ctx.cursor)) then
				return;
			end
			link_image(ctx.cursor, vid);
			blend_image(ctx.cursor, ctx.cursor_opa);
			order_image(ctx.cursor, 1);
		end,
		own = function(ctx, src)
			return src == vid;
		end
	};

-- need to keep a list of active mouse handlers so we can deregister
	table.insert(ctx.mouseh, mh);
	mouse_addlistener(mh, {"click", "over", "motion"});

-- and only have the actual group be the one to receive mouse events
	image_mask_clear(vid, MASK_UNPICKABLE);
end

return {
	setup = function(ctx, groups, yh, click, motion)
-- split based on number of rows that fit
		local gc = 0;
		local fd = active_display().font_delta;
		local tw, th = text_dimensions(fd .. "m1_m2 0000");
		local ul = math.floor(yh / th);

-- slice a table based on the maximum number of rows in the column
		local ct = {};
		local stepg = function(g)
			local ofs = 1;
			local nt = {};

			while (ofs <= #g) do
				table.insert(nt, g[ofs]);
				if ((#g[ofs] == 0 and #nt > 0) or (#nt == ul)) then
					table.insert(ct, nt);
					nt = {};
				end
				ofs = ofs + 1;
			end

			if (#nt > 0) then
				table.insert(ct, nt);
			end
		end
		for _,v in ipairs(groups) do
			stepg(v);
		end
		ctx.group_cache = ct;

-- register mouse handlers if those were provided
		if (type(click) == "function") then
			ctx.on_click = click;
			if (type(motion) == "function") then
				ctx.on_motion = motion;
			end
		end

		return #ctx.group_cache;
	end,
	destroy = function(ctx)
		if (not ctx) then
			return;
		end

		if (ctx.mouseh) then
			for i,v in ipairs(ctx.mouseh) do
				mouse_droplistener(v);
			end
		end
		ctx.mouseh = nil;
		if (valid_vid(ctx.cursor)) then
			delete_image(ctx.cursor);
			ctx.cursor = nil;
		end
		ctx.group_cache = nil;
	end,
	show = function(ctx, anchor, tbl, start_i, stop_i, col_w, ofs)
		local cind = 1;
		local out = {};
		local fd = active_display().font_delta;
		local props = image_surface_properties(anchor);
		local col_cnt = col_w and math.floor(props.width / col_w) or 1;

-- start at controlled offset (as we want to be able to let widget mgmt
-- allocate column) and append optional neutral+row-lbl-col + palette-row-data
		for i=start_i,stop_i do
			local lstr = tbl[i];
			local pref;
			if (i == start_i) then
				pref = "";
			else
				pref = (i % col_cnt == 0) and "\\n\\r" or "\\t";
			end

			if (type(tbl[i]) == "table") then
				table.insert(out, pref .. fd .. neutral);
				table.insert(out, tbl[i][1]);
				lstr = tbl[i][2];
				pref = "";
			end

			table.insert(out, pref .. fd .. HC_PALETTE[cind]);
			table.insert(out, lstr);
			cind = cind == #HC_PALETTE and 1 or (cind + 1);
		end

		local vid, heights, outw, outh, asc = render_text(out);
		if (not valid_vid(vid) or #heights == 0) then
			log(fmt(
				"widget_text:status=error:source=%s:start=%d:stop=%d:count=%d:msg=%s",
				ctx.name, start_i, stop_i, #tbl, tbl[start_i]));
			return;
		end

		local pad = suppl_display_ui_pad();
		ctx.text_w = outw;
		local bdw = outw;
		local bdh = (heights[#heights]+outh);
		local bdw = bdw > props.width and props.width or bdw;
		local bdh = bdh > props.height and props.height or bdh;
		local backdrop = color_surface(bdw + pad + pad, bdh + pad + pad, 20, 20, 20);
		shader_setup(backdrop, "ui", "rounded", "active");
		link_image(backdrop, anchor);
		link_image(vid, backdrop);
		image_inherit_order(backdrop, true);
		image_inherit_order(vid, true);
		move_image(vid, pad, pad);
--			center_image(tbl, anchor);
--			center_image(backdrop, anchor);
		show_image({backdrop, vid});
		order_image(backdrop, 1);
		order_image(vid, 1);
		image_clip_on(vid, CLIP_SHALLOW);
		image_clip_on(backdrop, CLIP_SHALLOW);
		image_mask_set(vid, MASK_UNPICKABLE);
		image_mask_set(backdrop, MASK_UNPICKABLE);

		if (ctx.on_click or ctx.on_motion) then
			setup_mh(ctx, bdw, bdh, vid, heights, ofs);
		end

		return bdw + pad + pad, bdh + pad + pad, vid, heights;
	end
};

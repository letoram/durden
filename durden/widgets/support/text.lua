-- just cycle this to make it easier to distinguish
-- individual lines
local neutral = "\\#999999";

return {
	show = function(ctx, anchor, tbl, start_i, stop_i, col_w)
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

		local tbl, heights, outw, outh, asc = render_text(out);
		local bdw = outw + outh;
		local bdh = (heights[#heights]+outh) + outh;
		local bdw = bdw > props.width and props.width or bdw;
		local bdh = bdh > props.height and props.height or bdh;

		if (valid_vid(tbl)) then
			local backdrop = fill_surface(bdw, bdh, 20, 20, 20);
			link_image(backdrop, anchor);
			link_image(tbl, backdrop);
			image_inherit_order(backdrop, true);
			image_inherit_order(tbl, true);
--			center_image(tbl, anchor);
--			center_image(backdrop, anchor);
			show_image({backdrop, tbl});
			order_image(backdrop, 1);
			order_image(tbl, 1);
			image_clip_on(tbl, CLIP_SHALLOW);
			image_clip_on(backdrop, CLIP_SHALLOW);
			image_mask_set(tbl, MASK_UNPICKABLE);
			image_mask_set(backdrop, MASK_UNPICKABLE);
			return bdw, bdh;
		end
	end
};

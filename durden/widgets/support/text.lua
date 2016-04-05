-- just cycle this to make it easier to distinguish
-- individual lines
local palette = {
	"\\#43abc9",
	"\\#b5c689",
	"\\#efd469",
	"\\#f58b4c",
	"\\#cd594a"
};

return {
	show = function(ctx, anchor, tbl, col_w)
		local cind = 1;
		local out = {};
		local fd = active_display().font_delta;
		local props = image_surface_properties(anchor);
		local col_cnt = math.floor(props.width / col_w);

		for i,v in ipairs(tbl) do
			table.insert(out, (i % col_cnt == 0 and "\\n\\r" or "\\t")
				.. fd .. palette[cind]);
			table.insert(out, v);
			cind = cind == #palette and 1 or (cind + 1);
		end
		local tbl, heights, outw, outh, asc = render_text(out);
		if (valid_vid(tbl)) then

			local backdrop = fill_surface(outw * 1.1,
				(heights[#heights]+outh) * 1.1, 20, 20, 20);
			link_image(tbl, anchor);
			link_image(backdrop, anchor);
			image_inherit_order(tbl, true);
			image_inherit_order(backdrop, true);
			center_image(tbl, anchor);
			center_image(backdrop, anchor);
			show_image({backdrop, tbl});
			order_image(tbl, 2);
			order_image(backdrop, 1);
			image_clip_on(tbl, CLIP_SHALLOW);
			image_clip_on(backdrop, CLIP_SHALLOW);
			image_mask_set(tbl, MASK_UNPICKABLE);
			image_mask_set(backdrop, MASK_UNPICKABLE);
			return true;
		end
		return false;
	end
};

-- simple "normal" ascii helper for binding UTF-8 sequences just replicate this
-- with different name and file to get another, with more extended values ..
local tbl = {
'20	  " "'
};

-- just cycle this to make it easier to distinguish
-- individual lines
local palette = {
	"\\#43abc9",
	"\\#b5c689",
	"\\#efd469",
	"\\#f58b4c",
	"\\#cd594a"
};

for i=0x21,0x7e do
	table.insert(tbl, string.format("(%.2x) %c", i, i));
end

for i=0xa0,0xbf do
	table.insert(tbl, string.format("(c2 %.2x) %c%c", i, 0xc2, i));
end

for i=0x80,0xbf do
	table.insert(tbl, string.format("(c3 %.2x) %c%c", i, 0xc3, i));
end

local function show(ctx, anchor)
	local cind = 1;
	local out = {};
	local fd = active_display().font_delta;
	local tw = text_dimensions(fd .. " aa 0000\\t");
	local props = image_surface_properties(anchor);

	for i,v in ipairs(tbl) do
		table.insert(out, (i % 12 == 0 and "\\n\\r" or "\\t") .. fd .. palette[cind]);
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
		return true;
	end
	return false;
end

local function destroy(ctx)
end

return {
	name = "ascii", -- user identifiable string
	paths = {"special:u8"},
	show = show, -- will happen for each uniqo
	destroy = destroy
};

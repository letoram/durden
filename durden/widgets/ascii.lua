-- simple "normal" ascii helper for binding UTF-8 sequences just replicate this
-- with different name and file to get another, with more extended values ..
local tsupp = system_load("widgets/support/text.lua")();

local tbl = {
	{"(20)", "\" \""}
};

for i=0x21,0x7e do
	table.insert(tbl, {string.format("(%.2x)  ", i), string.char(i)});
end

for i=0xa0,0xbf do
	table.insert(tbl, {string.format("(c2 %.2x)  ", i),
		string.char(0xc2)..string.char(i)});
end

for i=0x80,0xbf do
	table.insert(tbl, {string.format("(c3 %.2x)  ", i),
		string.char(0xc3)..string.char(i)});
end

local function probe(ctx, yh)
	local fd = active_display().font_delta;
	local tw, th = text_dimensions(fd .. "(c3 aa) 0000");
	ctx.group_sz = math.floor(yh / th);
	ctx.group_sz = ctx.group_sz > #tbl and #tbl or ctx.group_sz;
	return math.ceil(#tbl / ctx.group_sz);
end

local function show(ctx, anchor, ofs)
	local fd = active_display().font_delta;
	local tw = text_dimensions(fd .. "(c3 aa) 0000");
	local si = 1 + (ofs - 1) * ctx.group_sz;
	local ul = si + ctx.group_sz - 1;
	local ap = image_surface_resolve_properties(anchor);
	ul = ul > #tbl and #tbl or ul;
	return tsupp.show(ctx, anchor, tbl, si, ul, tw);
end

local function destroy(ctx)
end

return {
	name = "ascii", -- user identifiable string
	paths = {"special:u8"},
	show = show,
	probe = probe,
	destroy = destroy
};

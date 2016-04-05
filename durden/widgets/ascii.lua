-- simple "normal" ascii helper for binding UTF-8 sequences just replicate this
-- with different name and file to get another, with more extended values ..
local tsupp = system_load("widgets/support/text.lua")();

local tbl = {
'20	  " "'
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
	local fd = active_display().font_delta;
	local tw = text_dimensions(fd .. " aa 0000\\t");
	tsupp.show(ctx, anchor, tbl, tw);
end

local function destroy(ctx)
end

return {
	name = "ascii", -- user identifiable string
	paths = {"special:u8"},
	show = show,
	destroy = destroy
};

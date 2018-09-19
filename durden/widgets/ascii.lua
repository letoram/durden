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

local function on_click(ctx, lbl, i)
	lbl = lbl[1];
	local start = string.find(lbl, "%(");
	if (not start) then
		return;
	end
	local stop = string.find(lbl, "%)");
	if (not stop or stop + 1 <= start - 1) then
		return;
	end
	local seq = string.sub(lbl, start + 1, stop - 1);
	local lbar = tiler_lbar_isactive(true);
	if (not lbar) then
		return;
	end
	lbar.inp:set_str(seq);
end

local function probe(ctx, yh)
	return tsupp.setup(ctx, {tbl}, yh, on_click, nil);
end

local function show(ctx, anchor, ofs)
	return tsupp.show(ctx, anchor,
		ctx.group_cache[ofs], 1, #ctx.group_cache[ofs], nil, ofs);
end

local function destroy(ctx)
	return tsupp.destroy(ctx);
end

return {
	name = "ascii", -- user identifiable string
	paths = {"special:u8"},
	show = show,
	probe = probe,
	destroy = destroy
};

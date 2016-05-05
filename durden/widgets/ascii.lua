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
	local ul = math.floor(yh / th);

	local ct = {};
	local nt = {};
	local ofs = 1;

	while (ofs < #tbl) do
		table.insert(nt, tbl[ofs]);
		if (#nt == ul) then
			table.insert(ct, nt);
			nt = {};
		end
		ofs = ofs + 1;
	end

	if (#nt > 0) then
		table.insert(ct, nt);
	end

	ctx.group_cache = ct;
	return #ctx.group_cache;
end

local function show(ctx, anchor, ofs)
	return tsupp.show(ctx, anchor, ctx.group_cache[ofs], 1, #ctx.group_cache[ofs]);
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

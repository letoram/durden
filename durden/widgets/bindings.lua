-- simple "normal" ascii helper for binding UTF-8 sequences just replicate this
-- with different name and file to get another, with more extended values ..
local tsupp = system_load("widgets/support/text.lua")();

local function probe(ctx, yh)
	local lst = dispatch_list();
-- group based on meta key presses
	local m1g = {};
	local m2g = {};
	local m1m2g = {};
	local miscg = {};

	for k,v in ipairs(lst) do
		if (string.match(v, "m1_m2")) then
			table.insert(m1m2g, v);
		elseif (string.match(v, "m1_")) then
			table.insert(m1g, v);
		elseif (string.match(v, "m2_")) then
			table.insert(m2g, v);
		else
			table.insert(miscg, v);
		end
	end

	return tsupp.setup(ctx, {m1g, m2g, m1m2g, miscg}, yh);
end

local function show(ctx, anchor, ofs)
	return tsupp.show(ctx, anchor,
		ctx.group_cache[ofs], 1, #ctx.group_cache[ofs], nil, ofs);
end

local function destroy(ctx)
	return tsupp.destroy(ctx);
end

return {
	name = "bindings",
	paths = {"special:custom", "/global/input/bind"},
	show = show,
	probe = probe,
	destroy = destroy
};

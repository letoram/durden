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

		while (ofs < #g) do
			table.insert(nt, g[ofs]);
			if (#nt == ul) then
				table.insert(ct, nt);
				nt = {};
			end
			ofs = ofs + 1;
		end

		if (#nt > 0) then
			table.insert(ct, nt);
		end
	end

-- finally add all to the group cache
	stepg(m1g);
	stepg(m2g);
	stepg(m1m2g);
	stepg(miscg);
	ctx.group_cache = ct;

	return #ctx.group_cache;
end

local function show(ctx, anchor, ofs)
	return tsupp.show(ctx, anchor, ctx.group_cache[ofs], 1, #ctx.group_cache[ofs]);
end

local function destroy(ctx)
end

return {
	name = "bindings",
	paths = {"special:custg"},
	show = show,
	probe = probe,
	destroy = destroy
};

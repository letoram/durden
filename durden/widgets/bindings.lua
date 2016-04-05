-- simple "normal" ascii helper for binding UTF-8 sequences just replicate this
-- with different name and file to get another, with more extended values ..
local tsupp = system_load("widgets/support/text.lua")();

local function probe(ctx, yh)
	ctx.lst = dispatch_list();
	local fd = active_display().font_delta;
	local tw, th = text_dimensions(fd .. "(c3 aa) 0000");
	print(yh, th);
	ctx.group_sz = math.floor(yh / th);
	ctx.group_sz = ctx.group_sz > #ctx.lst and #ctx.lst or ctx.group_sz;
	return math.ceil(#ctx.lst / ctx.group_sz);
end

local function show(ctx, anchor, ofs)
	local lst = ctx.lst;
	local len = 0;
	local lenstr = "";

-- could possibly be smarter and sort by length and arrange so that
-- the rightmost column gets the longest ones (highest chance for clipping)
-- or simply crop the path here
	for k,v in ipairs(lst) do
		if (string.len(v) > len) then
			lenstr = v;
			len = string.len(v);
		end
	end

	if (len == 0) then
		return;
	end

	local si = 1 + (ofs - 1) * ctx.group_sz;
	local ul = si + ctx.group_sz - 1;
	ul = ul > #lst and #lst or ul;
	tsupp.show(ctx, anchor, lst, si, ul);
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

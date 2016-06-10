--
-- Simple "cheat sheet" helper that, based on vim titlebar
-- ident content tries to load the approriate cheat sheet(s)
--
-- should also allow clickable "force spawn new?"
--

local tsupp = system_load("widgets/support/text.lua")();
local sheets = {};

local function reglob()
	local lst = glob_resource("widgets/cheatsheets/*.txt");
	for k,v in ipairs(lst) do
		if (sheets[v] == nil) then
-- open_rawresource, read up to n lines and add to sheets, blocking
			local lines = {};
			if (open_rawresource("widgets/cheatsheets/" .. v)) then
				local line;
				repeat
					line = read_rawresource();
					if (line) then
						table.insert(lines, line);
					end
				until(#lines > 256 or not line);
				close_rawresource();
			end
			if (#lines > 1) then
				sheets[v] = lines;
			end
		end
	end
end

local function probe(ctx, yh)
	local fd = active_display().font_delta;
	local tw, th = text_dimensions(fd .. "(probe)");
	local ul = math.floor(yh / th);

-- divide the cheatsheets across groups, always split on
-- sheet no matter the amount of elements versus vertical space
	local ct = {};
	for k,v in ipairs(ctx.sheetset) do
		local nt = {};
		for i=2,#v do
			table.insert(nt, v[i]);
			if (#nt == ul) then
				table.insert(ct, nt);
				nt = {};
			end
		end
		table.insert(ct, nt);
	end
	ctx.group_cache = ct;
	return #ct;
end

local function show(ctx, anchor, ofs)
	return tsupp.show(ctx, anchor, ctx.group_cache[ofs], 1, #ctx.group_cache[ofs]);
end

local function destroy()
end

-- on root path, find the nodes that have a title that matches a certain set
local function ident(ctx, pathid, strid)
	if (not strid or string.len(pathid) > 1) then
		return;
	end
	ctx.sheetset = {};
	for k,v in pairs(sheets) do
		if (v[1] == "*" or string.match(strid, v[1])) then
			table.insert(ctx.sheetset, v);
		end
	end
	return #ctx.sheetset > 0;
end

reglob();

return {
	name = "cheatsheet",
	paths = {ident},
	show = show,
	probe = probe,
	destroy = destroy
};

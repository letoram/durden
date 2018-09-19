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

local function probe(ctx, yh, sheetset)
	return tsupp.setup(ctx, sheetset, yh);
end

local function show(ctx, anchor, ofs)
	return tsupp.show(ctx, anchor,
		ctx.group_cache[ofs], 1, #ctx.group_cache[ofs], nil, ofs);
end

local function destroy()
end

local function ident(ctx, pathid)
	local wnd = active_display().selected;
	if (pathid ~= "/target" or not wnd or not wnd.ident or not wnd.prefix) then
		return false;
	end

	ctx.sheetset = {};
	local strset = {};
	if (#wnd.ident > 0) then
		table.insert(strset, wnd.ident);
	end
	if (#wnd.prefix > 0) then
		table.insert(strset, wnd.prefix);
	end

-- each sheet can apply either always or pattern match on set of windows tags
	local sheetset = {};
	for k,v in pairs(sheets) do
		if (v[1] == "*") then
			table.insert(sheetset, v);
		else
			for i,j in ipairs(strset) do
				if string.match(j, v[1]) then
					table.insert(sheetset, v);
					break;
				end
			end
		end
	end

	return #sheetset > 0 and sheetset or nil;
end

reglob();

return {
	name = "cheatsheet",
	paths = {ident},
	show = show,
	probe = probe,
	destroy = destroy
};

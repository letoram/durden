-- Just a quick way to show a simple helper message when the menu is used for
-- other purposes, e.g. binding. Add any context detection to 'paths' and then
-- populate the messages in probe.

local tsupp = system_load("widgets/support/text.lua")();

local function probe(ctx, yh)
	local lines = {};

-- can either be a string or a table of strings
	local msg = dispatch_user_message()
	if msg then
		if type(msg) == "table" then
			for _,v in ipairs(table) do
				if type(v) == "string" then
					table.insert(lines, msg)
				end
			end
		elseif type(msg) == "string" then
			table.insert(lines, msg)
		end
	end
	return tsupp.setup(ctx, {lines}, yh);
end

local function show(ctx, anchor, ofs)
	return tsupp.show(ctx, anchor,
		ctx.group_cache[ofs], 1, #ctx.group_cache[ofs], nil, ofs);
end

local function destroy(ctx)
	tsupp.destroy(ctx);
end

return {
	name = "texthelper",
	paths = {
		function(ctx, pathid)
			return dispatch_user_message() ~= nil
		end
	},
	show = show,
	probe = probe,
	destroy = destroy
};

local tsupp = system_load("widgets/support/text.lua")();

local function probe(ctx, yh)
	local lines = {};
	local wnd = active_display().selected;

	table.insert(lines,
		string.format("mouse-handlers : %d", mouse_handlercount()));

	local total, used = current_context_usage();
	table.insert(lines,
		string.format("context-usage: %d / %d", used, total));

	local iostate_dbg = iostatem_debug();
	table.insert(lines,
		string.format("io-state: %s", iostate_dbg));

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
	name = "sysdbg",
	paths = {function(ctx, pathid)
		if (pathid == "/global/system") then
			return DEBUGLEVEL > 0;
		end
	end},
	show = show,
	probe = probe,
	destroy = destroy
};

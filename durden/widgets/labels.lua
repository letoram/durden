--
-- label helper that shows the currently exposed labels,
-- current / default bindings and allow you to directly
-- input them by clicking
--

local tsupp = system_load("widgets/support/text.lua")();

local function send_input(dst, lbl)
	local iotbl = {
		kind = "digital",
		label = lbl,
		translated = true,
		active = true,
		devid = 8,
		subid = 8
	};

	dst:input_table(iotbl);
	iotbl.active = false;
	dst:input_table(iotbl);
end

local function on_click(ctx, lbl, i)
	local wnd = active_display().selected;
	lbl = table.find_key_i(wnd.input_labels, 1, lbl);
	if (not lbl) then
		return;
	end

	send_input(wnd, wnd.input_labels[lbl][1]);
end

local function on_motion(ctx, lbl, i)
-- need to re-resolve as our list is sorted
	local wnd = active_display().selected;
	local lbar = tiler_lbar_isactive(true);
	if (not lbar) then
		return;
	end

	lbl = table.find_key_i(wnd.input_labels, 1, lbl);
	if (lbl) then
		lbl = wnd.input_labels[lbl][3];
		lbar:set_helper(lbl and lbl or "");
	end
end

local function probe(ctx, yh)
	local wnd = active_display().selected;
	if (not wnd.input_labels or #wnd.input_labels == 0) then
		return 0;
	end

-- preprocess / sort the list of known labels
	local linear = {};
	for k,v in pairs(wnd.input_labels) do
		if (#v[1] > 0) then
			table.insert(linear, v[1]);
		end
	end
	table.sort(linear,
		function(a, b)
			return a < b;
		end
	);

	return tsupp.setup(ctx, {linear}, yh, on_click, on_motion);
end

-- show, called with an anchor and a group ofs / position
local function show(ctx, anchor, ofs)
	return tsupp.show(ctx, anchor,
		ctx.group_cache[ofs], 1, #ctx.group_cache[ofs], nil, ofs);
end

local function destroy(ctx)
	tsupp.destroy(ctx);
end

return {
	name = "labels",
	paths = {"/target/input"},
	show = show,
	probe = probe,
	destroy = destroy
};

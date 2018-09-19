--
-- One 'large group' of icons to pick from, populated using the known glyphs
-- when the icon:ref subset gets finished, it too will be used here as a helper
-- for the inputs that can take advantage of icon references - such as adding
-- statusbar and titlebar icons.
--
-- This is primarily a quick conveniece as it makes too many assumptions and
-- has rather poor performance - and thus only activate on the 'rare but can
-- be allowed to cost' config of UI icons as we don't have a decent asynch
-- way of generating the slices at the moment.
--
-- The intermediate fix is to simply cache the groups and invalidate on yh
-- changes, will cost a few MB of memory but prevent second-long stalls
-- each and every time
--

local tsupp = system_load("widgets/support/text.lua")();
local tbl = system_load("widgets/unicode_data.lua")();

for i,v in ipairs(tbl) do
	tbl[i] = {
		"(" .. tbl[i] .. ") ",
		string.to_u8(v)
	};
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
	lbar.inp:set_str("0x:" .. seq);
end

local function probe(ctx, yh)
	return tsupp.setup(ctx, {tbl}, yh, on_click);
end

local function show(ctx, anchor, ofs)
	return tsupp.show(ctx, anchor,
		ctx.group_cache[ofs], 1, #ctx.group_cache[ofs], nil, ofs);
end

local function destroy(ctx)
	return tsupp.destroy(ctx);
end

return {
	name = "unicode", -- user identifiable string
	paths = {
		"special:icon"
	},
	show = show,
	probe = probe,
	destroy = destroy
};

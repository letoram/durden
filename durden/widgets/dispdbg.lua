local tsupp = system_load("widgets/support/text.lua")();

local function probe(ctx, yh)
	local lines = {};
	local disp = active_display(false, true);

	table.insert(lines, string.format("Id: %d", disp.id));
	table.insert(lines, string.format("Dimensions: %d * %d", disp.w, disp.h));

	if (disp.refresh) then
		table.insert(lines, string.format("Refresh: %f", disp.refresh));
	else
		table.insert(lines, "Refresh: missing");
	end

	table.insert(lines,
		string.format("Density: %s", disp.ppcm and tostring(disp.ppcm) or "missing"));

	if (disp.ppcm_override) then
		table.insert(lines, string.format("Density (force): %f", disp.ppcm_override));
	end

	table.insert(lines, string.format("Name: %s",
		disp.name and disp.name or "missing"));

-- shorten as the real use is to be able to match to arcan_db show_appl durden
	local hexstr = string.hexenc(disp.name);
	hexstr = string.sub(hexstr, 1, 5) .. " ... " .. string.sub(hexstr, #hexstr - 5);
	table.insert(lines, string.format("-> hex: %s", hexstr));

	if (disp.primary) then
		table.insert(lines, "Primary-Sync");
	end

	if (disp.shader) then
		table.insert(lines, string.format("Shader: %s", disp.shader));
	else
		table.insert(lines, "Shader: missing");
	end

	if (disp.backlight) then
		table.insert(lines, string.format("Backlight: %f", disp.backlight));
	else
		table.insert(lines, "Backlight: missing");
	end

	if (disp.maphint and disp.maphint > 0) then
		local hint = bit.band(disp.maphint, bit.bnot(HINT_PRIMARY));
		if (hint == HINT_ROTATE_CW_90) then
			table.insert(lines, "Map: Rotate CW-90");
		elseif (hint == HINT_ROTATE_CCW_90) then
			table.insert(lines, "Map: Rotate CCW-90");
		else
			table.insert(lines, "Map: Unknown");
		end
	else
		table.insert(lines, "Map: Default");
	end

	return tsupp.setup(ctx, {lines}, yh);
end

local function show(ctx, anchor, ofs)
	return tsupp.show(ctx, anchor,
		ctx.group_cache[ofs], 1, #ctx.group_cache[ofs], nil, ofs);
end

local function destroy(ctx)
	return tsupp.destroy(ctx);
end

return {
	name = "dispdbg",
	paths = {function(ctx, pathid)
		if (pathid == "/global/display/displays/current") then
			return true;
		end
	end},
	show = show,
	probe = probe,
	destroy = destroy
};

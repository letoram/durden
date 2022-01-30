local tsupp = system_load("widgets/support/text.lua")();
local prefix = "/global/display/displays/"

local function probe(ctx, yh, tag)
	if not tag then
		return
	end

	local disp

	if tag ~= "current" then
		for d in all_displays_iter() do
			if "disp_" .. string.hexenc(d.name) == tag then
				disp = d;
-- note: breaking out of disp here is dangerous as the iterator needs a closure
			end
		end
	else
		disp = active_display(false, true);
	end

	if not disp then
		return tsupp.setup(ctx, {{"Broken " .. tag}}, yh);
	end

	local lines = {};

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

	if (disp.tiler.scalef) then
		table.insert(lines, string.format("Scale: %f", disp.tiler.scalef))
	end

	local fmt = "Normal(888)"
	if disp.modeopt and disp.modeopt.format then
		if disp.modeopt.fmt == ALLOC_QUALITY_HIGH then
			fmt = "Deep (10b)"
		elseif disp.modeopt.fmt == ALLOC_QUALITY_LOW then
			fmt = "Low (565)"
		elseif disp.modeopt.fmt == ALLOC_QUALITY_FLOAT16 then
			fmt = "HDR (fp16)"
		end
	end

	if #lines == 0 then
		table.insert(lines, "Not Found")
	else
		table.insert(lines, string.format("Format: %s", fmt))
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
	paths =
	{
	function(ctx, pathid)
		if string.starts_with(pathid, prefix) then
			local ng = #(string.split(pathid, "/"));
			return ng == 5 and string.sub(pathid, #prefix+1) or nil;
		end
	end
	},
	show = show,
	probe = probe,
	destroy = destroy
};

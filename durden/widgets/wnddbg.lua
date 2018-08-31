local tsupp = system_load("widgets/support/text.lua")();

local function probe(ctx, yh)
	local lines = {};
	local wnd = active_display().selected;

	if (wnd.crop_values) then
		local c = wnd.crop_values;
		table.insert(lines, string.format(
			"Crop: (%d, %d, %d, %d)", c[1], c[2], c[3], c[4]
		));
	else
		table.insert(lines, "Crop: no");
	end

	local props = image_surface_resolve(wnd.canvas);
	local sprops = image_storage_properties(wnd.canvas);

	table.insert(lines, string.format(
		"store: %d * %d, present: %d * %d",
		sprops.width, sprops.height,
		props.width, props.height
	));

	if (wnd.maximized) then
		table.insert(lines, "Maximized");
	else
		table.insert(lines, "Normal");
	end

	table.insert(lines, string.format(
		"pad: t-%d, l-%d, d-%d, r-%d + hint-pad: %d %d",
		wnd.pad_top, wnd.pad_left, wnd.pad_bottom, wnd.pad_right,
		wnd.dh_pad_w, wnd.dh_pad_h
	));

	local border = image_surface_resolve(wnd.border);
	table.insert(lines, string.format(
		"border: %d * %d @ %d, %d", border.width, border.height, border.x, border.y
	));

	table.insert(lines, string.format(
		"suggested max: %d * %d", wnd.max_w, wnd.max_h));

	table.insert(lines, string.format(
		"weight: %d - %d", wnd.weight, wnd.vweight));

	table.insert(lines, "scale: " .. wnd.scalemode);

	if (wnd.hint_w) then
		table.insert(lines, string.format("hint: %d * %d", wnd.hint_w, wnd.hint_h));
	end

	table.insert(lines,
		wnd.show_border and "Server-Border" or "Client-Border");

	table.insert(lines,
		wnd.show_border and "Server-Titlebar" or "Client-Titlebar");

	if (wnd.geom) then
		table.insert(lines, string.format(
			"geom: %d, %d, %d, %d", wnd.geom[1], wnd.geom[2], wnd.geom[3], wnd.geom[4]));
	end

	local lst = {};
	for k,_ in pairs(wnd.overlays) do
		table.insert(lst, k);
	end
	if (#lst > 0) then
		table.insert(lines, string.format("overlays: %s", table.concat(lst, ", ")));
	end

	if (#wnd.popups > 0) then
		table.insert(lines, string.format("popups: %d", #wnd.popups));
	end

	if (#wnd.alternate > 0) then
		table.insert(lines,
			string.format("alternate-slots:%d{%d}", #wnd.alternate, wnd.alternate_ind));
	end

	if (wnd.guid) then
		table.insert(lines, wnd.guid);
	end
	return tsupp.setup(ctx, {lines}, yh);
end

local function show(ctx, anchor, ofs)
	return tsupp.show(ctx, anchor, ctx.group_cache[ofs], 1, #ctx.group_cache[ofs]);
end

local function destroy(ctx)
	ctx.group_cache = nil;
end

return {
	name = "bindings",
	paths = {function(ctx, pathid)
		if (pathid == "/target") then
			return DEBUGLEVEL > 0;
		end
	end},
	show = show,
	probe = probe,
	destroy = destroy
};

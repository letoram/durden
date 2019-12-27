
function menu_path_for_set(set, path)
	local nents = {};

-- first build a list of possible paths based on the context of
-- each entry in the path
	for i,wnd in ipairs(set) do
		local menu, _, val, restbl = menu_resolve(path, wnd);
		if (menu) then
			for k,v in ipairs(menu) do
				if (not v.interactive) then
					nents[v.name] = v;
				end
			end
		end
	end

-- now, for each possible menu entry, make a shallow copy of it but switch out
-- handlers, evaluators and so on to proxy submenu lookup, handlers and
-- evaluators to be able to trigger with a specific window (rather than the
-- current selected) as the active wm selected one.
	local menu = {};
	for k,v in pairs(nents) do
		local newtbl = {};
		for i,j in pairs(v) do newtbl[i] = j; end
		local fullpath = path .. "/" .. newtbl.name;

-- eval is a bit tricky, basically ignore the original and implement as handler
		if newtbl.eval then
			newtbl.eval = function()
				return true;
			end;
		end

-- the set might mutate while the UI is being queried, so verify that
-- the table we are referencing still has the relevant functions.
			if (newtbl.kind == "value") then
				newtbl.handler = function(ctx, val)
					local cmd = string.format("%s=%s", fullpath, val);
					for _,wnd in ipairs(set) do
						if (wnd.wm) then
							dispatch_symbol_wnd(wnd, cmd);
						end
					end
				end
-- action items can have submenus
			else
				if (newtbl.submenu == true) then
					newtbl.handler = function()
						return menu_path_for_set(set, path .. "/" .. newtbl.name);
					end
				else
					newtbl.handler = function()
						for _,wnd in ipairs(set) do
							if (wnd.wm) then
								dispatch_symbol_wnd(wnd, fullpath);
							end
						end
					end
				end
			end
		table.insert(menu, newtbl);
	end

	return menu;
end

local function gen_menu_for_group(k)
	local set = {};
	for wnd in all_windows(nil, false) do
		if (wnd.group_tag and wnd.group_tag == k) then
			table.insert(set, wnd);
		end
	end

	return menu_path_for_set(set, "/target");
end

local function gen_all_menu(subtype)
	local set = {};
	for wnd in all_windows(subtype, false) do
		table.insert(set, wnd);
	end
	return menu_path_for_set(set, "/target");
end

local function gen_group_menu()
	local interim = {};
	local res = {};

	for wnd in all_windows(nil, false) do
		if (wnd.group_tag) then
			interim[wnd.group_tag] = true;
		end
	end
	for k,v in pairs(interim) do

		table.insert(res, {
			name = k,
			label = k,
			kind = "action",
			submenu = true,
			handler = function()
				return gen_menu_for_group(k);
			end
		});
	end

	return res;
end

local function gen_wnd_menu()
	local res = {};
	for wnd in all_windows(nil, false) do
		table.insert(res, {
			name = wnd.name,
			label = wnd.name,
			kind = action,
			description = wnd:get_name(),
			submenu = true,
			handler = function()
				return menu_path_for_set({wnd}, "/target");
			end,
		});
	end
	return res;
end

return {
	{
		name = "group",
		label = "Group",
		description = "Target action applied on group tag",
		kind = "action",
		submenu = true,
		eval = function() return #gen_group_menu() > 0; end,
		handler = function()
			return gen_group_menu();
		end
	},
	{
		name = "all",
		label = "All",
		description = "Target action applied to all windows",
		kind = "action",
		submenu = true,
		handler = function()
			return gen_all_menu();
		end
	},
	{
		name = "latest",
		label = "Latest",
		description = "Target action applied to the most recently created window",
		kind = "action",
		submenu = true,
		eval = function()
			return tiler_latest_window_name() ~= nil;
		end,
		handler = function()
			local name = tiler_latest_window_name();
			if not name then return;
			end
			for wnd in all_windows(nil, false) do
				if wnd.name == name then
					return menu_path_for_set({wnd}, "/target");
				end
			end
		end
	},
	{
		name = "name",
		label = "Name",
		description = "Target applied to a window by its unique name",
		kind = "action",
		submenu = true,
		eval = function()
			return #gen_wnd_menu() > 0;
		end,
		handler = function()
			return gen_wnd_menu();
		end,
	},
	{
		name = "type",
		label = "Type",
		description = "Target action applied to all windows by archetype",
		kind = "action",
		submenu = true,
		handler = function()
			local res = {};
			for _, v in ipairs({
				{"Terminal", "terminal"},
				{"TUI", "tui"},
				{"Wayland-Toplevel", "wayland-toplevel"},
				{"X", "bridge-x11"},
				{"Decode", "decode"},
				{"Game", "game"},
				{"Arcan", "lightweight arcan"},
				{"Remoting", "remoting"}
			}) do
				table.insert(res, {
					label = v[1],
					name = v[2],
					kind = "action",
					submenu = true,
					handler = function()
						return gen_all_menu(v[2]);
					end
				});
			end
			return res;
		end
	}
};

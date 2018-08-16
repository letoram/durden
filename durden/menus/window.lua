
local function get_path_for_set(set, path)
	local nents = {};

	for i,wnd in ipairs(set) do
		local menu, _, val, restbl = menu_resolve(path, wnd);
		if (menu) then
-- switch out the handlers to correspond to the same get_path_for..
-- it will always result in a menu path
			for k,v in ipairs(menu) do
				if (not v.interactive) then
					nents[v.name] = v;
				end
			end
		end
	end

	local menu = {};
	for k,v in pairs(nents) do
-- copy, but switch out handlers based on type.
		local newtbl = {};
		for i,j in pairs(v) do newtbl[i] = j; end
		local fullpath = path .. "/" .. newtbl.name;

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
			else
				if (newtbl.submenu == true) then
					newtbl.handler = function()
						return get_path_for_set(set, path .. "/" .. newtbl.name);
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

	return get_path_for_set(set, "/target");
end

local function gen_all_menu(subtype)
	local set = {};
	for wnd in all_windows(subtype, false) do
		table.insert(set, wnd);
	end
	return get_path_for_set(set, "/target");
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

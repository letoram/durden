
local function get_path_for_set(set, path)
	local nents = {};

	for i,v in ipairs(set) do
		local os = active_display().selected;
		local menu, _, val, restbl = menu_resolve(path, v);
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
			if (newtbl.kind == "value") then
				newtbl.handler = function(ctx, val)
					notification_add("test", nil, string.format("s=%s", newtbl.name, val));
					print("handle value");
				end
			else
				if (newtbl.submenu == true) then
					newtbl.handler = function()
						return get_path_for_set(set, path .. "/" .. newtbl.name);
					end
				else
					newtbl.handler = function()
						notification_add("test", nil, "action");
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
		description = "Target action applied to a group",
		kind = "action",
		submenu = true,
		eval = function() return #gen_group_menu() > 0; end,
		handler = function()
			return gen_group_menu();
		end
	},
};

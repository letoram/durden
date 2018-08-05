local global = system_load("menus/global/global.lua")();
local target = system_load("menus/target/target.lua")();
local browse = system_load("menus/browse.lua")();
local window = system_load("menus/window.lua")();

-- add m2 to m1, overwrite on collision
local function merge_menu(m1, m2)
	local kt = {};
	local res = {};
	if (m2 == nil) then
		return m1;
	end

	if (m1 == nil) then
		return m2;
	end

	for k,v in ipairs(m1) do
		kt[v.name] = k;
		table.insert(res, v);
	end

	for k,v in ipairs(m2) do
		if (kt[v.name]) then
			res[kt[v.name]] = v;
		else
			table.insert(res, v);
		end
	end
	return res;
end

local function get_target_menu()
	local wnd = active_display().selected;
	if (not wnd) then
		return {};
	elseif (wnd.no_shared) then
		return target;
	else
		return merge_menu(target, wnd.actions);
	end
end

function menus_register(root, path, entry)
	local level;
	if (root == "global") then
		level = global;
	elseif (root == "target") then
		level = target;
	else
		warning("register menus, unknown root specified");
		return;
	end

	local elems = string.split(path, '/');

	if (#elems > 0 and elems[1] == "") then
		table.remove(elems, 1);
	end

	for k,v in ipairs(elems) do
		local found = false;
		for i,j in ipairs(level) do
			if (j.name == v and type(j.handler) == "table") then
				found = true;
				level = j.handler;
				break;
			end
		end
		if (not found) then
			warning(string.format("attach-%s (%s) failed on (%s)",root, path, v));
			return;
		end
	end
	table.insert(level, entry);
end

function menus_get_root()
return {
{
	name = "global",
	label = "Global",
	submenu = true,
	kind = "action",
	handler = global,
	description = "Global settings and actions",
},
{
	name = "target",
	label = "Target",
	submenu = true,
	kind = "action",
	eval = function() return active_display().selected; end,
	handler = get_target_menu,
	description = "Actions that target the currently selected window"
},
{
	name = "windows",
	label = "Windows",
	submenu = true,
	kind = "action",
	description = "Target actions projected over a set of windows",
	handler = window
},
{
	name = "browse",
	label = "Browse",
	submenu = true,
	kind = "action",
	handler = browse,
	description = "File browser/picker"
}
};
end

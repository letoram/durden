local global = system_load("menus/global/global.lua")();
local target = system_load("menus/target/target.lua")();
local browse = system_load("menus/browse.lua")();
local window = system_load("menus/window.lua")();

local menu_list = {};

function menu_lookup_custom(name)
	for k,v in ipairs(menu_list) do
		if v.name == name then
			return v:handler();
		end
	end
end

local function rescan_menu()
-- save the first entry always
	local ent = menu_list[1];
	menu_list = {
		ent
	};

-- now glob and popen()
	local list = glob_resource("devmaps/menus/*.lua");
	for k,v in ipairs(list) do
		local res, msg = system_load("devmaps/menus/" .. v, false);
		if (v == "rescan") then
			warning("devmaps/menus/rescan ignored, name collision");
		elseif (not res) then
			warning(string.format("could parse devmaps/menus: %s", v));
		else
			local okstate, msg = pcall(res);
			if not (okstate) then
				warning(string.format("runtime error loading menu: %s - %s", v, msg));
			elseif type(msg) ~= "table" then
				warning(string.format("runtime error loading menu: %s, no table returned", v));

-- all error conditions handled, add as a dynamic submenu and resolve the list
-- when triggered
			else
				local short = string.sub(v, 1, #v-4);
				table.insert(menu_list, {
					name = short,
					label = short,
					kind = "action",
					submenu = true,
					handler = function()
						return menu_build(msg);
					end
				});
			end
		end
	end
end

menu_list[1] = {
	name = "rescan",
	kind = "action",
	label = "Rescan",
	description = "Rescan devmaps/menus for updates",
	handler = rescan_menu
};

rescan_menu();

-- add m2 to m1, overwrite on collision
function merge_menu(m1, m2)
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

-- replace if one already exists, this will work poorly for dynamically generated
	for i, v in ipairs(level) do
		if v.name == entry.name then
			level[i] = entry
			return
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
	eval = function()
		return active_display().selected ~= nil;
	end,
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
},
{	name = "menus",
	label = "Menus",
	submenu = true,
	kind = "action",
	handler = menu_list,
	description = "Custom menu selectors (devmaps/menus)"
},
{
	name = "bindtarget",
	label = "Bindtarget",
	kind = "value",
	invisible = true,
	validator = function(val)
		return val ~= nil and #val > 0;
	end,
	handler = function(ctx, val)
		dispatch_bindtarget(val);
	end,
}
};
end

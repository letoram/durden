--
-- Globally available menus, settings and functions. All code here is just
-- boiler-plate mapping to engine- or support script functions.
--

local toplevel = {
	{
		name = "open",
		label = "Open",
		kind = "action",
		submenu = true,
		handler = system_load("menus/global/open.lua")()
	},
	{
		name = "launch",
		label = "Launch",
		kind = "action",
		eval = function() return #(list_targets()) > 0; end,
		handler = grab_global_function("query_launch")
	},
	{
		name = "global_menu",
		label = "Global Menu",
		kind = "action",
		invisible = true,
		handler = function()
			grab_global_function("global_actions")();
		end,
	},
	{
		name = "target_menu",
		label = "Window Menu",
		kind = "action",
		invisible = true,
		handler = function()
			grab_global_function("target_actions")
		end
	},
-- useful for idle- timers where you only want enter or exit behavior
	{
		name = "do_nothing",
		label = "Nothing",
		kind = "action",
		invisible = true,
		handler = function()
		end
	},
	{
		name = "workspace",
		label = "Workspace",
		kind = "action",
		submenu = true,
		hint = "Workspace:",
		handler = system_load("menus/global/workspace.lua")()
	},
	{
		name = "display",
		label = "Display",
		kind = "action",
		submenu = true,
		hint = "Displays:",
		handler = system_load("menus/global/display.lua")()
	},
	{
		name = "settings",
		label = "Config",
		kind = "action",
		submenu = true,
		hint = "Config:",
		handler = system_load("menus/global/config.lua")()
	},
	{
		name = "audio",
		label = "Audio",
		kind = "action",
		submenu = true,
		hint = "Audio:",
		handler = system_load("menus/global/audio.lua")()
	},
	{
		name = "input",
		label = "Input",
		kind = "action",
		submenu = true,
		hint = "Input:",
		handler = system_load("menus/global/input.lua")()
	},
	{
		name = "system",
		label = "System",
		kind = "action",
		submenu = true,
		hint = "System:",
		handler = system_load("menus/global/system.lua")()
	},
};

function get_global_menu()
	return toplevel;
end

local global_actions = nil;
global_actions = function(trigger_function)
	LAST_ACTIVE_MENU = global_actions;
	if (IN_CUSTOM_BIND) then
		return launch_menu(active_display(), {
			list = toplevel,
			trigger = trigger_function,
			show_invisible = true
		}, true, "Bind:");
	else
		return launch_menu(active_display(), {list = toplevel,
			trigger = trigger_function}, true, "Action:");
	end
end

function attach_global_menu(path, entry)
	local elems = string.split(path, '/');
	local level = toplevel;
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
			warning(string.format("attach_global_menu(%s) failed on (%s)",path,v));
			return;
		end
	end
	table.insert(level, entry);
end

register_global("global_actions", global_actions);

--
-- Globally available menus, settings and functions. All code here is just
-- boiler-plate mapping to engine- or support script functions.
--

local tools = {
};

local toplevel = {
	{
		name = "open",
		label = "Open",
		kind = "action",
		submenu = true,
		description = "Start built-in tools or preset trusted applications",
		handler = system_load("menus/global/open.lua")()
	},
	{
		name = "global",
		label = "Global Menu",
		kind = "action",
		invisible = true,
		description = "Binding to launch the global menu",
		handler = function()
			grab_global_function("global_actions")();
		end,
	},
	{
		name = "crash",
		label = "Crash WM",
		kind = "action",
		description = "This will provoke a WM error by calling a function that does not exist",
		handler = function()
			this_will_crash_the_wm();
		end
	},
	{
		name = "target",
		label = "Window Menu",
		kind = "action",
		invisible = true,
		description = "Binding to launch the current window context menu",
		handler = function()
			grab_shared_function("target_actions")();
		end
	},
-- useful for idle- timers where you only want enter or exit behavior
	{
		name = "do_nothing",
		label = "Nothing",
		kind = "action",
		description = "Special binding for idle-timers",
		invisible = true,
		handler = function()
		end
	},
	{
		name = "workspace",
		label = "Workspace",
		kind = "action",
		description = "Current- or all- workspace related actions",
		submenu = true,
		handler = system_load("menus/global/workspace.lua")()
	},
	{
		name = "display",
		label = "Display",
		kind = "action",
		submenu = true,
		description = "Display output controls",
		handler = system_load("menus/global/display.lua")()
	},
	{
		name = "settings",
		label = "Config",
		kind = "action",
		submenu = true,
		description = "Persistent configuration tuning",
		handler = system_load("menus/global/config.lua")()
	},
	{
		name = "audio",
		label = "Audio",
		kind = "action",
		submenu = true,
		description = "Global audio controls",
		handler = system_load("menus/global/audio.lua")()
	},
	{
		name = "input",
		label = "Input",
		kind = "action",
		submenu = true,
		description = "Global input settings",
		handler = system_load("menus/global/input.lua")()
	},
-- unsure if it is a good idea to expose these for access outside binding etc.
-- leaning towards 'no' in the current state of things.
	{
		name = "windows",
		label = "Windows",
		kind = "action",
		hidden = true,
		eval = function() return false; end,
		submenu = true,
		handler = system_load("menus/global/windows.lua")()
	},
	{
		name = "system",
		label = "System",
		kind = "action",
		submenu = true,
		description = "System- specific actions",
		handler = system_load("menus/global/system.lua")()
	},
	{
		name = "tools",
		label = "Tools",
		kind = "action",
		submenu = true,
		descriptions = "Plugin/Tool activation and control",
		handler = tools
	}
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
			trigger = trigger_function}, true, nil, {
				tag = "Global",
				domain = "!"
			});
	end
end

function global_menu_register(path, entry)
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

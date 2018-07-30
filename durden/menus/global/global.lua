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
-- useful for idle- timers where you only want enter or exit behavior
	{
		name = "do_nothing",
		label = "Nothing",
		kind = "action",
		description = "Used for timer binding (enter- or exit- only)",
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
		handler = system_load("menus/global/settings.lua")()
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

return toplevel;

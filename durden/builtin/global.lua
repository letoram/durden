--
-- globally available menus, settings and functions
--

local function global_valid01_uri(str)
	return true;
end

local function display_rescan()
	video_displaymodes();
end

local function query_synch()
	local lst = video_synchronization();
	if (lst) then
		local res = {};
-- dynamically populated so we don't expose this globally at the moment
		for k,v in ipairs(lst) do
			res[k] = {
				name = "set_synch_" .. tostring(k),
				label = v,
				kind = "action",
				handler = function(ctx)
					video_synchronization(v);
				end
			};
		end
		launch_menu(displays.main, {list = res}, true, "Synchronization:");
	end
end

local display_menu = {
	{
		name = "list_displays",
		label = "Displays",
		kind = "action",
		submenu = true,
		handler = function(ctx)
			warning("enum known displays, list here with dynamic handler to " ..
	"enable / disable or switch resolution");
		end
	},
	{
		name = "display_rescan",
		label = "Rescan",
		kind = "action",
		submenu = false,
		handler = function(ctx)
			video_displaymodes();
		end
	},
	{
		name = "synchronization_strategies",
		label = "Synchronization",
		kind = "action",
		submenu = true,
		handler = function(ctx)
			query_synch();
		end
	},
};

local function query_exit()
	launch_menu(displays.main, {list = {
		{
			name = "shutdown_no",
			label = "No",
			kind = "action",
			handler = function() end
		},
		{
			name = "shutdown_yes",
			label = "Yes",
			kind = "action",
			handler = function() shutdown(); end
		}
	}}, true, "Shutdown?");
end

local system_menu = {
	{
		name = "shutdown",
		label = "Shutdown",
		kind = "action",
		handler = query_exit
	},
};

local function show_displaymenu()
	launch_menu(displays.main, {list = display_menu}, true, "Displays:");
end

local function show_systemmenu()
	launch_menu(displays.main, {list = system_menu}, true, "System:");
end

-- Stub for now
local toplevel = {
	{
		name = "open",
		label = "Open",
		kind = "string",
		validator = global_valid01_uri,
		handler = function(ctx, value)
			warning("launch missing");
		end
	},
	{
		name = "workspace",
		label = "Workspace",
		kind = "action",
		submenu = true,
		handler = function(ctx, value)
			warning("spawn workspace menu");
		end
	},
	{
		name = "display",
		label = "Display",
		kind = "action",
		submenu = true,
		handler = show_displaymenu,
	},
	{
		name = "audio",
		label = "Audio",
		kind = "action",
		submenu = true,
		handler = function(ctx, value)
			warning("spawn audio menu");
		end
	},
	{
		name = "input",
		label = "Input",
		kind = "action",
		submenu = true,
		handler = function(ctx, value)
			warning("spawn input menu");
		end
	},
	{
		name = "system",
		label = "System",
		kind = "action",
		submenu = true,
		handler = function(ctx, value)
			warning("spawn system menu");
		end
	},
};

local function global_actions()
	launch_menu(displays.main, {list = toplevel}, true, "Action:");
end

register_global("display_rescan", display_rescan);
register_global("global_actions", global_actions);
register_global("exit", query_exit);

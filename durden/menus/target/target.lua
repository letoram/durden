local sdisp = {
	input_label = function(wnd, source, tbl)
		if (not wnd.input_labels) then wnd.input_labels = {}; end
		if (#wnd.input_labels < 100) then
			table.insert(wnd.input_labels, {tbl.labelhint, tbl.idatatype});
		end
	end
};

-- default event handlers that will be added to a new registered
-- window, used to track things like wanted key=vales (coreopts)
-- and input labels
function shared_dispatch()
	return sdisp;
end

local shared_actions = {
	{
		name = "input",
		label = "Input",
		submenu = true,
		kind = "action",
		eval = function()
			return not active_display().selected.menu_input_disable;
		end,
		handler = system_load("menus/target/input.lua")()
	},
	{
		name = "state",
		label = "State",
		submenu = true,
		kind = "action",
		eval = function()
			local wnd = active_display().selected;
			return valid_vid(wnd.external, TYPE_FRAMESERVER)
				and not wnd.menu_state_disable;
		end,
		handler = system_load("menus/target/state.lua")()
	},
	{
		name = "clipboard",
		label = "Clipboard",
		submenu = true,
		kind = "action",
		eval = function()
			return active_display().selected and
				active_display().selected.clipboard_block == nil;
		end,
		handler = system_load("menus/target/clipboard.lua")()
	},
	{
		name = "options",
		label = "Options",
		submenu = true,
		kind = "action",
		eval = function()
			local wnd = active_display().selected;
			return valid_vid(wnd.external, TYPE_FRAMESERVER) and
				wnd.coreopt and #wnd.coreopt > 0;
		end,
		handler = system_load("menus/target/coreopts.lua")()
	},
	{
		name = "audio",
		label = "Audio",
		submenu = true,
		kind = "action",
		eval = function(ctx)
			return active_display().selected.source_audio;
		end,
		handler = system_load("menus/target/audio.lua")()
	},
	{
		name = "video",
		label = "Video",
		kind = "action",
		submenu = true,
		handler = system_load("menus/target/video.lua")()
	},
	{
		name = "window",
		label = "Window",
		kind = "action",
		submenu = true,
		handler = system_load("menus/target/window.lua")()
	},
};

if (DEBUGLEVEL > 0) then
	table.insert(shared_actions, {
		name = "debug",
		label = "Debug",
		kind = "action",
		submenu = true,
		handler = system_load("menus/target/debug.lua")();
	});
end

function get_shared_menu()
	return shared_actions;
end

function shared_menu_register(path, entry)
	local elems = string.split(path, '/');
	local level = shared_actions;
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

local show_shmenu;
show_shmenu = function(wnd)
	wnd = wnd and wnd or active_display().selected;

	if (wnd == nil) then
		return;
	end

	LAST_ACTIVE_MENU = show_shmenu;

	local ctx = {
		list = merge_menu(wnd.no_shared and {} or shared_actions, wnd.actions),
		handler = wnd
	};

	return launch_menu(active_display(), ctx, true, nil, {
		tag = "Target",
		domain = "#"
	});
end

register_shared("target_actions", show_shmenu);

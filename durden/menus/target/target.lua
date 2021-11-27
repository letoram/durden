local shared_actions = {
	{
		name = "input",
		label = "Input",
		submenu = true,
		kind = "action",
		description = "Mouse/Keyboard/Custom client inputs",
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
		description = "Client state management",
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
		description = "Clipboard control and actions",
		eval = function()
			return active_display().selected and
				active_display().selected.clipboard_block ~= true;
		end,
		handler = system_load("menus/target/clipboard.lua")()
	},
	{
		name = "options",
		label = "Options",
		submenu = true,
		kind = "action",
		description = "Client-supplied configuration keys",
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
		description = "Audio controls",
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
		description = "Video controls",
		handler = system_load("menus/target/video.lua")()
	},
	{
		name = "window",
		label = "Window",
		kind = "action",
		submenu = true,
		description = "Window position and size controls",
		handler = system_load("menus/target/window.lua")()
	},
	{
		name = "triggers",
		label = "Triggers",
		kind = "action",
		submenu = true,
		description = "Bind menu actions to window events",
		handler = system_load("menus/target/triggers.lua")()
	},
	{
		name = "share",
		label = "Share",
		kind = "action",
		submenu = true,
		description = "Sharing, Streaming and Recording Options",
		handler = system_load("menus/target/share.lua")()
	}
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

return shared_actions;

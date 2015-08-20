--
-- Specialized singleton window that monitors input events,
-- state changes, messages etc.
--

local debug_metatbl = {
	__index = function(t, k)
	end
};

local function debugwnd_resize(wnd, w, h)
	print("resize to", w, h);
-- redraw lists etc.
end

local function target_event(wnd, src, tbl)
end

local function event_dispatch(wnd, kind, tbl)
end

local function add_input(wnd, iotbl)
end

local function debugwnd_spawn()
	if (displays.main.debug_console) then
		return;
	end

	local img = fill_surface(100, 100, 0, 0, 0);

	local wnd = displays.main:add_window(img, {});
	wnd.tick = function() end
	wnd.target_event = target_event;
	wnd.event_dispatch = event_dispatch;
	wnd.add_input = add_input;
	wnd:set_title("Debug Console");
	wnd.no_shared = true;
	table.insert(wnd.handlers.destroy, function()
		 displays.main.debug_console = nil;
	end);
	table.insert(wnd.handlers.resize, debugwnd_resize);
	setmetatable(wnd, debug_metatbl);
	displays.main.debug_console = wnd;
end

if (DEBUGLEVEL > 0) then
	register_global("debug_debugwnd", debugwnd_spawn);
end

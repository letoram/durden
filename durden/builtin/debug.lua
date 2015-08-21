--
-- Specialized singleton window that monitors input events,
-- state changes, messages etc.
--

local debug_metatbl = {
	__index = function(t, k)
	end
};

local function debugwnd_resize(wnd, w, h)
	wnd:refresh();
end

local function target_event(wnd, src, tbl)
	local ostr = "";
	if (tbl.kind == "framestatus") then
-- noisy and mostly useless debuggingwise
	elseif (tbl.kind == "input_label") then
		wnd:add_event(1, string.format(
			"(%d)[%s] label: %s", CLOCK, wnd.name, tbl.labelhint));
	else
		wnd:add_event(1, string.format(
		"(%d)[%s] kind: %s", CLOCK, wnd.name, tbl.kind));
	end
end

local function event_dispatch(wnd, kind, tbl)
	wnd:add_event(2, string.format(
		"(%d)[%s] => %s [%s]", CLOCK, kind, wnd.name));
end

local function add_input(wnd, iotbl)
	print(wnd, iotbl);
end

local function refresh(wnd)
	if (valid_vid(wnd.history)) then
		delete_image(wnd.history);
	end
	local nr = math.ceil(wnd.height / gconfig_get("font_sz") - 0.5);
	if (nr > 0) then
		local ec = #wnd.events[wnd.gind].ent;
		nr = nr > ec and ec or nr;
		local str = string.format("%s %s",
			gconfig_get("font_str"),
			table.concat(wnd.events[wnd.gind].ent, [[\n\r]], ec - nr + 1, ec)
		);
		wnd.history = render_text(str);
		if (valid_vid(wnd.history)) then
			show_image(wnd.history);
			link_image(wnd.history, wnd.canvas);
			image_clip_on(wnd.history, CLIP_SHALLOW);
			image_mask_set(wnd.history, MASK_UNPICKABLE);
			image_inherit_order(wnd.history, true);
			order_image(wnd.history, 1);
		end
	else
		wnd.history = nil;
	end
end

local function add_event(wnd, ind, str)
	if (str) then
		table.insert(wnd.events[ind].ent, str);
	end
	if (#wnd.events[ind].ent> 100) then
		table.remove(wnd.events[ind].ent, 1);
	end
	if (ind == wnd.gind) then
		wnd:refresh();
	end
end

local function wnd_destroy(wnd)
	if (valid_vid(wnd.history)) then
		delete_image(wnd.history);
	end
end

local function wnd_input(wnd, sym, iotbl)
	if (iotbl.active and sym == SYSTEM_KEYS["previous"]) then
		wnd.gind = wnd.gind == 1 and #wnd.events or wnd.gind - 1;
		wnd:set_prefix(wnd.events[wnd.gind].tag);
		wnd:refresh();
	elseif (iotbl.active and sym == SYSTEM_KEYS["next"]) then
		wnd.gind = (wnd.gind + 1)
			> #wnd.events and 1 or (wnd.gind + 1);
		wnd:set_prefix(wnd.events[wnd.gind].tag);
		wnd:refresh();
	end
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
	wnd.gind = 1;
	wnd.events = {{
		tag = "target-event handler",
		ent= {}
	},
	{
		tag = "target-event dispatch",
		ent= {}
	},
	{
		tag = "input-event handler",
		ent= {}
	},
	{
		tag = "symbol dispatch",
		ent= {}
	}};
	wnd.key_input = wnd_input;
	wnd.add_event = add_event;
	wnd.refresh = refresh;
	wnd:add_handler("destroy", wnd_destroy);
	wnd:set_title("Debug Console");
	wnd.no_shared = true;
	wnd.scalemode = "stretch";
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

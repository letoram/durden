-- input controls for working with rotary input devices
local log, fmt = suppl_add_logfn("idevice");
local device_count = 0;

local labels = system_load("devmaps/rotary/rotary.lua")();
for _,v in ipairs(labels) do
	v.devices = {};
end

local function space_handler(dev, iotbl)
	if iotbl.digital then
		if dev.buttons and dev.buttons[iotbl.subid] then
			if iotbl.active then
				dispatch_symbol(dev.buttons[iotbl.subid]);
			end
			return true;
		end
	end

-- update state tracking about various 'held' axes that are ticking
--
-- if we are in mouse- emulation mode the tick below will emit a relative
-- sample based on the relative axis for each dimension
--
-- the rest is only if we have a selected window to work with
	local wnd = active_display().selected;
	if not wnd then
		return true;
	end

-- if we have any analog inputs labeled, try and match and if no match,
-- pick based on index -- since we don't want to slam the search and
-- match each time, keep a cache
	if not wnd.input_labels or not
		wnd.rotary_cache or wnd.rotary_cache ~= wnd.label_update then
		wnd.rotary_cache = wnd.label_update;
		wnd.rotary_cache_tbl = {};
		table.set_unless_exists(wnd, "input_labels", {});

-- need path / control for mapping analog axes to device axes here
		for i,v in ipairs(wnd.input_labels) do
			if v.idatatype == "analog" then
				table.insert(wnd.rotary_cache_tbl, v.label);
			end
		end
	end

-- remap axis and lookup against known labels
	if iotbl.analog then
		iotbl.subid = dev.axis_map[iotbl.subid] and dev.axis_map[iotbl.subid] or iotbl.subid
		iotbl.label = wnd.rotary_cache_tbl[iotbl.subid];

-- manually re-range
		iotbl.samples[1] = dev.resample(dev.subid, iotbl.samples[1])
	end

	wnd:input_table(iotbl);
	return true;
end

-- common denominator for mouse/keyboard handler,
-- figure out basic gestures (press-wheel, click, doubleclick)
local function classify_action(dev, iotbl)

-- start by resetting the idle counter
	if dev.rotary_in_idle then
		dev.rotary_in_idle = nil;
		if dev.gestures["idle_leave"] then
			dispatch_symbol(dev.gestures["idle_leave"]);
		end
	end
	dev.rotary_idle = 0;

-- then button or spin?
	local step = 0;
	local meta = false;
	local button;

	if iotbl.digital then
		if dev.buttons and dev.buttons[iotbl.subid] then
			if iotbl.active then
				dispatch_symbol(dev.buttons[iotbl.subid]);
			end
			return true;
		end

-- release or press?
		if (dev.rotary_held ~= nil) then
			if iotbl.active == false then
				if CLOCK - dev.rotary_last_click <= gconfig_get("mouse_dblclick") then
					button = "dblclick";
					dev.rotary_last_click = 0;
				else
-- add latency to determine single click or double-click if double click is wanted
					button = "click";
					dev.rotary_last_click = CLOCK;
				end
				dev.rotary_held = nil;
			end
		else
-- long-press is determined in the tick timer
			dev.rotary_held = iotbl.active and CLOCK or nil;
		end

-- clamp
	elseif iotbl.analog then
		if iotbl.samples[1] > 0 then
			step = 1;
		elseif iotbl.samples[1] < 0 then
			step = -1;
		end

-- detect press-spin, reset counter for long-press
		if dev.rotary_held ~= nil then
			dev.rotary_held = CLOCK;
			meta = true;
			step = step * dev.scale_press;
		else
			step = step * dev.scale;
		end
	end

	log(fmt("submodule=rotary:step=%d:meta=%s:button=%s",
		step, meta and "yes" or "no", button and button or "none"));
	return step, meta, button;
end

-- use to run different behavior for popups, lbar etc.
local function step_to_systemkey(step, meta, button)
	local key;

	if (button and button == "click") then
		key = SYSTEM_KEYS["accept"];
	elseif step < 0 then
		key = SYSTEM_KEYS["left"];
	elseif step > 0 then
		key = SYSTEM_KEYS["right"];
	else
		return;
	end

	local tbl = {
		kind = "digital",
		translated = true,
		digital = true,
		active = true,
		devid = 0,
		subid = SYMTABLE[key],
		number = SYMTABLE[key],
		modifiers = 0,
	};

	active_display():input_lock(key, tbl, key, false, nil);
end

local function mouse_handler(dev, iotbl)
	local step, meta, button = classify_action(dev, iotbl);
-- special handle if we have popup, menu or pickregion
	if active_display().input_lock then
		step_to_systemkey(step, meta, button);
		return true;
	end

	if step == 0 then
		return true;
	end

-- translate to wheel action, unless no grab and target window
-- support seeking, then simply map to that
	local niter = math.abs(step);
	for i=1,niter do
		local ind;
		if dispatch_meta() then
			ind = step > 0 and MOUSE_WHEELPX or MOUSE_WHEELNX;
		else
			ind = step < 0 and MOUSE_WHEELPY or MOUSE_WHEELNY;
		end

		mouse_button_input(ind, true);
		mouse_button_input(ind, false);
	end
	return true;
end

-- [popup or menu?]
-- translate to UP/DOWN, click to select, dblclick to cancel]
-- [selected window?]
-- client has content_hint? scroll, or press-scroll, click to toggle axis
-- [no window/dblclick? - show popup]

local function keyboard_handler(dev, iotbl)
	local res, meta, button = classify_action(dev, iotbl);
end

local handlers = {
{
	name = "mouse",
	label = "Mouse",
	description = "Translate to mouse wheel motion, click for axis",
	kind = "action",
	handler = function(dev)
		dev.rotary_sample = mouse_handler
	end
},
{
	name = "keyboard",
	label = "Keyboard",
	description = "Forward as keypresses or content hints",
	kind = "action",
	handler = function(dev)
		dev.rotary_sample = keyboard_handler
	end
}
};

local function rotary_tick()
	for _,v in ipairs(labels) do

-- deal with idle entry - re-entry
		for _,dev in ipairs(v.devices) do

-- with dblclick defined, this timeout means that the click should fire,
-- otherwise it can fire on the release event
			if dev.rotary_last_click > 0 and
				CLOCK - dev.rotary_last_click > gconfig_get("mouse_dblclick") and
				dev.gestures["click"] then
				dispatch_symbol(dev.gestures["click"]);
				dev.rotary_last_click = nil;
			end

-- treat idle enter with the same parameters as hiding the mouse
			dev.rotary_idle = dev.rotary_idle + 1;
			if dev.rotary_idle > gconfig_get("mouse_hidetime") and
				not dev.rotary_in_idle and dev.gestures["idle_enter"] then
				dev.rotary_in_idle = true;
				dispatch_symbol(dev.gestures["idle_enter"]);
			end

-- deal with long-press
-- this might be better as something else, but it seems like an ok comparison
			if dev.rotary_held and CLOCK - dev.rotary_held >
				gconfig_get("mouse_hovertime") and dev.gestures["longpress"] then
					dev.rotary_held = nil;
					dispatch_symbol(dev.gestures["longpress"]);
			end
		end

	end
end

local function lookup_device(devtbl)
-- specific override for one device?
	local dev =	table.find_key_i(labels, "devid", devtbl.devid);

-- or generic profile for class?
	if not dev then
		dev = table.find_key_i(labels, "label", devtbl.label);
	end

	if not dev then
		log(fmt("submodule=rotary:" ..
			"kind=no_match:device=%d:label=%s", devtbl.devid, devtbl.label));
		return;
	end
	dev = labels[dev];

	log(fmt("submodule=rotary:kind=added:device=%d", devtbl.devid));
	device_count = device_count + 1;

-- enable the tick- timer for digital events (idle, click, double-click)
	if (device_count == 1) then
		timer_add_periodic("rotary", 1, false, rotary_tick, false);
	end

-- init basic tracking fields
	table.insert(dev.devices, devtbl);

-- 'elastic' rotary (3dmouse) only turns then bounces back on release
	if (dev.elastic) then
		devtbl.rotary_sample = space_handler;
	else
		devtbl.rotary_sample = mouse_handler;
	end

-- copy basics from profile
	devtbl.rotary_last_click = 0;
	devtbl.rotary_idle = 0;
	devtbl.scale = dev.scale;
	devtbl.scale_press = dev.scale_press;
	devtbl.buttons = dev.buttons;
	devtbl.axis_map = dev.axis_map;
	devtbl.resample = dev.resample;
	table.set_unless_exists(devtbl, "resample", function(id, smpl) return smpl; end);
	table.set_unless_exists(devtbl, "axis_map", {});
	devtbl.gestures = {
		["click"] = dev.gestures.click,
		["dblclick"] = dev.gestures.dblclick,
		["longpress"] = dev.gestures.longpress,
		["idle_enter"] = dev.gestures.idle_enter,
		["idle_leave"] = dev.gestures.idle_leave,
	};

-- the handler can be switched dynamically to respond to events
	iostatem_register_handler(devtbl.devid, "rotary",
		function(iotbl)
			return devtbl:rotary_sample(iotbl);
		end);

	return true;
end

-- when a device with a matching table gets added, implement a handler
iostatem_listen_events(lookup_device);

local function menu_for(dev)
	local res = {
		{
			label = "Click",
			kind = "action",
			name = "click",
			description = "Set a handler for the 'click' button action",
			handler = function()
				dispatch_symbol_bind(function(path)
					if not path or #path == 0 then
						return;
					end
					dev.gestures["click"] = path;
				end);
			end,
		},
		{
			label = "Double Click",
			kind = "action",
			name = "dblclick",
			description = "Set a handler for the 'double click' button action",
			handler = function()
				dispatch_symbol_bind(function(path)
					if not path or #path == 0 then
						return;
					end
					dev.gestures["dblclick"] = path;
				end);
			end
		},
		{
			label = "Scale",
			kind = "value",
			name = "scale",
			initial = tostring(dev.scale),
			hint = "(-10..10)",
			validator = gen_valid_num(-10, 10, 1),
			description = "Set the normal wheel scale factor (negative value to invert)",
		},
		{
			label = "Press-Scale",
			kind = "value",
			name = "scale_press",
			initial = tostring(dev.scale_press),
			hint = "(-10..10)",
			validator = gen_valid_num(-10, 10),
			description = "Set the pressed wheel scale factor (negative value to invert)",
			handler = function(ctx, val)
				dev.scale_pressed = tonumber(val);
			end
		}
	};

-- add to the set of allowed classifiers
	for i,v in ipairs(handlers) do
		table.insert(res, {
			name = v.name,
			label = v.label,
			description = v.description,
			kind = "action",
			handler = function()
				v.handler(dev);
			end
		});

		table.insert(res, {
			name = "cycle_mode",
			label = "Cycle Mode",
			kind = "action",
			handler = function()
				local ind = table.find_key_i(handlers, "handler", dev.rotary_sample);
				if ind < #handlers then
					ind = ind + 1;
				else
					ind = 1;
				end
				log(fmt("submodule=rotary:dev=%d:mode=%d", dev.devid, ind));
				handlers[ind].handler(dev);
			end
		});
	end

	return res;
end

function rotary_controls()
	local res = {};
	for k,v in ipairs(labels) do
		if #v.devices > 0 then
			for i,d in ipairs(v.devices) do
				table.insert(res,
				{
					label = v.label,
					name = tostring(i),
					kind = "action",
					submenu = true,
					handler = function()
						return menu_for(d);
					end
				});
			end
		end
	end

	return res;
end

menus_register("global", "input", {
	name = "rotary",
	label = "Rotary",
	description = "Rotary Input Devices",
	kind = "action",
	eval = function()
		return #rotary_controls() > 0;
	end,
	submenu = true,
	handler = rotary_controls
});

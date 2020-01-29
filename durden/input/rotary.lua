-- input controls for working with rotary input devices
local log, fmt = suppl_add_logfn("idevice");
local device_count = 0;

local labels = {
	{
		name = "surface_dial",
		label = "Surface Dial System Multi Axis",
		devices = {}
	};
};

-- we still want to have the device tracking etc. so disable by setting
-- an empty handler function rather than deregistering from the iostate
local function empty_function()
end

-- common denominator for mouse/keyboard handler,
-- figure out basic gestures (press-wheel, click, doubleclick)
local function classify_action(dev, iotbl)
	dev.rotary_idle = 0;

	local step = 0;
	local meta = false;
	local button;

	if iotbl.digital then

-- release or press?
		if (dev.rotary_held ~= nil) then
			if iotbl.active == false then
				if CLOCK - dev.rotary_last_click <= gconfig_get("mouse_dblclick") then
					button = "dblclick";
				else
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
		end
	end

	log(fmt("submodule=rotary:step=%d:meta=%s:button=%s",
		step, meta and "yes" or "no", button and button or "none"));
	return step, meta, button;
end

local function mouse_handler(dev, iotbl)
	local step, meta, button = classify_action(dev, iotbl);

-- translate to wheel action, unless no grab and target window support
-- seeking, then simply map to that
	if step ~= 0 then
		local ind;
		if meta then
			ind = step > 0 and MOUSE_WHEELPX or MOUSE_WHEELNX;
		else
			ind = step > 0 and MOUSE_WHEELPY or MOUSE_WHEELNY;
		end
		mouse_button_input(ind, true);
		mouse_button_input(ind, false);
	end
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
	name = "empty",
	label = "Empty",
	kind = "action",
	description = "Ignore all device inputs",
	handler = function(dev)
		dev.rotary_sample = empty_function
	end
},
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

local function lookup_device(devtbl)
	local dev = table.find_key_i(labels, "label", devtbl.label);
	if not dev then
		return;
	end
	dev = labels[dev];

	log(fmt(
		"submodule=rotary:kind=added:device=%d", devtbl.devid));
	device_count = device_count + 1;

-- enable the tick- timer for digital events (idle, click, double-click)
	if (device_count == 1) then
		warning("enable tick");
	end

-- init basic tracking fields
	table.insert(dev.devices, devtbl);
	devtbl.rotary_sample = mouse_handler;
	devtbl.rotary_last_click = 0;

-- the handler can be switched dynamically to respond to events
	iostatem_register_handler(devtbl.devid, "rotary",
		function(iotbl)
			return devtbl:rotary_sample(iotbl);
		end);
end

-- when a device with a matching table gets added, implement a handler
iostatem_listen_events(lookup_device);

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
						return menu_for(s);
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

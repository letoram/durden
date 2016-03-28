--
-- wrapper for _input_event that tracks device states for repeat-rate control
-- and for "uncommon" devices that fall outside the normal keyboard/mouse
-- setup, that require separate lookup and translation, including state-
-- toggle on a per window (save/restore) basis etc.
--

local devstate = {};
local devices = {};
local def_period = 0;
local def_delay = 0;
local DEVMAP_DOMAIN = APPL_RESOURCE;

-- specially for game devices, note that like with the other input platforms,
-- the actual mapping for a device may vary with underlying input platform and,
-- even worse, not guaranteed consistent between OSes even with 'the same'
-- platform.
local label_lookup = {};
local function default_lh(sub)
	return "BUTTON" .. tostring(sub + 1);
end

local function default_ah(sub)
	return "AXIS" .. tostring(sub + 1), 1;
end

-- returns a table that can be used to restore the input state, used
-- for context switching between different windows or input targets.
local odst;

function iostatem_save()
	odst = devstate;
	devstate = {
		iotbl = nil,
		delay = def_delay,
		period = def_period,
		counter = def_delay
	};
	return odst;
end

function iostatem_state()
	return (devstate.period and devstate.period or -1),
		(devstate.delay and devstate.delay or -1),
		devstate.counter
	;
end

function iostatem_restore(tbl)
	if (tbl == nil) then
		tbl = odst;
	end

	devstate = tbl;
	devstate.iotbl = nil;
	devstate.counter = tbl.delay and tbl.delay or def_delay;
end

-- just feed this function, will cache state as necessary
function iostatem_input(iotbl)
	local dev = devices[iotbl.devid];
	if (iotbl.mouse) then
		return;
	end

	if (iotbl.translated) then
		if (not iotbl.active or SYMTABLE:is_modifier(iotbl)) then
			devstate.counter = devstate.delay and devstate.delay or def_delay;
			devstate.iotbl = nil;
			return;
		end

		devstate.iotbl = iotbl;

	elseif (iotbl.digital) then
		if (dev) then
			iotbl.dsym = tostring(iotbl.devid) .. "_" .. tostring(iotbl.subid);
			iotbl.label = dev.lookup and
				"PLAYER" .. tostring(dev.slot) .. "_" .. dev.lookup[1](iotbl.subid) or "";
		end

	elseif (iotbl.analog and dev) then
		if (dev.lookup) then
			local ah, af = dev.lookup[2](iotbl.subid);
			if (ah) then
				iotbl.label = "PLAYER" .. tostring(dev.slot) .. "_" .. ah;
				if (af ~= 1) then
					for i=1,#iotbl.samples do
						iotbl.samples[i] = iotbl.samples[i] * af;
					end
				end
			end
		end

-- only forward if asbolutely necessary (i.e. selected window explicitly accepts
-- analog) as the input storms can saturate most event queues
	return true;
	else
		print("iostatem, missing things", iotbl.kind);
-- nothing for touch devices right now
	end
end

function iostatem_reset_repeat()
	devstate.iotbl = nil;
	devstate.counter = 0;
end

-- for the _current_ context, set delay in ms, period in ticks/ch
function iostatem_repeat(period, delay)
	if (period ~= nil) then
		if (period <= 0) then
			devstate.period = 0;
		else
			devstate.period = period;
		end
	end

	if (delay ~= nil) then
		devstate.delay = delay < 0 and 10 or math.ceil(delay / (1000 / CLOCKRATE));
		devstate.counter = devstate.delay;
	end
end

-- returns a table of iotbls, process with ipairs and forward to
-- normal input dispatch
function iostatem_tick()
	if (devstate.counter == 0) then
		return;
	end

	if (devstate.iotbl and devstate.period) then
		devstate.counter = devstate.counter - 1;
		if (devstate.counter == 0) then
			devstate.counter = devstate.period and devstate.period or def_period;

-- copy and add a release so the press is duplicated
			local a = {};
			for k,v in pairs(devstate.iotbl) do
				a[k] = v;
			end

			a.active = false;
			return {a, devstate.iotbl};
		end
	end

-- scan devstate.devices and emitt similar events for the auto-
-- repeat toggles there
end

-- find the lowest -not-in-used- slot ID by alive devices
local function assign_slot(dev)
	local vls = {};
	for k,v in pairs(devices) do
		if (not v.lost and v.slot) then
			vls[v.slot] = true;
		end
	end

	local ind = 1;
	while true do
		if (vls[ind]) then
			ind = ind + 1;
		else
			break;
		end
	end

	dev.slot = ind;
end

function iostatem_added(iotbl)
	local dev = devices[iotbl.devid];
	if (not dev) then
-- locate last saved device settings:
-- axis state, analog force, special bindings
		devices[iotbl.devid] = {
			devid = iotbl.devid,
			label = iotbl.label,
-- we only switch analog sampling on / off
			lookup = label_lookup[iotbl.label]
				and label_lookup[iotbl.label] or {default_lh, default_ah},
			force_analog = false,
			keyboard = iotbl.keyboard
		};
		dev = devices[iotbl.devid];
		assign_slot(dev);
	else
-- keeping this around for devices and platforms that generate a new
-- ID for each insert/removal will slooowly leak (unlikely though)
		if (dev.lost) then
			dev.lost = false;
-- reset analog settings and possible load slot again
			assign_slot(dev);
		else
			warning("added existing device, likely platform bug.");
			dev.slot = 1;
		end
	end
end

function iostatem_removed(iotbl)
	local dev = devices[iotbl.devid];
	if (dev) then
		dev.lost = true;
-- protection against keyboard behaving differently when lost/found
		if (dev.keyboard) then
			meta_guard_reset();
		end
	else
		warning("remove unknown device, likely platform bug.");
	end
end

function iostatem_devices()
	return pairs(devices);
end

function iostatem_devcount()
	local i = 0;
	for k,v in pairs(devices) do
		if (not v.lost) then
			i = i + 1;
		end
	end
	return i;
end

local function tryload(map)
	local res = system_load("devmaps/" .. map, 0);
	if (not res) then
		warning(string.format("iostatem, system_load on map %s failed", map));
		return;
	end

	local okstate, id, flt, handler, ahandler = pcall(res);
	if (not okstate) then
		warning(string.format("iostatem, couldn't get handlers for %s", map));
		return;
	end

	if (type(id) ~= "string" or type(flt) ~=
		"string" or type(handler) ~= "function") then
		warning(string.format("iostatem, map %s returned wrong types", map));
		return;
	end

	if (label_lookup[id] ~= nil) then
		warning("iostatem, identifier collision for %s", map);
		return;
	end

	if (string.match(API_ENGINE_BUILD, flt)) then
		label_lookup[id] = {handler, (ahandler and type(ahandler) == "function")
			and ahandler or default_ah};
	end
end

local function set_period(id, val)
	def_period = val;
end

local function set_delay(id, val)
	val = val < 0 and 1 or math.ceil(val / 1000 * CLOCKRATE);
	def_delay = val;
end

function iostatem_init()
	devstate.devices = {};
	set_period(nil, gconfig_get("kbd_period"));
	set_delay(nil, gconfig_get("kbd_delay"));
	gconfig_listen("kbd_period", "iostatem", set_period);
	gconfig_listen("kbd_delay", "iostatem", set_delay);
	devstate.counter = def_delay;
	local list = glob_resource("devmaps/*.lua", DEVMAP_DOMAIN);

-- glob for all devmaps, make sure they match the platform and return
-- correct types and non-colliding identifiers
	for k,v in ipairs(list) do
		tryload(v);
	end

-- all analog sampling on by default, then we manage on a per-window
-- and per-device level
	inputanalog_toggle(true);
	iostatem_save();
end

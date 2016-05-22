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
local rol_avg = 1;
local evc = 1;

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

function iostatem_debug()
	return string.format("st: %d, ctr: %d, dly: %d, rate: %d, inavg: %.2f, cin: %.2f",
		devstate.iotbl and "1" or "0",
		devstate.counter, devstate.delay, devstate.period, rol_avg, evc);
end

function iostatem_restore(tbl)
	if (tbl == nil) then
		tbl = odst;
	end

	devstate = tbl;
	devstate.iotbl = nil;
	devstate.counter = tbl.delay and tbl.delay or def_delay;
	devstate.period = tbl.period and tbl.period or def_period;
-- FIXME: toggle proper analog axes and filtering
end

-- just feed this function, will cache state as necessary
local badseq = 1;
function iostatem_input(iotbl)
	local dev = devices[iotbl.devid];
	evc = evc + 1;

-- !dev shouldn't happen but may be an input platform bug
-- add a placeholder device so that we will at least 'work' normally
	if (not dev) then
		local lbl = "unkn_bad_" .. badseq;
		badseq = badseq + 1;
		local oldlbl = iotbl.label;
		iotbl.label = lbl;
		dev = iostatem_added(iotbl);
		iotbl.label = oldlbl;
	end

-- currently mouse state management is handled elsewhere (durden+tiler.lua)
-- but we simulate a fake 'joystick' device here to allow meta + mouse to be
-- bound while retaining normal mouse behavior
	if (iotbl.mouse) then
		local m1, m2 = dispatch_meta();
		if (iotbl.digital and (m1 or m2)) then
			iotbl.mouse = nil;
		else
			return;
		end
	end

	if (iotbl.translated) then
		if (not iotbl.active or SYMTABLE:is_modifier(iotbl)) then
			devstate.counter = devstate.delay ~= nil and devstate.delay or def_delay;
			devstate.iotbl = nil;
			return;
		end

		devstate.iotbl = iotbl;

	elseif (iotbl.digital) then
		iotbl.dsym = tostring(iotbl.devid).."_"..tostring(iotbl.subid);
		if (dev.slot > 0) then
			iotbl.label = dev.lookup and
				"PLAYER"..tostring(dev.slot).."_"..dev.lookup[1](iotbl.subid) or "";
		end

	elseif (iotbl.analog and dev and dev.slot > 0) then
		local ah, af = dev.lookup[2](iotbl.subid);
		if (ah) then
			iotbl.label = "PLAYER" .. tostring(dev.slot) .. "_" .. ah;
			if (af ~= 1) then
				for i=1,#iotbl.samples do
					iotbl.samples[i] = iotbl.samples[i] * af;
				end
			end
		end

-- only forward if asbolutely necessary (i.e. selected window explicitly accepts
-- analog) as the input storms can saturate most event queues
	return true;
	else
-- nothing for touch devices right now
	end
end

function iostatem_reset_repeat()
	devstate.iotbl = nil;
	devstate.counter = devstate.delay;
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
	rol_avg = rol_avg * (CLOCK - 1) / CLOCK + evc / CLOCK;
	evc = 0;

	if (devstate.counter == 0) then
		return;
	end

	if (devstate.iotbl and devstate.period) then
		devstate.counter = devstate.counter - 1;

		if (devstate.counter == 0) then
			devstate.counter = devstate.period;

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
		if (iotbl.devid == nil) then
			for k,v in pairs(iotbl) do print(k, v); end
		end

		devices[iotbl.devid] = {
			devid = iotbl.devid,
			label = iotbl.label,
-- we only switch analog sampling on / off
			lookup = label_lookup[iotbl.label]
				and label_lookup[iotbl.label] or {default_lh, default_ah},
			force_analog = false,
			keyboard = (iotbl.keyboard and true or false)
		};
		dev = devices[iotbl.devid];
		if (label_lookup[iotbl.label]) then
			assign_slot(dev);
		else
			dev.slot = 0;
		end
	else
-- keeping this around for devices and platforms that generate a new
-- ID for each insert/removal will slooowly leak (unlikely though)
		if (dev.lost) then
			dev.lost = false;
-- reset analog settings and possible load slot again
			assign_slot(dev);
		else
			warning("added existing device "..dev.label..", likely platform bug.");
		end
	end
	return devices[iotbl.devid];
end

function iostatem_removed(iotbl)
	local dev = devices[iotbl.devid];
	if (dev) then
		dev.lost = true;
-- protection against keyboard behaving differently when lost/found
		if (iotbl.devkind == "keyboard") then
			meta_guard_reset();
		end
	else
		warning("remove unknown device, likely platform bug.");
	end
end

local function get_devlist(eval)
	local res = {};
	for k,v in pairs(devices) do
		if (eval(v)) then
			table.insert(res, v);
		end
	end
	return res;
end

function iostatem_devices(slotted)
	local lst;
	if (slotted) then
		lst = get_devlist(function(a) return not a.lost and a.slot > 0; end);
		table.sort(lst, function(a, b) return a.slot < b.slot; end);
	else
		lst = get_devlist(function(a) return not a.lost; end);
		table.sort(lst, function(a,b) return a.devid < b.devid; end);
	end
		return ipairs(lst);
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

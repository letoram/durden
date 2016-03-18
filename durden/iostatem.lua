--
-- wrapper for _input_event that tracks device states for repeat-rate control
-- and for "uncommon" devices that fall outside the normal keyboard/mouse
-- setup, that require separate lookup and translation, including state-
-- toggle on a per window (save/restore) basis etc.
--

local devstate = {};
local devices = {};

-- returns a table that can be used to restore the input state, used
-- for context switching between different windows or input targets.
local odst;

function iostatem_save()
	odst = devstate;
	devstate = {
		iotbl = nil,
		period = devstate.period,
		delay = devstate.delay,
		counter = 0
	};
	return odst;
end

function iostatem_state()
	return devstate.period, devstate.delay, devstate.counter;
end

function iostatem_restore(tbl)
	dispatch_meta_reset();
	devstate = tbl and tbl or odst;
	devstate.iotbl = nil;
	devstate.counter = devstate.delay;
end

-- just feed this function, will cache state as necessary
function iostatem_input(iotbl)
	if (iotbl.translated) then
		if (not iotbl.active or SYMTABLE:is_modifier(iotbl)) then
			devstate.iotbl = nil;
			return;
		end

		devstate.iotbl = iotbl;
		devstate.counter = devstate.delay;
	end
end

-- delay in ms, period in cps
function iostatem_repeat(period, delay)
	if (period ~= nil) then
		if (period <= 0) then
			devstate.period = 0;
		else
			devstate.period = math.ceil(period / CLOCKRATE);
		end
	end

	if (delay ~= nil) then
		devstate.delay = delay < 0 and 1 or math.ceil(delay / (1000 / CLOCKRATE));
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

function iostatem_added(iotbl)
	local dev = devices[iotbl.devid];
	if (not dev) then
-- locate last saved device settings etc.
		devices[iotbl.devid] = {
			devid = iotbl.devid,
			translated = iotbl.translated
		};
	else
-- keeping this around for devices and platforms that generate a new
-- ID for each insert/removal will slooowly leak (unlikely though)
		if (dev.lost) then
			dev.lost = false;
-- re-run possible device filtering settings
		else
			warning("added existing device, likely platform bug.");
		end
	end
end

function iostatem_removed(iotbl)
	local dev = devices[iotbl.devid];
	if (dev) then
		devices[iotbl.devid].lost = true;
-- protection against keyboard behaving differently when lost/found
		if (devices[iotbl.devid].translated) then
			meta_guard_reset();
		end
	else
		warning("remove unknown device, likely platform bug.");
	end
end

function iostatem_devcount()
	local i = 0;
	for k,v in pairs(devices) do
		if (not devices[iotbl.devid].lost) then
			i = i + 1;
		end
	end
	return i;
end

function iostatem_init()
	devstate.devices = {};
	iostatem_repeat(gconfig_get("kbd_period"), gconfig_get("kbd_delay"));
	iostatem_save();
end

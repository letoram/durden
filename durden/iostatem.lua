--
-- wrapper for _input_event that tracks device states for repeat-rate control
-- only support the last translated device at the moment, plan is to expand
-- with configurable repeatability for all digital devices.
--

local devstate = {};

-- returns a table that can be used to restore the input state, used
-- for context switching between different windows or input targets.
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

function iostatem_restore(tbl)
	devstate = tbl;
end

-- just feed this function, will cache state as necessary
function iostatem_input(iotbl)
	if (iotbl.translated) then
		if (not iotbl.active) then
			devstate.iotbl = nil;
			return;
		end

		devstate.iotbl = iotbl;
		devstate.counter = devstate.delay;
	end
end

-- delay in ms, period in cps
function iostatem_repeat(period, delay)
	devstate.delay = 1;
	if (period <= 0) then
		devstate.period = 0;
	else
		devstate.period = math.ceil(period / CLOCKRATE);
	end

	devstate.delay = delay < 0 and 1 or math.ceil(delay / (1000 / CLOCKRATE));
	devstate.counter = devstate.delay;
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

-- scan devstate.devies
end

function iostatem_init()
	kbd_repeat(0, 0);
	devstate.devices = {};
end

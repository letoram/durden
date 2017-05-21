--
-- different roles:
--  passive : manual config, will be mapped to the menu system
--  keymap  : current keyboard state will be pushed unto map,
--            map defines SYM/key -> ledid translation
--  custom  : separate function, invoked from clock_pulse
--  dispmap : separate function, sample-rate triggered clock
--
--  if a device doesn't have a matching profile, it will always go to passive
--
local readback_handler;
local profile_path = "devmaps/led";
local devices = {
	passive = {},
	keymap = {},
	custom = {},
	dispmap = {}
};
local profiles = {};

local function tryload(map)
	res = system_load(profile_path .. "/" .. map, 0);
	if (not res) then
		warning(string.format("ledm, system_load on map %s failed", map));
		return;
	end

	local okstate, devtbl = pcall(res);
	if (not okstate or not type(devtbl) == "table") then
		warning(string.format("ledm, couldn't load/parse %s", map));
		return;
	end

-- FIXME: type-validation

	return devtbl;
end

local function load_profiles()
	local list = glob_resource(profile_path .. "/*.lua");
	if (not list) then
		return;
	end

	table.sort(list);
	for k,v in ipairs(list) do
		local res = tryload(v);
		if (res and type(res.role) == "string" and devices[res.role] ~= nil) then
			table.insert(profiles, res);
		end
	end
end

function ledm_added(tbl)
-- shouldn't trigger anything but protect against platform bugs
	ledm_removed(tbl);
	for i,v in ipairs(profiles) do
		if ((v.matchdev and tbl.domain == "platform" and tbl.devid == v.matchdev) or
		(v.matchlbl == tbl.label)) then
			local newt = {};
			for k,v in pairs(v) do
				newt[k] = v;
			end
			newt.devid = tbl.devid;
			table.insert(devices[v.role], newt);
			return;
		end
	end

-- still here, then it's a passive one
	table.insert(devices.passive, {
		domain = tbl.domain,
		devid = tbl.devid,
		role = "passive",
		label = tbl.label,
	});
end

-- Find device reference and invoke event handler, note that the event
-- layer does not track device label, only domain+id
function ledm_removed(tbl)
	for k, d in pairs(devices) do
	for i, v in ipairs(d) do
		if (v.domain == tbl.domain and v.devid == tbl.devid) then
			if (v.destroy) then
				v:destroy();
			end
			table.remove(d, i);
			return;
		end
	end
	end
end

-- updated when selection changes, locked state changes or meta- key state
-- changes.
function ledm_kbd_state(m1, m2, locked, globals, targets, locals)
	if (locked) then
		for k,v in ipairs(devices.keymap) do
			local cl = v.default_color;
			set_led_rgb(v.devid, -1, cl[1], cl[2], cl[3]);
		end
		return;
	end

-- reset everything, light up m1/m2 unless they are pressed.
	for k,v in ipairs(devices.keymap) do
		local cl = v.default_color;

		set_led_rgb(v.devid, -1, 0, 0, 0, false);
		if (not m1) then
			local cl = v.m1_color;
			set_led_rgb(v.devid, v.m1, cl[1], cl[2], cl[3], true);
		end
		if (not m2) then
			local cl = v.m2_color;
			set_led_rgb(v.devid, v.m2, cl[1], cl[2], cl[3], true);
		end

		if (globals) then
			local cl = v.global_color;
			for i,d in ipairs(globals) do
				if (v.symtable[d]) then
					set_led_rgb(v.devid, v.symtable[d], cl[1], cl[2], cl[3], true);
				end
			end
		end

		if (targets) then
			local cl = v.target_generic_color;
			for i,d in ipairs(targets) do
				if (v.symtable[d]) then
					set_led_rgb(v.devid, v.symtable[d], cl[1], cl[2], cl[3], true);
				end
			end
		end

--
-- reserved for now as the shmif- part actually misses the modifier information
--		if (locals) then
--			for i,d in ipairs(locals) do
--				if (v.symtable[d]) then
--			set_led_rgb(v.devid, v.symtable[d], unpack(v.target_custom_color), true);
--  		end
--		end
--		end

-- abuse the last id as a way to commit without tracking more state
		set_led_rgb(v.devid, 255, 0, 0, 0, false);
	end
end

-- FIXME: display_map listener

--
-- return a table of all the present LED devices that match all or one role
--
function ledm_devices(role)
	local res = {};
	if (role) then
		return (devices[role] and devices[role] or res);
	end

	for k, d in pairs(devices) do
	for i, v in ipairs(d) do
		table.insert(res, {
			label = v.label and v.label or tostring(v.devid),
			name = v.name and v.name or tostring(v.devid),
			devid = v.devid
		});
	end
	end

	return res;
end

function ledm_tick()
	for k,v in ipairs(devices.custom) do
		if (v.counter == nil or v.counter == 1) then
			v.counter = v.tickrate;
			v.clock(v.devid);
		else
			v.counter = v.counter - 1;
		end
	end
end

load_profiles();

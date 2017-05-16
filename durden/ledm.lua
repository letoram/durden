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
local devices = {};
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
		if (res) then
			table.insert(profiles, res);
		end
	end
end

function ledm_added(tbl)
-- shouldn't trigger anything but protect against platform bug
	ledm_removed(tbl);

	for i,v in ipairs(profiles) do
		if (v.matchdev and tbl.domain == "platform" and tbl.devid == v.matchdev) then
		elseif (v.matchlbl == tbl.label) then
			local newt = {};
			for k,v in pairs(v) do
				newt[k] = v;
			end
			newt.devid = tbl.devid;
			table.insert(devices, newt);
			return;
		end
	end
-- still here, then it's a passive one
	table.insert(devices, {
		domain = tbl.domain,
		devid = tbl.devid,
		role = "passive",
		label = tbl.label,
	});
end

-- Find device reference and invoke event handler
function ledm_removed(tbl)
	for i, v in ipairs(devices) do
		if (v.domain == tbl.domain and v.devid == tbl.devid) then
			if (v.destroy) then
				v:destroy();
			end
			table.remove(devices, i);
			return;
		end
	end
end

-- updated when selection changes, locked state changes or meta- key state
-- changes.
function ledm_kbd_state(m1, m2, locked, targets)
end

--
-- return a table of all the present LED devices that match all or one role
--
function ledm_devices(role)
	local res = {};

	for k,v in pairs(devices) do
		if (role == nil or v.role == role) then
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
	for k,v in ipairs(devices) do
		if (v.role == "custom") then
			if (v.counter == nil or v.counter == 1) then
				v.counter = v.tickrate;
				v.clock(v.devid);
			else
				v.counter = v.counter - 1;
			end
		end
	end
end

load_profiles();

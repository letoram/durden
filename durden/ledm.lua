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

local function load_profiles()
--	local list = glob_resources(profile_path .. "/*.lua");
end

function ledm_added(tbl)
-- shouldn't trigger anything but protect against platform bug
	ledm_removed(tbl);

	for i,v in ipairs(profiles) do
		if (v.matchdev and tbl.domain == "platform" and tbl.devid == v.matchdev) then
		elseif (v.matchflt == tbl.label) then
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

function ledm_clock_pulse()
	for k,v in ipairs(devices) do
		if (v.profile == "custom") then
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

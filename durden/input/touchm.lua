-- Copyright: 2016-2019, Björn Ståhl
-- Description: Touch, tablet, multitouch support and routing.
-- This unit hooks itself through iostatem and selectively takes control
-- of devices that fits a preset profile (devmaps/touch/...). These profiles
-- sets default parameters and state-machine ('classifier') which filters
-- and interprets the incoming event stream.
local devices = {};
local profiles = {};
local default_profile = nil;

local idevice_log = suppl_add_logfn("idevice");
local touchm_evlog = function(msg)
	idevice_log("submodule=touch:" .. msg);
end

-- classifiers take a device configuration profile and translate
-- input samples on the device to dispatch actions or new input
-- events on virtual devices
local classifiers = {};
local mclassifiers = system_load("input/classifiers/mouse.lua")();
for k,v in pairs(mclassifiers) do
	classifiers[k] = v;
end

touchm_evlog("status=active");

local function tryload(map)
	local res = system_load("devmaps/touch/" .. map, 0);
	if  (not res) then
		touchm_evlog("kind=error:status=eexist:source=" .. map);
		return;
	end

	local okstate, profile = pcall(res);
-- completely broken?
	if (not okstate or not type(profile) == "table") then
		touchm_evlog("kind=error:status=einval:message=parsing error:source=" .. map);
		return;
	end

	if (not profile.label or not profile.name) then
		touchm_evlog("kind=error:status=einval:message=missing field:source=" .. map);
		return;
	end

-- sanity check fields or revert to defaults
	local res = {};
	res.label = profile.label;
	res.name = profile.name;

-- used for touch-device plugging
	res.matchflt = profile.matchflt;
	res.matchstr = profile.matchstr;

	local ref = {
		mt_eval = 10,
		swipe_threshold = 0.2,
		drfag_threshold = 0.2,
		autorange = true,
		timeout = 10,
		idle_base = 500,
		motion_block = false,
		warp_press = false,
		touch_only = false,
		autorange = true,
		activation = {0.0, 0.0, 1.0, 1.0},
		scale_x = 1.0,
		scale_y = 1.0,
		range = {0, 0, VRESW, VRESH},
		gestures = {},
		zones = {},
		axis_remap = {},
		button_remap = {},
		cooldown = 4
	};

	table.merge(res, profile, ref,
	function(k)
		touchm_evlog(string.format(
			"kind=error:status=einval:key=%s:source=%s", k, map));
	end);

-- device start as idle
	res.idle = res.idle_base;
	res.default_cooldown = res.cooldown;

	return res;
end

local function pair_device_profile(dev, prof)
	if (not prof) then
		return;
	end

	if (prof.matchstr) then
		return dev.label == prof.matchstr;
	end

	if (prof.matchflt) then
		return string.match(dev.label, prof.matchflt);
	end
end

local function apply_classifier(cf, profile, devtbl, devid)
	local new_profile = table.copy(profile);
	cf.init(new_profile);

	for k,v in pairs(new_profile) do
		devtbl[k] = v;
	end
	devtbl.tick = cf.tick;

	iostatem_register_handler(devid, "touch",
		function(iotbl)
			cf.sample(devtbl, iotbl);
		end
	);
end

-- normally a device class like this would be added by adding a listener
-- to the iostatem change, and then see if device/label match what it can
-- handle, but touch is treated as a primitive type, and we don't know for
-- every platform whether an aggregate device supports this or not so we
-- trigger on first unhandled touch sample inside of iostatem_input
function touch_register_device(iotbl, eval)
	local devstr = "kind=status:device=" .. tostring(iotbl.devid);

	if (devices[iotbl.devid]) then
		touchm_evlog(devstr .. ":message=ignore register, reason: known");
		return;
	end

-- try and find a profile based on device name
	local devtbl = iostatem_lookup(iotbl.devid);
	local profile = nil;
	if (devtbl and devtbl.label) then
		for _,v in ipairs(profiles) do
			if (pair_device_profile(devtbl, v)) then
				profile = v;
				touchm_evlog(devstr .. ":matched=" .. devtbl.label);
				break;
			end
		end
	end

	if (not profile) then
		if (eval) then
			return;
		end
		touchm_evlog(devstr .. ":message=no profile, assigning default");
		profile = default_profile;
	end

-- set table that wiill maintain state for the device
	devices[iotbl.devid] = {};
	local devtbl = st;

-- grab the matching classifier
	if (classifiers[profile.classifier]) then
		cf = classifiers[profile.classifier];
-- or fallback
	elseif (classifiers[gconfig_get("mt_classifier")]) then
		cf = classifiers[gconfig_get("mt_classifier")];
	else
		cf = classifiers["relmouse"];
	end

	if not cf then
		touchm_evlog("kind=warning:message=missing /unknown classifier");
		return;
	end

	apply_classifier(cf, profile, devices[iotbl.devid], iotbl.devid);

-- reinject input so the sample gets used as well
	durden_input(iotbl);
end

function touch_shutdown()
-- sweep devices and store ranging values, need some kind of profile-key
-- to store under, and only store autoranged devices and calibration
-- profiles
end

local clock_fun = function(...)
	for k,v in pairs(devices) do
		v.idle = v.idle + 1;

-- treat idle management as a gesture
		if not v.in_idle and v.idle > v.idle_base then
			v.in_idle = true;
			touchm_evlog("device=" .. tostring(k) .. ":gesture_key=idle_enter");
			if v.gestures["idle_enter"] then
				dispatch_symbol(v.gestures[key]);
			end
		end

-- profiles have an individual clock to for normal gestures
		if (v.tick) then
			v:tick();
		end
	end
end

function touchm_reload()
	profiles = {};
	local lst = glob_resource("devmaps/touch/*.lua", APPL_RESOURCE);
	if (not lst) then
		return;
	end

	table.sort(lst);
	for k,v in ipairs(lst) do
		local res = tryload(v);
		if (res) then
			table.insert(profiles, res);
		end
	end

	for k,v in ipairs(profiles) do
		if (v.name == "default") then
			default_profile = v;
			return true;
		end
	end

	touchm_evlog("kind=disabled:message=no default profile");
	return false;
end

touchm_reload();
timer_add_periodic("touch", 1, false, clock_fun, false);

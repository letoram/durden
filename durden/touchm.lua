-- Copyright: 2016, Björn Ståhl
-- touch, tablet, multitouch support and routing.
-- each device is assigned a classifier that covers how multitouch
-- events should be mapped to other device behaviors or explicit
-- gestures.

--
-- On an unknown touch event entering, we should run a calibration
-- tool automatically, with the option to ignore/disable the device
-- or automatic activation.
--
-- The tool should query for:
--  [number of fingers]
--  actual range
--  pressure- sensitivity
--  preferred classifier (relmouse, absmouse, gesture, more advanced..)
--  if it also maps to any mouse event
--  and possibly disabilities in the user (e.g. parkinson)
--
-- good cases to try it out with is DS "second screen" touch input
-- and some vectorizer -> chinese OCR style input
--

local gestures = {
	M1_TAP_1 = 1,
	M1_TAP_2 = 2,
	M1_DBL_TAP = 4,
};

local devices = {};
local profiles = {};

local function tryload(map)
	local res = system_load("devmaps/touch/" .. map, 0);
	if  (not res) then
		warning(string_format("touchm, system_load on map %s failed", map));
		return;
	end

	local okstate, devtbl = pcall(res);
	if (not okstate or not type(devtbl) == "table") then
		warning(string.format("touchm, couldn't load/parse %s", map));
		return;
	end

	local res = {};
	if (not devtbl.label or not devtbl.name) then
		warning(string.format("touchm, map %s is missing label/name", map));
		return;
	end

-- sanity check fields or revert to defaults
	res.label = devtbl.label;
	res.name = devtbl.name;

-- used for touch-device plugging
	res.matchflt = devtbl.matchflt;

-- used for translating absolute coordinates into relative
	if (not devtbl.autorange and not devtbl.range) then
		res.autorange = true;
	end

	if (devtbl.range) then
		res.range = {};
		res.range[1] = devtbl.range.low_x and devtbl.range.low_x or VRESW;
		res.range[2] = devtbl.range.low_y and devtbl.range.low_y or VRESH;
		res.range[3] = devtbl.range.high_x and devtbl.range.high_x or 0;
		res.range[4] = devtbl.range.high_y and devtbl.range.high_y or 0;
	end

	res.activation = {0.0, 0.0, 1.0, 1.0};
	if (devtbl.activation) then
		if (type(devtbl.activation) == "table" and #devtbl.activation == 4) then
			res.activation = devtbl.activation;
		else
			warning(string.format("touchm, map %s has wrong activation field", map));
		end
	end

-- gestures map to normal menu paths
	res.scale_x = devtbl.scale_x and devtbl.scale_x or 1.0;
	res.scale_y = devtbl.scale_y and devtbl.scale_y or 1.0;
	res.gestures = {};
	res.zones = {};
	if (devtbl.gestures) then
		for k,v in ipairs(devtbl.gestures) do
			if (typeof(v) == "string" and typeof(k) == "string") then
				res.gestures[k] = v;
			else
				warning(string.format("touchm, gesture %s ignored\n", k));
			end
		end
	end

	if (devtbl.button_remap) then
		res.button_remap = {};
		for k,v in ipairs(devtbl.button_remap) do
			if (type(v) == "number") then
				res.button_remap[k] = v;
			end
		end
	end

	res.timeout = (devtbl.timeout and type(devtbl.timeout) == "number") and
		devtbl.timeout or 10;

	res.default_cooldown = (devtbl.default_cooldown and type(
		devtbl.default_cooldown) == "number") and devtbl.default_cooldown or 3;
	return res;
end

local function nbits(v)
	local res = 0;
	while(v > 0) do
		res = res + bit.band(v, 1);
		v = bit.rshift(v, 1);
	end
	return res;
end

function touchm_reload()
	profiles = {};
	local lst = glob_resource("devmaps/touch/*.lua", APPL_RESOURCE);
	for k,v in ipairs(lst) do
		local res = tryload(lst);
		if (res) then
			table.insert(profiles, res);
		end
	end
end

touchm_reload();

-- aggregate samples with a variable number of ticks as sample period
-- and then feed- back into _input as a relative mouse input event
local function relative_sample(devtbl, iotbl)
	local ind = iotbl.subid - 128;

-- digital is bothersome as some devices send the first button as
-- finger on pad even if it has a 'real' button underneath. Then we
-- have 'soft'buttons multitap, and the default behavior for the device
-- in iostatem..
	if (iotbl.digital) then
		if (devtbl.button_remap) then
			local bi = devtbl.button_remap[iotbl.subid];
			if (bi) then
				mouse_button_input(bi, iotbl.active);
			end
		elseif (iotbl.subid < MOUSE_AUXBTN) then
			mouse_button_input(iotbl.subid, iotbl.active);
		end
		return iotbl;
	end

	if (not iotbl.x or not iotbl.y) then
		return;
	end

-- update range
	if (devtbl.autorange) then
		devtbl.range[1] = iotbl.x < devtbl.range[1] and iotbl.x or devtbl.range[1];
		devtbl.range[2] = iotbl.y < devtbl.range[2] and iotbl.y or devtbl.range[2];
		devtbl.range[3] = iotbl.x > devtbl.range[3] and iotbl.x or devtbl.range[3];
		devtbl.range[4] = iotbl.y > devtbl.range[4] and iotbl.y or devtbl.range[4];
	end

-- convert to normalized coordinates
	local x = (iotbl.x - devtbl.range[1]) / devtbl.range[3];
	local y = (iotbl.y - devtbl.range[2]) / devtbl.range[4];

-- track sample for auto-reset
	devtbl.last_sample = CLOCK;

-- check for activation, we want a cooldown to this so that the slight
-- delay in multitouch doesn't result in real mouse events
	if (not devtbl.in_active) then
		if (x >= devtbl.activation[1] and x <= devtbl.activation[3] and
			y >= devtbl.activation[2] and y <= devtbl.activation[4]) then
			devtbl.in_active = true;
			devtbl.last_x = x;
			devtbl.last_y = y;
			devtbl.cooldown = devtbl.default_cooldown;
		end
		return;
	end

	local im = bit.lshift(1, ind);
	local nm = devtbl.ind_mask;

-- track for the transition between single- and multitouch
	if (iotbl.active) then
		nm = bit.bor(devtbl.ind_mask, im);
		if (nm ~= devtbl.ind_mask) then
			if (nbits(nm) == 1) then
				devtbl.primary = nm;
			end
		end
		devtbl.ind_mask = nm;
	else
		nm = bit.band(devtbl.ind_mask, bit.bnot(im));
		if (nm == 0 or (nm == 1 and ind ~= devtbl.primary_ind)) then
			devtbl.in_active = false;
		else
			devtbl.last_x = x;
			devtbl.last_y = y;
		end
		devtbl.ind_mask = nm;
		return;
	end

	if (nbits(devtbl.ind_mask) == 1 and devtbl.ind_mask == devtbl.primary) then
		local ad = active_display();
		local dx = (x - devtbl.last_x) * devtbl.scale_x;
		local dy = (y - devtbl.last_y) * devtbl.scale_y;
		devtbl.last_x = x;
		devtbl.last_y = y;
		if (devtbl.cooldown == 0) then
			mouse_input(VRESW * dx, VRESH * dy);
		end
	end
	return nil;
end

local function relative_init(prof, st)
-- one-level copy
	for k,v in pairs(prof) do
		if (type(v) == "table") then
			st[k] = {};
			for j,l in pairs(v) do
				st[k][j] = l;
			end
			for j,l in ipairs(v) do
				st[k][j] = l;
			end
		else
			st[k] = v;
		end
	end

-- basic tracking we need
	st.gest_mask = 0;
	st.ind_mask = 0;
end

local classifiers = {
	relmouse = {relative_init, relative_sample}
};

local default_profile = {
	label = "default",
	name = "default",
	autorange = true,
	range = {0, 0, 1, 1},
	classifier = "relmouse",
	activation = {0.2, 0.2, 0.8, 0.8},
	scale_x = 1.0,
	scale_y = 1.0,
	default_cooldown = 2,
	timeout = 10,
	gestures = {
		swipe3_right = '!workspace/switch/next',
		swipe3_left = '!workspace/switch/prev',
	};
};

-- will only come here the firs time for each device
function touch_consume_sample(iotbl)
	if (not devices[iotbl.devid]) then
		local st = {};
		devices[iotbl.devid] = st;

-- try and find a profile based on device name
		local devtbl = iostatem_lookup(iotbl.devid);
		local profile = default_profile;
		if (devtbl and devtbl.label) then
			for k,v in ipairs(profiles) do
				if (v and v.matchflt and string.match(devtbl.label, v.matchflt)) then
					profile = v;
					break;
				end
			end
		end

-- grab the matching classifier
		if (classifiers[profile.classifier]) then
			cf = classifiers[profile.classifier];
-- or fallback
		elseif (classifiers[gconfig_get("mt_classifier")]) then
			cf = classifiers[gconfig_get("mt_classifier")];
		else
			cf = classifiers[relmouse];
		end

-- and register
		cf[1](profile, st);
		durden_register_devhandler(iotbl.devid, cf[2], st);
		durden_input(iotbl);
	end
end

-- sweep devices and store ranging values
function touch_shutdown()
end

local old = _G[APPLID .. "_clock_pulse"];
_G[APPLID .. "_clock_pulse"] = function(...)
	for k,v in pairs(devices) do
		if (v.in_active) then
			if (v.cooldown > 0) then
				v.cooldown = v.cooldown - 1;
			end
			if (CLOCK - v.last_sample > v.timeout) then
				v.in_active = false;
				v.ind_mask = 0;
			end
		end
	end
	old(...);
end

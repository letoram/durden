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
local devices = {};
local profiles = {};
local classifiers = {};
local default_profile = nil;

local function tryload(map)
	local res = system_load("devmaps/touch/" .. map, 0);
	if  (not res) then
		warning(string.format("touchm, system_load on map %s failed", map));
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
	res.mt_eval = (devtbl.mt_eval and type(devtbl.mt_eval) == "number") and
		devtbl.mt_eval or 10;
	res.swipe_threshold = (devtbl.swipe_threshold and
		type(devtbl.swipe_threshold) == "number") and devtbl.swipe_threshold or 0.2;
	res.drag_threshold = (devtbl.drag_threshold and
		type(devtbl.drag_threshold) == "number") and devtbl.drag_threshold or 0.2;
	res.autorange = devtbl.autorange and devtbl.autorange == true;
	res.submask = (devtbl.submask and type(devtbl.submask) == "number") and
		devtbl.submask or 0xfffff;
	res.timeout = (devtbl.timeout and type(devtbl.timeout) == "number") and
		devtbl.timeout or 10;
	res.motion_block = devtbl.motion_block or false;
	res.warp_press = devtbl.warp_press or false;
	res.touch_only = devtbl.touch_only or false;

-- used for translating absolute coordinates into relative
	if (not devtbl.autorange and not devtbl.range) then
		res.autorange = true;
	end

	if (devtbl.range) then
		res.range = {};
		res.range[1] = devtbl.range[1] and devtbl.range[1] or 0;
		res.range[2] = devtbl.range[2] and devtbl.range[2] or 0;
		res.range[3] = devtbl.range[3] and devtbl.range[3] or VRESW;
		res.range[4] = devtbl.range[4] and devtbl.range[4] or VRESH;
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
		for k,v in pairs(devtbl.gestures) do
			if (type(v) == "string" and type(k) == "string") then
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

-- get prefix%d_dir, only l/r/u/d down, no diags..
local function gen_key(prefix, thresh, dx, dy, nf)
	local adx = math.abs(dx);
	local ady = math.abs(dy);
	if (adx > ady) then
		if (adx - ady > thresh) then
			return string.format("%s%d_%s", prefix, nf, dx<0 and "left" or "right");
		end
	else
		if (ady - adx > thresh) then
			return string.format("%s%d_%s", prefix, nf, dy<0 and "up" or "down");
		end
	end
end

local function run_drag(dev, dx, dy, nf)
	local key = gen_key("drag", dev.drag_threshold, dx, dy, nf);
	if (key and dev.gestures[key]) then
		dispatch_symbol(dev.gestures[key]);
	end
end

local function run_swipe(dev, dx, dy, nf)
	local key = gen_key("swipe", dev.swipe_threshold, dx, dy, nf);
	if (key and dev.gestures[key]) then
		dispatch_symbol(dev.gestures[key]);
	end
end

-- aggregate samples with a variable number of ticks as sample period
-- and then feed- back into _input as a relative mouse input event
local function memu_sample(devtbl, iotbl)

-- poorly documented hack, subid is indexed higher for touch to handle
-- devices that emit both emulated mouse and touch events
	local ind = iotbl.subid - 128;
	if (ind < 0 and not iotbl.digital) then
		return;
	end

-- digital is bothersome as some devices send the first button as
-- finger on pad even if it has a 'real' button underneath. Then we
-- have 'soft'buttons multitap, and the default behavior for the device
-- in iostatem..
	if (iotbl.digital) then
-- warping is needed for a combination of a touch display that should
-- only give gestures and "touch-press" but have normal behavior with
-- a mouse or trackpad
		local mx, my = mouse_xy();
		if (devtbl.warp_press) then
			mouse_absinput_masked(devtbl.last_x, devtbl.last_y, true);
		end

		if (devtbl.button_remap) then
			local bi = devtbl.button_remap[iotbl.subid];
			if (bi) then
				mouse_button_input(bi, iotbl.active);
			end
-- if we don't have an explicit button map to use, use the ID and
-- modify with an optional "how many fingers on pad" value (can be masked out)
		elseif (iotbl.subid < MOUSE_AUXBTN) then
			local bc = nbits(devtbl.ind_mask);
			bc = bc > 0 and bc - 1 or bc;
			local badd = bit.band(bc, devtbl.submask);
			mouse_button_input(iotbl.subid + bc, iotbl.active);
		end

		if (devtbl.warp_press) then
			mouse_absinput_masked(mx, my, true);
		end
		return iotbl;
	end

-- platform or caller filtering, to allow devices lika a PS4 that has a touchpad
-- but also analog axes that we want to handle 'the normal way'
	if (not devtbl.touch and devtbl.touch_only) then
		return iotbl;
	end

	if (not iotbl.x or not iotbl.y) then
		if (iotbl.samples) then
-- something that fakes (or is) a mouse like derivative delivered samples here,
-- need to do the normal "only update on 1" trick
			if (iotbl.subid == 1) then
				iotbl.x = devtbl.cache_x;
				iotbl.y = iotbl.samples[1];
			else
				devtbl.cache_x = iotbl.samples[1];
				return;
			end
		else
			return iotbl;
		end
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
			devtbl.onef_enter = nil;
			devtbl.dxdt = 0;
			devtbl.dydt = 0;
			devtbl.max_ind = 0;
			devtbl.dxyclk = CLOCK;
			devtbl.cooldown = devtbl.default_cooldown;
		end
		return;
	end

-- detect which fingers have been added or removed
	local im = bit.lshift(1, ind);
	local nm = devtbl.ind_mask;

-- track for the transition to/from single- and multitouch
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
			if (devtbl.mt_enter) then
				if (devtbl.max_ind > 1 and not devtbl.dragged) then
					run_swipe(devtbl, devtbl.dxdt, devtbl.dydt, devtbl.max_ind);
				end
				devtbl.mt_enter = nil;
				devtbl.dragged = false;
				devtbl.max_ind = 0;
			end
		else
			devtbl.last_x = x;
			devtbl.last_y = y;
		end
		devtbl.ind_mask = nm;
		return;
	end

-- only track delta motion for the first finger, this
-- prevents the classifier from being able to distinguish
-- pinch/zoom style motion
	if (im ~= devtbl.primary) then
		return;
	end

-- finally figure out the actual motion and scale
	local dx = (x - devtbl.last_x) * devtbl.scale_x;
	local dy = (y - devtbl.last_y) * devtbl.scale_y;
	local nb = nbits(devtbl.ind_mask);

-- track the maximum number of fingers on the pad during a timeslot
-- to detect drag+tap or distinguish between 2/3 finger swipe
	if (devtbl.max_ind < nb) then
		devtbl.max_ind = nb;
	end

	devtbl.last_x = x;
	devtbl.last_y = y;

-- for one-finger drag, map to absolute or relative input, unless
-- "blocked". blocking motion can be useful for touch-displays where
-- presses should warp.
	if (nb == 1 and not devtbl.motion_block) then
		local ad = active_display();
		if (devtbl.abs) then
			mouse_absinput(ad.width * x, ad.height * y);
		else
			if (devtbl.cooldown == 0) then
				mouse_input(ad.width * dx, ad.height * dy);
			end
		end
-- track multi-finger gestures motion separate, this is reset in
-- per timeslot and can be used for magnitude in multi-finger drag
	elseif (nb >= 2) then
		if (not devtbl.mt_enter) then
			devtbl.mt_enter = CLOCK;
		end

		devtbl.dxdt = devtbl.dxdt + dx;
		devtbl.dydt = devtbl.dydt + dy;
	end
end

local function memu_init(abs, prof, st)
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
	st.last_sample = CLOCK;
	st.relative = abs;
end

local function memu_tick(v)
-- this captures 1,2,3+ button drag actions
	if (v.in_active) then
		if (v.cooldown > 0) then
			v.cooldown = v.cooldown - 1;
		end

	if (v.mt_enter and CLOCK - v.mt_enter >= v.mt_eval) then
-- check if dxdt exceeds threshold, and if so, convert to gesture
-- otherwise reset dxdt and drop mt_enter
			local nb = nbits(v.ind_mask);
			if (nb == 2 or nb == 3) then
				run_drag(v, v.dxdt, v.dydt, nb);
				v.dragged = true;
			end
			v.mt_enter = CLOCK;
			v.dxdt = 0;
			v.dydt = 0;
		end
	end

	if (CLOCK - v.last_sample > v.timeout) then
		v.in_active = false;
		v.ind_mask = 0;
		v.dragged = false;
		v.mt_enter = nil;
	end
end

classifiers.relmouse =
-- simple classifier that only takes 1-finger drag to mouse and
-- 2-3 finger drag/sweeps into account, to be complemented with
-- more competent ones
	{function(...) memu_init(false, ...); end, memu_sample, memu_tick};

classifiers.absmouse =
	{function(...) memu_init(true, ...); end, memu_sample, memu_tick};

-- will only come here the first time for each device
function touch_register_device(iotbl, eval)
	if (devices[iotbl.devid]) then
		return;
	end

-- try and find a profile based on device name
	local devtbl = iostatem_lookup(iotbl.devid);
	local profile = nil;
	if (devtbl and devtbl.label) then
		for k,v in ipairs(profiles) do
			if (v and v.matchflt and (
				devtbl.label == v.matchflt or string.match(devtbl.label, v.matchflt))) then
				profile = v;
				break;
			end
		end
	end

	if (not profile) then
		if (eval) then
			return;
		end
		profile = default_profile;
	end

	local st = {};
	devices[iotbl.devid] = st;

-- grab the matching classifier
	if (classifiers[profile.classifier]) then
		cf = classifiers[profile.classifier];
-- or fallback
	elseif (classifiers[gconfig_get("mt_classifier")]) then
		cf = classifiers[gconfig_get("mt_classifier")];
	else
		cf = classifiers["relmouse"];
	end

-- and register
	if (cf) then
		cf[1](profile, st);
		durden_register_devhandler(iotbl.devid, cf[2], st);
		durden_input(iotbl);
		st.tick = cf[3];
	else
		warning(string.format(
			"touchm, no classifier loaded for %s", profile.classifier));
	end
end

-- sweep devices and store ranging values
function touch_shutdown()
end

local clock_fun = function(...)
	for k,v in pairs(devices) do
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
			touch_tick = clock_fun;
			return true;
		end
	end

	warning("touchm_reload(), no default profile found, touch disabled");
	touch_tick = function() end;
	return false;
end

touchm_reload();

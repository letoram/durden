-- Copyright: 2016-2020, Björn Ståhl
-- Description: Touch, tablet, multitouch support and routing.
-- of devices that fits a preset profile (devmaps/touch/...). These profiles
-- sets default parameters and state-machine ('classifier') which filters
-- and interprets the incoming event stream.
local devices = {};
local profiles = {};
local default_profile = nil;

local idevice_log, fmt = suppl_add_logfn("idevice");
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
	res = {};
	res.label = profile.label;
	res.name = profile.name;

-- used for touch-device plugging
	res.matchflt = profile.matchflt;
	res.matchstr = profile.matchstr;

	local ref = {
		mt_eval = 10,
		swipe_threshold = 0.2,
		drag_threshold = 0.2,
		autorange = true,
		timeout = 10,
		idle_base = 500,
		motion_block = false,
		warp_press = false,
		touch_only = false,
		activation = {0.0, 0.0, 1.0, 1.0},
		swap_xy = false,
		invert_x = false,
		invert_y = false,
		scale_x = 1.0,
		scale_y = 1.0,
		classifier = "relmouse",
		range = {0, 0, VRESW, VRESH},
		gestures = {},
		zones = {},
		axis_remap = {},
		button_remap = {},
		cooldown = 4
	};

	table.merge(res, profile, ref,
	function(k)
		touchm_evlog(fmt(
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
	devtbl.profile = profile;

	if (devid) then
		iostatem_register_handler(devid, "touch",
			function(iotbl)
				cf.sample(devtbl, iotbl);
			end
		);
end
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
	local devtbl = {};
	devices[iotbl.devid] = devtbl;

-- grab the matching classifier
	if (classifiers[profile.classifier]) then
		touchm_evlog(devstr .. "classsifier=" .. profile.classifier);
		cf = classifiers[profile.classifier];
-- or fallback
	elseif (classifiers[gconfig_get("mt_classifier")]) then
		touchm_evlog(devstr .. "classsifier=mt_default:name=" .. gconfig_get("mt_classifier"));
		cf = classifiers[gconfig_get("mt_classifier")];
	else
		cf = classifiers["relmouse"];
	end

	if not cf then
		touchm_evlog("kind=warning:message=missing /unknown classifier");
		return;
	end

	apply_classifier(cf, profile, devtbl, iotbl.devid);

-- load autorange values and profile overrides
	local name = "touch_" ..profile.name .. "_%";
	for _,v in ipairs(match_keys(name)) do
		local key, val = string.split_first(v, "=");
		local subkey = string.sub(key, #name);
		if subkey == "range" then
			for i, v in ipairs(string.split(val, ":")) do
				local num = tonumber(v);
				if num and devtbl.range[i] then
					devtbl.range[i] = num;
				end
			end
		end
	end

-- reinject input so the sample gets used as well
	durden_input(iotbl);
end

function touch_shutdown()
end

-- shared by classifiers after translating input, autoranged devices
function touchm_update_range(devtbl, iotbl)
	local rt = devtbl.range;

	if iotbl.x < rt[1] then
		rt[1] = iotbl.x;
		devtbl.range_dirty = true;

	elseif iotbl.x > rt[3] then
		rt[3] = iotbl.x;
		devtbl.range_dirty = true;
	end

	if iotbl.y < rt[2] then
		rt[2] = iotbl.y;
		devtbl.range_dirty = true;

	elseif iotbl.y > rt[4] then
		rt[4] = iotbl.y;
		devtbl.range_dirty = true;
	end
end

local clock_fun = function(...)
	for k,v in pairs(devices) do
		v.idle = v.idle + 1;

-- treat idle management as a gesture
		if not v.in_idle and v.idle > v.idle_base then
			v.in_idle = true;
			touchm_evlog(fmt("device=%s:gesture_key=idle_enter", v.name));
			if v.gestures["idle_enter"] then
				dispatch_symbol(v.gestures[key]);
			end
		end

-- profiles have an individual clock to for normal gestures
		if (v.tick) then
			v:tick();
		end

-- flush pending range values to keystore
		if v.range_dirty then
			v.range_dirty = false;
			touchm_evlog(fmt("device=%s:store_ranging=%.0f %.0f %.0f %.0f",
				v.name, v.range[1], v.range[2], v.range[3], v.range[4]));

			local name = "touch_" .. v.profile.name;
			local tbl = {};
			tbl[name .. "_range"] =
				string.format("%.0f:%.0f:%.0f:%.0f",
					v.range[1], v.range[2], v.range[3], v.range[4]
				);

			store_key(tbl);
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

local function get_classifier_set()
	local res = {};
	for k, v in pairs(classifiers) do
		table.insert(res, k);
	end
	table.sort(res)
	return res;
end

local function menu_for_device(dev)
 -- mt_eval, 0..n
 -- swipe_thresh 0.2
 -- drag_thresh
 -- autorange
 -- timeout
 -- idle_base
 -- motion_block
 -- warp_press
 -- touch_only
 -- activation bounds
 -- scale_x
 -- scale_y
 -- range
 -- gestures (should be populated by the classifier as well)
 -- zones (same problem as cursor regions actually)
 -- axis_remap
 -- button_remap
	return {
	{
		name = "cooldown",
		label = "Cooldown",
		kind = "value",
		description = "Period of silence (ticks) between discrete device actions",
		validator = gen_valid_num(1, 100),
		initial = tostring(dev.cooldown),
		handler = function(ctx, val)
			dev.cooldown = tonumber(val);
		end
	},
	{
		name = "swap_xy",
		label = "Swap Axis",
		kind = "value",
		description = "Swap the X and Y input axes",
		set = {LBL_YES, LBL_NO, LBL_FLIP},
		initial = dev.swap_xy and LBL_YES or LBL_NO,
		handler = function(ctx, val)
			if (val == LBL_FLIP) then
				dev.swap_xy = not dev.swap_xy;
			elseif (val == LBL_YES) then
				dev.swap_xy = true;
			else
				dev.swap_xy = false;
			end
		end
	},
	{
		name = "invert_x",
		label = "Invert X",
		kind = "value",
		description = "Invert X axis samples",
		set = {LBL_YES, LBL_NO, LBL_FLIP},
		initial = dev.invert_x and LBL_YES or LBL_NO,
		handler = function(ctx, val)
			if (val == LBL_FLIP) then
				dev.invert_x = not dev.invert_x;
			elseif (val == LBL_YES) then
				dev.invert_x = true;
			else
				dev.invert_x = false;
			end
		end
	},
	{
		name = "invert_y",
		label = "Invert Y",
		kind = "value",
		description = "Invert Y axis samples",
		set = {LBL_YES, LBL_NO, LBL_FLIP},
		initial = dev.invert_y and LBL_YES or LBL_NO,
		handler = function(ctx, val)
			if (val == LBL_FLIP) then
				dev.invert_y = not dev.invert_y;
			elseif (val == LBL_YES) then
				dev.invert_y = true;
			else
				dev.invert_y = false;
			end
		end
	},
	{
	name = "classifier",
	kind = "value",
	label = "Classifier",
	description = "Set the input analysis model used",
	set = get_classifier_set(),
	handler = function(ctx, val)
		apply_classifier(classifiers[val], dev.profile, dev);
	end
	}
	};
end

local function gen_touch_menu()
	local devlist = {};
	for k,v in pairs(devices) do
		v.devid = k;
		table.insert(devlist, v);
	end

	table.sort(devlist, function(a, b)
		return a.devid < b.devid;
	end);

	local res = {};
	for _,j in ipairs(devlist) do
		table.insert(res, {
			name = tostring(j.devid),
			label = j.label,
			kind = "action",
			submenu = true,
			handler = function()
				return menu_for_device(j);
			end
		});
	end

	return res;
end


menus_register("global", "input", {
	name = "touch",
	label = "Touch",
	description = "Touch, Trackpad and Pen- class device controls",
	kind = "action",
	eval = function()
		return #gen_touch_menu() > 0;
	end,
	submenu = true,
	handler = gen_touch_menu
});

touchm_reload();
timer_add_periodic("touch", 1, false, clock_fun, false);

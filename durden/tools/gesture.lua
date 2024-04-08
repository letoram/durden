local log, fmt = suppl_add_logfn("tools")

-- the recognizer is configured as handling orientation, no-1D and faster solver
local recognizer

gconfig_register("gesture_flash", true);
gconfig_register("gesture_cooldown", 20);
gconfig_register("gesture_timeout", 10);
gconfig_register("gesture_delta", 5);
gconfig_register("gesture_threshold", 1.0);
gconfig_register("gesture_samples", 60);
gconfig_register("gesture_color", "\\#00aa00");

local constants =
{
	cooldown = gconfig_get("gesture_cooldown"),
	min_samples = gconfig_get("gesture_samples"),
	score_threshold = gconfig_get("gesture_threshold"),
	min_delta = gconfig_get("gesture_delta"),
	timeout = gconfig_get("gesture_timeout"),
	flash = gconfig_get("gesture_flash"),
	px_sz = 10
}

local cfgmenu =
{
	{
		name = "color",
		label = "Color",
		description = "Background flash and drawing color"
	},
	{
		name = "flash",
		label = "Flash",
		description = "Flash screen when tracking triggers",
		kind = "value",
		initial = function()
			return constants.flash and LBL_YES or LBL_NO
		end,
		set = {LBL_YES, LBL_NO, LBL_FLIP},
		handler = suppl_flip_handler(
			"gesture_flash",
			function(active)
				constants.flash = active
			end
		)
	},
	{
		name = "cooldown",
		label = "Cooldown",
		description = "Delay between activation and tracking gesture",
		kind = "value",
		hint = "(0 .. 100)",
		initial = function()
			return constants.cooldown
		end,
		validator = gen_valid_num(0, 100, 10),
		handler = function(ctx, val)
			constants.cooldown = tonumber(val)
			gconfig_set("gesture_cooldown", constants.cooldown)
		end
	},
	{
		name = "samples",
		label = "Samples",
		description = "Minimum number of samples to collect",
		kind = "value",
		hitn = "(64 .. 200)",
		initial = function()
			return constants.min_samples
		end,
		validator = gen_valid_num(64, 200, 1),
		handler = function(ctx, val)
			constants.min_samples = tonumber(val)
			gconfig_set("gesture_samples", constants.min_samples)
		end,
	},
	{
		name = "timeout",
		label = "Timeout",
		description = "Number of ticks before gesture is considered or discarded",
		kind = "value",
		hint = "(10 .. 200)",
		initial = function()
			return constants.timeout
		end,
		validator = gen_valid_num(10, 200, 5),
		handler = function(ctx, val)
			constants.timeout = tonumber(val)
			gconfig_set("gesture_timeout", constants.timeout)
		end
	},
	{
		name = "score",
		label = "Score",
		description = "Minimal acceptible gesture match score to trigger",
		kind = "value",
		hint = "(0.3 .. 4.0)",
		initial = function()
			return constants.score_threshold
		end,
		validator = gen_valid_num(0.3, 4.0, 0.1),
		handler = function(ctx, val)
			constants.score_threshold = tonumber(val)
			gconfig_set("gesture_threshold", constants.score_threshold)
		end,

	},
	{
		name = "delta",
		label = "Delta",
		description = "Minimum pixel distance between samples",
		kind = "value",
		hint = "(5 .. 50)",
		initial = function()
			return constants.min_delta
		end,
		validator = gen_valid_num(5, 50, 1),
		handler = function(ctx, val)
			constants.delta = tonumber(val)
			gconfig_set("gesture_delta", constants.delta)
		end,
	}
}

local r, g, b = suppl_hexstr_to_rgb(gconfig_get("gesture_color"))
constants.color = {r, g, b}

suppl_append_color_menu(gconfig_get("gesture_color"), cfgmenu[1],
function(str, r, g, b)
	gconfig_set("gesture_color", str)
	constants.color = {r, g, b}
end
)

-- populate the recognizer

local gm -- mouse handler
local vids = {} -- track drawing trail
local overlay -- capture surface
local samples -- classify/trainer state

local function flush_gestures()
	local set = match_keys("gesture_%") or {}
	local outkeys = {}

	for i,v in ipairs(set) do
		local key, val = string.split_first(v, "=")
		outkeys[key] = ""
	end

	store_key(outkeys)
end

local function load_gestures()
	recognizer = system_load("tools/gesture/gestures.lua")()(true, false, true)
	local set = match_keys("gesture_%") or {}

-- format is gesture_index=name\tx y x y x y then downscale * 0.01
-- then gesture_index_name=/path
	for _,v in ipairs(set) do
		local key, val = string.split_first(v, "=")
		local name, pts = string.split_first(val, "\t")
		local coords = string.split(pts, " ")
		if #coords % 2 ~= 0 or #coords == 0 or #name == 0 then
			log(fmt("tool=gesture:kind=error:bad_gesture=%s:coord=%d", name, #coords))
		else
			for i=1,#coords do
				coords[i] = tonumber(coords[i]) * 0.01
			end
			log(fmt("tool=gesture:kind=added:name=%s", name))
			recognizer.add(name, coords)
		end
	end
end

load_gestures()

local function done(ok)
	local run

-- apply train to path or run gesture
	if ok then
		if samples.training then
			local num = recognizer.add(samples.training, samples)
			log(fmt("tool=gesture:kind=added:total=%d:path=%s", num, samples.training))
			store_key(recognizer.serialize(samples.training))
		else
			local name, score, _ = recognizer.recognize(samples)
			log(fmt("tool=gesture:score=%.3f:path=%s", score, name))
			if score > constants.score_threshold then
				run = name
			end
		end
	end

	vids = {}
	samples = {}

	log("tool=gesture:kind=status:over")
-- release all the input controls
	mouse_droplistener(gm)
	durden_input_sethandler(nil, "gesture_handler")
	delete_image(overlay)
	dispatch_symbol_unlock()
	timer_delete("gesture_tick")

	if run then
		dispatch_symbol(run)
	end
end

gm =
{
	name = "mouse_gesture",
	own = function()
		return true
	end,
-- reset
	rclick = function()
		if samples.training then
			for i,v in ipairs(vids) do
				delete_image(v)
			end
			vids = {}
		end
		samples = {
			training = samples.training,
			last_sample = CLOCK,
			cooldown = constants.cooldown
		}
	end,
	click = function()
		done(#samples < constants.min_samples)
	end,
	motion = function()
		if samples.cooldown > 0 then
			return
		end
		local x, y = mouse_xy()

		local sample = samples[#samples]
		local ok_delta = not sample or
			math.abs(sample[1] - x) > constants.min_delta or
			math.abs(sample[2] - y) > constants.min_delta

		if not ok_delta then
			return
		end

-- visual marker, modify here to get more flair
		local px_sz = constants.px_sz
		local new = color_surface(px_sz, px_sz, unpack(constants.color))
		link_image(new, overlay)
		image_inherit_order(new, true)
		show_image(new)
		move_image(new, x - (0.5 * px_sz), y - (0.5 * px_sz))
		image_mask_set(new, MASK_UNPICKABLE)
		table.insert(vids, new)
		samples.last_sample = CLOCK,
-- x, y, vid, norm_x, norm_y
		table.insert(samples, {x, y})
	end
}

local function on_gesture_tick()
-- send a flash as a reaction trigger
	if samples.cooldown > 0 then
		samples.cooldown = samples.cooldown - 1
		if samples.cooldown == 2 and constants.flash then
			log("tool=gesture:kind=status:cooldown_flash")
			local flash =
				fill_surface(
					active_display().width,
					active_display().height,
					unpack(constants.color)
				)
			order_image(flash, 65531)
			blend_image(flash, 1.0, 1)
			blend_image(flash, 0.0, 1)
			expire_image(flash, 3)
		end
		return
	end

	if CLOCK - samples.last_sample < constants.timeout then
		return
	end

	log("tool=gesture:kind=status:idle_trigger")
-- idle but not enough samples, reset and try again
	if #samples < constants.min_samples then
		for i,v in ipairs(vids) do
			delete_image(v)
		end
		vids = {}
		samples = {
			cooldown = 2,
			training = samples.training,
			last_sample = CLOCK
		}
		log("tool=gesture:kind=status:reset_retry")
	else
		done(true)
	end
end

local function gesture_handler(iotbl, fromim)
	if iotbl.kind == "status" then
		durden_iostatus_handler(iotbl)
		return
	end

	if not fromim then
		if iostatem_input(iotbl) then
			return
		end
	end

	if iotbl.translated and iotbl.active then
		local sym, lutsym = SYMTABLE:patch(iotbl)
		if SYSTEM_KEYS["cancel"] == sym then
			gm.click()
			return
		end
	end

	mouse_iotbl_input(iotbl)
end

local function draw_gesture(path)
-- build draw_anchor (invisible)

-- grab mouse by creating a capture mouse surface, blocking dispatch from interfering
-- and register a new input handler so that we can capture escape button presses
	local wm = active_display()
	overlay = null_surface(wm.width, wm.height)
	order_image(overlay, 65530)
	show_image(overlay)
	iostatem_save()
	dispatch_meta_reset()
	dispatch_symbol_lock()
	durden_input_sethandler(gesture_handler, "draw_gesture")
	mouse_addlistener(gm)

	samples = {
		training = path,
		cooldown = constants.cooldown,
		last_sample = CLOCK
	}

-- attach timer that will be used to drive the datapoint sampling
	timer_add_periodic("gesture_tick", 1, false, on_gesture_tick, function() end, true)
end

local gesture_menu =
{
	{
		name = "draw",
		kind = "action",
		label = "Draw",
		description = "Draw a gesture and trigger any trained action",
		eval = function()
			return #recognizer.templates > 0
		end,
		handler = function()
			draw_gesture()
		end,
	},
	{
		label = "Forget",
		name = "forget",
		kind = "value",
		description = "Remove a previously trained gesture by action",
		eval = function()
			return #recognizer.templates > 0
		end,
		set = function()
			local ret = {}
			for i=1,#recognizer.templates do
				table.insert(ret, recognizer.templates[i].name)
			end
			return ret;
		end,
		handler = function(ctx, val)
			recognizer.remove(val)
			flush_gestures()
			store_key(recognizer.serialize())
		end
	},
	{
		name = "train",
		kind = "action",
		label = "Train",
		description = "Pick an action path and then draw the intended gesture",
		handler = function()
			dispatch_symbol_bind(function(path)
				draw_gesture(path)
			end)
		end
	}
}

menus_register("global", "input/mouse", {
	name = "gesture",
	kind = "action",
	label = "Train",
	submenu = true,
	handler = gesture_menu,
	label = "Gesture",
	description = "Use cursor or touch motion complex gestures to trigger actions"
})

menus_register("global", "input/mouse/gesture", {
	name = "tune",
	label = "Tune",
	kind = "action",
	submenu = true,
	description = "Adjust gesture tool look and feel",
	handler = cfgmenu
})

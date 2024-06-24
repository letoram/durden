local log, fmt = suppl_add_logfn("tools")

local delays =
{
	instant = 1, -- special case, still use the timer for the initial delay
	fastest = 1,
	fast = 2,
	medium = 8,
	slow = 20,
}

local oracle =
{
	broken = false,
	vid = BADID,
	last_word = "",

-- a prefix tree would be a decent optimisation here to reduce amount of decode RTs
	current_set = {},
	pending_set = {}
}

gconfig_register("typer_model", "instant")
gconfig_register("typer_oracle", "spell")
gconfig_register("typer_language", "en_GB")

local config =
{
	type_model = gconfig_get("typer_model"),
	oracle = gconfig_get("typer_oracle"),
	language = gconfig_get("typer_language")
}

local function launch_oracle()
	oracle.vid =
	launch_avfeed("proto=spell", "decode",
	function(source, status)
		if status.kind == "terminated" then
			oracle.broken = true
			log("typer:oracle_terminated")
			delete_image(oracle.vid)

		elseif status.kind == "message" then
-- the special thing here is that we need to trigger lbar re-evaluation of set,
-- the 'easiest' hack for that is injecting a null key
			table.insert(oracle.pending_set, status.message)

		elseif status.kind == "frame" then
			oracle.current_set = oracle.pending_set
			oracle.pending_set = {}
			local ictx = active_display().input_ctx
			if ictx then
				ictx.inp:input({active = true, utf8 = ''}, "NONE", true, {})
			end
		end
	end
	)
	if not valid_vid(oracle.vid) then
		oracle.broken = true
		log("typer:error=couldn't spawn oracle")
	else
		target_flags(oracle.vid, TARGET_BLOCKADOPT) -- get frame delivery
		target_flags(oracle.vid, TARGET_VERBOSE) -- get frame delivery
		target_flags(oracle.vid, TARGET_DRAINQUEUE) -- process immediately
	end
end

local function synch_oracle(val)
	local set = string.split(val, " ")
	val = set[#set]

	if config.oracle == "spell" and not oracle.broken then
		if not valid_vid(oracle.vid) then
			launch_oracle()
		end

-- single character suggestions aren't exactly useful
		if #val <= 1 then
			return {}
		elseif valid_vid(oracle.vid) then
			if oracle.last_word ~= val then
				oracle.current_set = {}
				oracle.last_word = val
				target_input(oracle.vid, val)
			end
		end

		return oracle.current_set, oracle.last_word
	end
	return {}
end

-- The problem with this is that we have the godforsaken xkb format to deal with
-- for wayland and x11 clients still. This should be isolated to arcan-wayland
-- and Xarcan so that they can chose between whatever vxiv_text_input_protocol_
-- we_will_surely_get_it_right_this_time or whatever client pretends to
-- implement then either walk the current XKB map in reverse to find the
-- production syms or say fsck it and just .. dynamically generate / build a
-- keymap based on the symbols you use and punish asian languages for the 5-10k
-- invalidations seeding the thing. That or create a fake XIM which still
-- doesn't solve for Wayland being worst in class.
local function string_to_keyboard(str, kbd)
	local res = {}

	for i=1,#str do
		local ch = string.sub(str, i, i)
		local sub = string.byte(ch)
		local tbl = {
			kind = "digital",
			translated = true,
			digital = true,
			active = true,
			utf8 = ch,
			devid = 0,
			subid = sub,
			keysym = sub,
			modifiers = 0,
			number = sub
		}
		table.insert(res, tbl)
		local copy = {}
		for k,v in pairs(tbl) do
			copy[k] = v
		end

		copy.active = false
		copy.utf8 = ""
		table.insert(res, copy)
	end

	return res
end

local function queue_input(wnd)
	local function run_key()
		local input = table.remove(wnd.type_input_queue[1], 1)
		target_input(wnd.external, input)
		input = table.remove(wnd.type_input_queue[1], 1)
		target_input(wnd.external, input)

		if #wnd.type_input_queue[1] == 0 then
			table.remove(wnd.type_input_queue, 1)
		end

		return #wnd.type_input_queue > 0
	end

	local tname = wnd.name .. "_type"
	timer_add_periodic(tname, delays[config.type_model], false,
		function()
			if not valid_vid(wnd.external, TYPE_FRAMESERVER) then
				timer_delete(tname)
			end

			if config.type_model == "instant" then
				while run_key() do
				end
				timer_delete(tname)
			elseif not run_key() then
				timer_delete(tname)
			end
		end,
		true
	)
end

local function type_input(ctx, val)
	local wnd = active_display().selected
	if not wnd.type_input_queue then
		wnd.type_input_queue = {string_to_keyboard(val, SYMTABLE)}
		queue_input(wnd, val)
	else
		table.insert(wnd.type_input_queue, string_to_keyboard(val, SYMTABLE))
	end
end

local input_menu =
{
	{
		name = "input",
		label = "Input",
		description = "Query for a text string to send to the window",
		kind = "value",
		eval = function()
			return valid_vid(active_display().selected.external)
		end,
		helpsel = synch_oracle,
		validator = function(src)
			return #src > 0
		end,
		handler = type_input
	},
	{
		name = "model",
		label = "Model",
		kind = "value",
		initial = function() return config.type_model; end,
		description = "Control the pattern between input events being delivered",
		set = {"instant", "fastest", "fast", "medium", "slow"},
		handler = function(ctx, val)
			config.type_model = val
			gconfig_set("typer_model", val)
		end
	},
	{
		name = "oracle",
		label = "Oracle",
		kind = "value",
		description = "Set the oracle used for generating suggestions",
		initial = function() return config.oracle; end,
		set = {"none", "spell"},
		handler = function(ctx, val)
			config.oracle = val
			oracle.broken = false
			if valid_vid(oracle.vid) then
				delete_image(oracle.vid)
			end
			gconfig_set("typer_oracle", val)
		end
	}
}

menus_register("target", "input", {
	label = "Text",
	name = "text",
	description = "Type buffered input with language and typing model support",
	kind = "action",
	submenu = true,
	handler = input_menu
})

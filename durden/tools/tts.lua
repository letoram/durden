local voices = {}; -- set of active (vid ~= BADID) / configured voices
local n_voices = 0;

local map_cache = {};
local scan_voices = {}; -- set of known voice styles
local log, fmt = suppl_add_logfn("tools");

local function rescan()
	scan_voices = {};
	launch_avfeed("protocol=t2s:list", "decode",
	function(source, status)
		if status.kind == "terminated" then
			delete_image(source);
		elseif status.kind == "message" then
			local set = string.split(status.message, '=');
			if set and set[2] and #set[2] > 0 then
				table.insert(scan_voices, set[2]);
			end
		end
	end)
end

local function verify_add(res)
-- make sure the required fields are there, warn on missing ones,
-- find suitable decode voice
	table.insert(map_cache, res)
end

local function list_devmaps(rescan)
	if rescan then
		map_cache = glob_resource("devmaps/tts/*.lua", APPL_RESOURCE);
		for i=#map_cache, 1 do
			if string.sub(map_cache[i], -4) ~= ".lua" or #map_cache[i] == 4 then
				table.remove(map_cache, 1)
			else
				local res = suppl_script_load("devmaps/tts/" .. map_cache[i], log)
				if res then
					verify_add(res)
				end
			end
		end
	end
	return map_cache;
end

rescan();
list_devmaps(true);

local function send_label(vid, lbl)
	target_input(vid,
		{kind = "digital", label = lbl, active = true, devid = 0, subid = 0})
end

local function speak_message(voice, msg)
	voice.last_message = msg
	target_input(voice.vid, msg)
end

local function drop_voice(name)
	if not voices[name] then
		return
	end

	if valid_vid(voices[name].vid) then
		delete_image(voices[name].vid)
	end

	for _, v in ipairs(voices[name].cleanup) do
		v()
	end

	voices[name] = nil
	log(fmt("tts:kind=dead:name=%s", name))
	n_voices = n_voices - 1
end

local function voice_select(voice, action)
	local wm = active_display()
	local map = voice.map

-- can get multiple repeats of the same select on some transitions so only send if
-- something has actually changed
	voice.wnd_select = function(wm, wnd)
		local value = string.trim(wnd[action[2]])
		if #value == 0 then
			return
		end
		local msg = string.format("wnd %s %s", action[1], value)
		if voice.last_select ~= msg then
			voice.last_select = msg
			voice:message(msg)
		end
	end

	table.insert(wm.on_wnd_select, voice.wnd_select)
	table.insert(voice.cleanup,
	function() table.remove_match(wm.on_wnd_select, voice.wnd_select) end)
end

local function voice_clipboard(voice, action)
	local map = voice.map

	voice.clipboard =
	function(msg, src)
		if msg == voice.last_msg then
			return
		end
		voice.last_msg = msg

-- avoid bad x11 clients setting selection on every _motion event
-- (chrome) and wait until it is released, since we don't have a
-- global listener for this, use a timer
		if mouse_state().btns[1] then
			voice.deferred = msg
			return
		end

		voice:message(string.format("%s set %s", action, msg))
	end

	table.insert(voice.cleanup,
	function()
		CLIPBOARD:del_monitor(voice.clipboard)
	end)
	CLIPBOARD:add_monitor(voice.clipboard)
end

local function voice_clipboard_paste(voice, action)
	local map = voice.map

	voice.clipboard_paste =
	function(msg, fail)
		if fail then
			voice:message(string.format("%s couldn't paste", action))
		else
			voice:message(string.format("%s paste %s", action, msg))
		end
	end
	table.insert(voice.cleanup, function()
		CLIPBOARD:del_monitor(voice.clipboard_paste)
	end)
	CLIPBOARD:add_monitor(voice.clipboard_paste, true)
end

local tiler_lbar_hook
local tiler_lbar_orig
local function voice_menu(voice, action)
	if tiler_lbar_orig then
		log(fmt("tts:kind=warning:name=%s:reason=only one voice for menu", voice.name))
		return
	end

-- Several complexities here, we need to hook the input context and
-- provide additional controls for repeating the current input, for
-- hooking the cursor state, for speaking the full path and so on.
--
-- Each display assigns tiler_lbar to the lbar member of wm
	local hook =
	function(...)
		local bar = tiler_lbar(...)
			local cp = menu_get_current_path()
			local set = string.split(cp, "/")
			voice:message(set[#set])

-- get input string and input prefix
		bar.custom_bindings["lctrl_t"] =
			function(ictx)
				local str = ictx.inp:view_str()
				if #str == 0 then
					voice:message("empty prompt")
				else
					voice:message("prompt " .. str)
					local caret = ictx.inp:caret_str()
					if caret ~= str then
						voice:message("before " .. caret)
					end
				end
			end

		bar.custom_bindings["rctrl_t"] = bar.custom_bindings["lctrl_t"]
		bar.custom_bindings["lctrl_h"] =
		function(ictx)
			if ictx.last_helper then
				voice:message(ictx.last_helper)
			else
				voice:message("no description")
			end
		end
		bar.custom_bindings["rctrl_h"] = bar.custom_bindings["lctrl_h"]

-- get current full path
		bar.custom_bindings["lctrl_p"] =
			function(ictx)
				voice:message(action .. menu_get_current_path())
			end

-- hook stepping the currently selected items
		local old_step = bar.on_step
		local lastmsg = ""
		bar.on_step =
			function(lbar, i, key, anchor, ofs, w, mh)
				old_step(lbar, i, key, anchor, ofs, w, mh)
				if key and key ~= lastmsg and key ~= ".." then
					reset_target(voice.vid)
					voice:message(key)
					lastmsg = key
				end
		end

		return bar
	end

	for d in all_tilers_iter() do
		d.lbar = hook
	end

	table.insert(voice.cleanup,
	function()
		for d in all_tilers_iter() do
			d.lbar = tiler_lbar
		end
	end)
end

local function voice_notification(voice, arg)
-- the only special things here is possibly to remember window sources for
-- notifications and providing a binding to jump to the last source window
end

local function voice_accessibility(voice, arg)
-- this is for windows that can handle / provide an accessibility
-- segment and we can access / step its contexts through tui functions,
-- since the vstore type in arcan for that is incomplete this is just
-- notes and a placeholder.
end

-- actual implementations of all possible actions in the voice map
-- extend here with features that requires deeper hooks into durden.
--
-- the other place for extension is the voice menu further below for
-- things that resolve to simpler menu path actions
local actions = {
["select"] = voice_select,
["clipboard"] = voice_clipboard,
["clipboard_paste"] = voice_clipboard_paste,
["menu"] = voice_menu
}

local function load_voice(name)
	if voices[name] then
		log(fmt("tts:kind=status:error=exists:name=%s", name))
		return
	end

	local maps = list_devmaps(false)

	for k,v in pairs(map_cache) do
		if v.name == name then
			map = v
			break
		end
	end

	if not map then
		log(fmt("tts:kind=status:error=missing:name=%s", name))
		return
	end

-- ensure that the loaded profile has the expected values or fill out
-- defaults and convert into t2s protocol arguments
	local voice = {
		profile = map,
		name = name,
		message = speak_message,
		labels = {},
		cleanup = {},
		tick = {}
	}

	local argstr =
	string.format(
		"protocol=t2s:channel=%s:voice=%s:" ..
		"rate=%.0f:pitch=%.0f:range=%.0f:gap=%.0f:punct=%d",
		map.channel,
		map.model,
		map.rate,
		map.pitch,
		map.range,
		map.gap,
		map.punct
	)

	table.insert(voice.cleanup,
	function()
		if voice.key_echo then
			dispatch_symhook(voice.key_echo)
		end
	end)

	if map.cappitch then
		argstr = argstr .. ":cappitch=" .. tostring(map.cappitch)
	elseif map.capmode then
		argstr = argstr .. ":capmode=" .. map.capmode
	end

-- some actions need a timer for polling and for speech queue management
	voice.timer =
	function()
		if voice.deferred then
			if mouse_state().btns[1] then
				return
			end
			voice.last_msg = nil
			voice.clipboard(voice.deferred, "")
			voice.deferred = nil
		end

		for i=#voice.tick,1,-1 do
			voice.tick[i](voice)
		end
	end

	timer_add_periodic("tts_timer_" .. tostring(CLOCK), 25, false, voice.timer, true)
	table.insert(voice.cleanup, function() timer_delete_trigger(voice.timer) end)

	dispatch_bindings_overlay(map.bindings, true)
	table.insert(voice.cleanup,
		function() dispatch_bindings_overlay(map.bindings, false) end)

-- now apply the actual action table
	for k, v in pairs(map.actions) do
		if actions[k] then
			actions[k](voice, v)
		else
			log(fmt("tts:kind=warning:voice=%s:missing_action=%s", voice.name, k))
		end
	end

	log(fmt("tts:kind=status:activate=%s:%s", name, argstr))

-- actually setup the profile itself
	voice.vid, voice.aid =
	launch_avfeed(argstr, "decode",
		function(source, status)
			if status.kind == "terminated" then
				delete_image(source)
				drop_voice(name)

-- need to latch the voice message to after the preroll is over
			elseif status.kind == "preroll" then
				voice.active = true
				timer_add_periodic("t2s_start", 1, true, function()
					if valid_vid(source) then
						target_input(source, "the voice" .. name .. " activated")
					end
				end)

			elseif status.kind == "input_label" then
				table.insert(voice.labels, status.labelhint)
			end
		end
	)

	voices[name] = voice
	n_voices = n_voices + 1

-- if that couldn't be spawned for any reason, re-use the regular close handler
-- so all the cleanup handlers are invoked correctly with the right data
	if not valid_vid(voice.vid) then
		log(fmt("tts:kind=error:process_failed"))
		drop_voice(voice)
		return
	end

	target_flags(voice.vid, TARGET_BLOCKADOPT)
	audio_gain(voice.aid, map.gain)
end

local function get_voice_opts(v)
	local ent = {};

-- flush/cancel
	table.insert(ent,
	{
		name = "flush",
		kind = "action",
		label = "Flush",
		description = "Cancel / flush current queue",
		handler = function()
			reset_target(v.vid);
		end,
	});

	table.insert(ent,
	{
		name = "speak",
		label = "Speak",
		description = "Speak a custom text message",
		kind = "value",
		handler = function(ctx, val)
			if not val or #val == 0 then
				return
			end
			v:message(val)
		end
	});

	table.insert(ent,
	{
		name = "destroy",
		label = "Destroy",
		kind = "action",
		description = "Destroy the voice and cancel all pending text",
		handler = function()
			drop_voice(v.name)
		end,
	});

	table.insert(ent,
	{
		name = "gain",
		label = "Gain",
		kind = "value",
		validator = gen_valid_num(0, 1),
		description = "Change the current audio mixing gain",
		handler = function(ctx, val)
			audio_gain(v.aid, tonumber(val));
		end,
	});

	table.insert(ent,
	{
		name = "slow_replay",
		label = "Slow Replay",
		kind = "action",
		description = "Set synthesis speed to slow, replay last message then revert speed",
		handler = function()
			if v.last_message then
				send_label(v.vid, "SLOW");
				target_input(v.vid, v.last_message);
				target_input(v.vid, "SETRATE");
			end
		end
	});

	table.insert(ent,
	{
		name = "toggle_key_echo",
		label = "Toggle Echo",
		kind = "action",
		handler = function()
			if v.key_echo then
				dispatch_symhook(v.key_echo, true)
				v.key_echo = nil
				target_input(v.vid, "key echo off")
			else
				v.key_echo = function(io)
					target_input(v.vid, io)
				end
				dispatch_symhook(v.key_echo)
				target_input(v.vid, "key echo on")
			end
		end
	})

-- any dynamic input labels from the speech service
	for _, lbl in ipairs(v.labels) do
		table.insert(ent,
			{
				name = "input_" .. string.lower(lbl),
				kind = "action",
				description = "forward input to speech service",
				label = lbl,
				handler = function()
					send_label(v.vid, lbl)
				end
			}
		)
	end

	return ent;
end

local function gen_voice_menu()
	local res = {};
	local names = {};

	for i, v in pairs(voices) do
		table.insert(names, v.name);
	end

	table.sort(names);
	for i, v in ipairs(names) do
		local voice = voices[v];
		table.insert(res, {
			name = v,
			kind = "action",
			description = "Control or modify the voice",
			label = v,
			submenu = true,
			handler = function()
				return get_voice_opts(voice);
			end
		});
	end

	return res;
end

menus_register("global", "tools", {
	name = "tts",
	label = "Text To Speech (TTS)",
	kind = "action",
	submenu = true,
	handler = {
	{
		name = "rescan",
		label = "Rescan",
		description = "Scan for voice models",
		kind = "action",
		handler = rescan
	},
	{
		name = "voices",
		label = "Voices",
		kind = "action",
		submenu = true,
		eval = function()
			return n_voices > 0;
		end,
		handler = function()
			return gen_voice_menu()
		end
	},
	{
		name = "open",
		label = "Open",
		description = "Open and activate a voice device map",
		kind = "value",
		eval = function()
			return #map_cache > 0
		end,
		set = function()
			local set = {}
			for i,v in ipairs(map_cache) do
				table.insert(set, v.name)
			end
			table.sort(set)
			return set
		end,
		handler = function(ctx, val)
			load_voice(val)
		end
	}
	}});

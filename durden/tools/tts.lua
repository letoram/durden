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

-- ensure that the loaded profile has the expected values or fill out defaults
-- and convert into t2s protocol arguments

	local voice = {
		profile = map,
		name = name,
		cleanup = {}
	}

-- punct = 0,1,2
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

	if map.cappitch then
		argstr = argstr .. ":cappitch=" .. tostring(map.cappitch)
	elseif map.capmode then
		argstr = argstr .. ":capmode=" .. map.capmode
	end

	if map.actions.clipboard then
		voice.clipboard = function(msg, src)
			target_input(voice.vid,
				string.format("%s set %s", map.actions.clipboard, msg))
		end

		table.insert(voice.cleanup, function()
			CLIPBOARD:del_monitor(voice.clipboard)
		end)

		CLIPBOARD:add_monitor(voice.clipboard)
	end

	if map.actions.clipboard_paste then
		voice.clipboard_paste =
		function(msg, fail)
			if fail then
				target_input(voice.vid,
					string.format("%s couldn't paste", map.actions.clipboard_paste))
			else
				target_input(voice.vid,
					string.format("%s paste %s", map.actions.clipboard_paste, msg))
			end
		end
		table.insert(voice.cleanup, function()
			CLIPBOARD:del_monitor(voice.clipboard_paste)
		end)
		CLIPBOARD:add_monitor(voice.clipboard_paste, true)
	end

	log(fmt("tts:kind=status:activate=%s:%s", name, argstr))

-- should convert profile into voice
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
			elseif status.kind == "labelhint" then
				table.insert(voice.labels, status.labelhint)
			end
		end
	)

	if not valid_vid(voice.vid) then
		log(fmt("tts:kind=error:process_failed"))
		return
	end

	voices[name] = voice
	n_voices = n_voices + 1
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
		label = "Reset",
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
			target_input(v.vid, val);
		end
	});
	table.insert(ent,
	{
		name = "destroy",
		label = "Destroy",
		kind = "action",
		description = "Destroy the voice and cancel all pending text",
		handler = function()
			delete_image(v.vid);
			table.remove_match(voices, v);
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

	return ent;
end

local function get_cfg_opts(v)
	local ent = {};

-- some of these could be dynamically configurated with the
-- coreopt arguments, and we should have a generalized coreopt
-- to menu anyhow so we can just bind that as the event handler
-- and attach...
--
-- channel l,r
-- rate (wpm)
-- pitch (50)
-- range (100)
-- gap (10)

	table.insert(ent,
		{
			name = "model",
			kind = "value",
			set = scan_voices,
			label = "Model",
			description = "Pick language/sound model for the voice",
			handler = function(ctx, val)
				v.voice = val;
			end,
		}
	);
	table.insert(ent,
		{
			name = "activate",
			kind = "action",
			label = "Activate",
			description = "Bind the current configuration to a voice synthesizer",
			handler =
			function()
				activate_voice(v);
			end,
		}
	);

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
			name = "voice_" .. v,
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

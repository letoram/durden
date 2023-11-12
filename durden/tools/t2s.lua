local voices = {}; -- set of active (vid ~= BADID) / configured voices
local scan_voices = {}; -- set of known voice styles

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

rescan();

local function load_voices(name)
end

local function save_voices(name)
end

load_voices("default");

local function activate_voice(v)
	if valid_vid(v.vid) then
		return;
	end

-- convert settings into argument string
	v.vid, v.aid =
		launch_avfeed("protocol=t2s", "decode",
			function(source, status)
			end
		)
end

local function get_live_opts(v)
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
		description = "Speak a custom phonetic text message",
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

-- request accessibility option
	if active_display().selected then
	end

-- need to probe if we can access tui text storage

-- dynamic window options:
-- speak row, word at cursor, home to cursor, cursor to end
-- popup options
-- speak visual contents around mouse-cursor
-- mouse-cursor sounds when crossing barriers?
--
-- notifications=on/off
-- keyboard_echo=on/off
-- wm_key_echo=on/off
-- (encode path length?, dynamic speed based on queue length?)
-- shortcut_dispatch=on/off
-- on_window_enter=descr
-- menu=on/off
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
	for i, v in ipairs(voices) do
		table.insert(res, {
			name = "voice_ " .. tostring(i),
			kind = "action",
			label = tostring(i),
			submenu = true,
			handler = function()
				if valid_vid(v.vid) then
					return get_live_opts(v);
				else
					return get_cfg_opts(v);
				end
			end
		});
	end
	if #res > 0 then
		table.insert(res,
		{
			name = "reset",
			kind = "action",
			label = "Reset",
			description = "Remove all active or configured voices",
			handler =
			function()
				for _,v in ipairs(voices) do
					if valid_vid(v.vid) then
						delete_image(v.vid);
					end
				end
				voices = {};
			end
		});
		table.insert(res,
		{
			name = "save",
			kind = "value",
			label = "Save",
			description = "Save all active voices and their configuration",
			validator = suppl_valid_name,
			handler =
			function(ctx, val)
				save_voices(val);
			end
		});
	end
-- glob to get set to load
--
	return res;
end

menus_register("global", "tools", {
	name = "t2s",
	label = "Text To Speech (T2S)",
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
		name =  "add",
		label = "New Voice",
		description = "Create a new instance of a voice",
		kind = "action",
		eval = function()
			return #scan_voices > 0;
		end,
		handler = function()
			table.insert(voices, {
				active = false,
				rate = 150,
				pitch = 50,
				range = 100,
				gap = 10,
				channel = "lr",
			});
		end,
	},
	{
		name = "voices",
		label = "Voices",
		description = "Configure and control voices",
		kind = "action",
		dyn_eval = function()
			return #voices > 0;
		end,
		submenu = true,
		handler = gen_voice_menu
	}
	}});

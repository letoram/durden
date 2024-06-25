local voices = {}; -- set of active (vid ~= BADID) / configured voices
local n_voices = 0;

local map_cache = {};
local scan_voices = {}; -- set of known voice styles
local log, fmt = suppl_add_logfn("tools");
local tts_in_echo;

local labels =
{
	no_wnd = "no window selected",
	no_tui = "window is pixel based",
	empty_prompt = "empty prompt",
	prompt = "prompt",
	help = "help",
	no_description = "no description",
	speak = "speak",
	echo_fail = "echo fail",
	echo_fail_long = "key echo held by other active voice",
	no_changes = "nothing changed",
	at_top = "current row at top",
	at_bottom = "current row at bottom",
	current_row = "row %d "
}

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

local notes = {}
local function build_note_lut()
	local a4 = 440
	local names = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
	for i=12,131 do
		local vreq = a4 * 2^((i-69)-12)
		local oct = math.floor(i/12)-1
		local ind = i%12+1
		local name = names[ind] .. tostring(oct)
		notes[name] = freq
	end
end
build_note_lut()

local function build_sine(freq, length)
	local step = 2 * math.pi * freq / 48000.0
	local samples = length * 48000.0
	local res = {}
	local val = 0

	for i=1,samples,2 do
		res[i] = math.sin(val)
		res[i+1] = res[i]
		val = val + step
	end

	return res
end

local function play_tone(note, offset, length, waveform)
-- generate the sample buffer
-- create an aid, hook the end of playback to destroy
end

local function verify_add(res, fn)
-- missing:
-- make sure the required fields are there, warn on missing ones,
-- find suitable decode voice
	for i,e in ipairs(map_cache) do
		if e.file == fn then
			map_cache[i] = res
			return
		end
	end

	table.insert(map_cache, res)
end

local function list_devmaps(rescan)
	if not rescan then
		return map_cache
	end

	local files = glob_resource("devmaps/tts/*.lua", APPL_RESOURCE);
	for i,v in ipairs(map_cache) do
		v.mark = true
	end

	for _,v in ipairs(files) do
		if string.sub(v, -4) == ".lua" and #v > 4 then
			local found

			local res = suppl_script_load("devmaps/tts/" .. v, log)
			if res then
				res.file = v
				log("tts:new_profile=" .. v)
				verify_add(res, v)
			else
				log("tts:load_error=" .. v)
			end
		end
	end

	for i=#map_cache, 1 do
		if v.mark then
			table.remove(map_cache, i)
		end
	end
end

rescan();
list_devmaps(true);

local function send_label(vid, lbl)
	target_input(vid,
		{kind = "digital", label = lbl, active = true, devid = 0, subid = 0})
end

local function speak_message(voice, prefix, msg, reset)
	msg = string.trim(tostring(msg))

-- apply substitution patterns
	if voice.profile.replace then
		for k,v in ipairs(voice.profile.replace) do
			msg = string.gsub(msg, v[1], v[2])
		end
	end

-- ignore empty string
	if #msg == 0 then
		return
	end

-- don't repeat ourselves
	if voice.last_message == msg then
		return
	end

	voice.last_message = tostring(msg)

-- speak if the voice isn't dead, flush before if desired
	if valid_vid(voice.vid) then
		if reset then
			reset_target(voice.vid)
		end
		target_input(voice.vid, prefix .. msg)
	end
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
		if wnd ~= wm.selected then
			return
		end

		local value = string.trim(wnd[action[3]])
		if #value == 0 then
-- don't speak empty title
			voice:message(action[1], "empty", true)
--voice:message(string.format("wnd %s", action[2], wnd.atype or ""))
			return
		end

		local msg = value
		if voice.last_select ~= msg then
			voice.last_select = msg
			voice:message(string.format("%s %s", action[1], action[2]), msg, true)
		end
	end

	table.insert(wm.on_wnd_select, voice.wnd_select)
	table.insert(wm.on_wnd_title, voice.wnd_select)

	table.insert(voice.cleanup,
	function()
		table.remove_match(wm.on_wnd_select, voice.wnd_select)
		table.remove_match(wm.on_wnd_title, voice.wnd_select)
	end)
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

		voice:message(action, msg)
	end

	table.insert(voice.cleanup,
	function()
		CLIPBOARD:del_monitor(voice.clipboard)
	end)
	CLIPBOARD:add_monitor(voice.clipboard)
end

local function build_a11y_handler(voice, wm)
	return
	{
		request = function(wm, wnd, source, ev)
			if wnd.a11y and valid_vid(wnd.a11y.vid, TYPE_FRAMESERVER) then
				delete_image(wnd.a11y.vid)
			end

			wnd.a11y = {
				vid =
				accept_target(32, 32,
					function(source, status)
						if status.kind == "resized" then
							show_image(source)
							resize_image(source, status.width, status.height)

						elseif status.kind == "content_state" then
							target_displayhint(source, status.max_w, status.max_h)
-- acknowledge desired dimensions

						elseif status.kind == "message" then
-- out-of-band speak
							voice:message("message ", status.message)

						elseif status.kind == "alert" then
-- notification that something happened that is kept outside the normal
							voice:message("alert ", status.message)

						elseif status.kind == "frame" then
-- now we can sweep and speak the part of the window that has changed
-- through access_image_storage as the backing is tui

						elseif status.kind == "terminated" then
							delete_image(source)
							wnd.a11y = nil
						end
					end
				)
		}

		image_inherit_order(wnd.a11y.vid, true)
		suppl_tgt_color(wnd.a11y.vid, gconfig_get("tui_colorscheme"))
		link_image(wnd.a11y.vid, wnd.canvas, ANCHOR_LL)
		target_flags(wnd.a11y.vid, TARGET_BLOCKADOPT)
		return a11y_handler
	end,
	destroy = function()
		wm.a11y_handler = nil
	end
	}
end

local function voice_cursor(voice, action)
	voice.cursor_hook =
	function(vid, x, y, label)
		if voice.last_cursor == label or #label == 0 then
			return
		end
		voice.last_cursor = label
		voice:message(action, label, true)
	end

	if voice.cursor then
-- hook timer for generating beep, calcregion for edge detection
	end

	mouse_cursorhook(voice.cursor_hook)

	table.insert(voice.cleanup,
	function()
		mouse_cursorhook(voice.cursor_hook)
	end)
end

local function voice_a11y(voice, action)
	for d in all_tilers_iter() do
		if d.a11y_handler then
			d.a11y_handler:destroy()
		end
		d.a11y_handler = build_a11y_handler(voice, d)
	end

	table.insert(voice.cleanup, function()
		for d in all_tilers_iter() do
			if d.a11y_handler then
				d.a11y_handler.destroy()
			end
		end
	end
	)
end

local function voice_clipboard_paste(voice, action)
	local map = voice.map

	voice.clipboard_paste =
	function(msg, fail)
		if fail then
			voice:message(action, " fail")
		else
			voice:message(action, msg)
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

	if not voice.profile.menu then
		log(fmt("tts:kind=warning:name=%s:missing_menu_configuration", voice.name))
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
		voice:message("", set[#set] .. (bar.inp.lastm and
			bar.inp.lastm[1] and bar.inp.lastm[1].label or ""))

-- get input string and input prefix
		local prompt_bind = voice.profile.menu.speak_prompt
		if prompt_bind then
		bar.custom_bindings[prompt_bind] =
			function(ictx)
				local str = ictx.inp:view_str()
				if #str == 0 then
					voice:message("", labels.empty_prompt)
				else
					voice:message(labels.prompt, str)
					local caret = ictx.inp:caret_str()
					if caret ~= str then
						voice:message(labels.prompt, caret)
					end
				end
			end
		end

		local help_bind = voice.profile.menu.speak_description
		if help_bind then
			bar.custom_bindings[help_bind] =
			function(ictx)
				if ictx.last_helper then
					voice:message(labels.prompt, ictx.last_helper)
				else
					voice:message(labels.help, labels.no_description)
				end
			end
		end

-- get current full path
		local path_bind = voice.profile.menu.speak_path
		if path_bind then
			bar.custom_bindings[path_bind] =
				function(ictx)
					voice:message(action, menu_get_current_path())
				end
		end

-- message the active completion set
		local set_bind = voice.profile.menu.speak_set
		if set_bind then
			bar.custom_bindings[set_bind] =
				function(ictx)
					local tgt = ictx.inp.lastm
					if not tgt or #tgt == 0 then
						if ictx.inp.set and #ictx.inp.set > 0 then
							tgt = ictx.inp.set
						else
							return
						end
					end

					voice:message(action, "set")
					for k,v in ipairs(tgt) do
						local prefix = ""
						local value = v
						if type(v) == "table" then
							prefix = (v.submenu and "sub" or v.kind) .. " "
							value = v.label
						end

						voice:message("", prefix .. value)
					end
				end
		end

-- only enable echo if it isn't already
		if not tts_in_echo then
			local oldi = bar.inp.input
			bar.inp.input =
			function(ctx, io, sym)
				if #io.utf8 > 0 then
					target_input(voice.vid, io)
				end
				return oldi(ctx, io, sym)
			end
		end

-- hook stepping the currently selected items
		local old_step = bar.on_step
		local lastmsg = ""
		bar.on_step =
			function(lbar, i, key, anchor, ofs, w, mh)
				if old_step then
					old_step(lbar, i, key, anchor, ofs, w, mh)
				end
				if key and key ~= lastmsg and key ~= ".." then
					reset_target(voice.vid)
					voice:message("", key, true)
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

local function tuiwnd_check(v)
	local wnd = active_display().selected
	if not wnd then
		v:message("", labels.no_wnd)
		return
	elseif not wnd.tui_track then
		v:message("", labels.no_tui)
		return
	end
	return wnd
end

local function reset_track(wnd)
	wnd.tui_track.x1 = 6666
	wnd.tui_track.y1 = 6666
	wnd.tui_track.x2 = -1
	wnd.tui_track.y2 = -1
end

local function process_str_fmt(str, fmt)
-- use [fmt] to format >bold< >italic<
	return str
end

local function read_tui_row(wnd, v, x, y)
	local tt = wnd.tui_track
	image_access_storage(wnd.external,
		function(data, w, h, cols, rows)
			local str, fmt = data:read(x, tt.crow)
			v:message("", process_str_fmt(str, fmt))
		end
	)
end

local function voice_tuiwnd_menu(v)
	local res =
	{
		{
			name = "changes",
			label = "Changes",
			description = "Read accumulated changes to the text window since last invocation",
			kind = "action",
			handler = function()
				local wnd = tuiwnd_check(v)
				if not wnd then
					return
				end
				if wnd.tui_track.x1 > wnd.tui_track.x2 or
					wnd.tui_track.y1 > wnd.tui_track.y2 then
					v:message("", labels.no_changes)
					return
				end
				image_access_storage(
					wnd.external,
					function(data, w, h, cols, rows)
						for y=wnd.tui_track.y1,wnd.tui_track.y2 do
						end
					end
				)
				reset_track(wnd)
			end,
		},
		{
			name = "row_up",
			label = "Row up",
			kind = "action",
			description = "Move and read the selected row up one",
			handler = function(ctx)
				local wnd = tuiwnd_check(v)
				if not wnd then
					return
				end
				wnd.tui_track.crow = math.clamp(wnd.tui_track.crow, 0, 6666)
				if wnd.tui_track.crow > 0 then
					wnd.tui_track.crow = wnd.tui_track.crow - 1
					read_current_row(wnd, v)
				else
					v:message("", labels.at_top)
				end
			end
		},
		{
			name = "row_down",
			label = "Row Down",
			description = "Move and read the selected row up one",
			kind = "action",
			handler = function(ctx)
				local wnd = tuiwnd_check(v)
				if not wnd then
					return
				end
				wnd.tui_track.crow = math.clamp(wnd.tui_track.crow, 0, 6666)
				if not wnd.tui_track.rows or wnd.tui_track.crow < wnd.tui_track.rows then
					wnd.tui_track.crow = wnd.tui_track.crow + 1
					read_current_row(wnd, v)
				else
					v:message("", labels.at_bottom)
				end
			end
		},
		{
			name = "cursor_before",
			label = "Start to cursor",
			description = "Read content from start of row up to and including the cursor",
			kind = "action",
			handler = function(ctx)
				local wnd = tuiwnd_check(v)
				if not wnd then
					return
				end
			end,
		},
		{
			name = "cursor_after",
			label = "Cursor to end",
			description = "Read contents from cursor row and position until end of line",
			kind = "action",
			handler = function(ctx)
				local wnd = tuiwnd_check(v)
				if not wnd then
					return
				end

			end
		}
	}
end

-- actual implementations of all possible actions in the voice map
-- extend here with features that requires deeper hooks into durden.
--
-- the other place for extension is the voice menu further below for
-- things that resolve to simpler menu path actions
local actions = {
["select"]          = voice_select,
["clipboard"]       = voice_clipboard,
["clipboard_paste"] = voice_clipboard_paste,
["menu"]            = voice_menu,
["a11ywnd"]         = voice_a11y,
["cursor"]          = voice_cursor
}

local wndhooks = 0
local function wnd_frame_hook(wnd, stat)
	if not stat.cols then
		return
	end
	local tt = wnd.tui_track

-- just go full bounded rectangle
	if stat.x < tt.x1 then
		tt.x1 = stat.x
	end

	if stat.x + stat.cols > tt.x2 then
		tt.x2 = stat.x + stat.cols
	end

	if stat.y < tt.y1 then
		tt.y1 = stat.y
	end

	if stat.y + stat.rows > tt.y2 then
		tt.y2 = stat.y + stat.rows
	end
end

-- this is activated on first use then not dropped until back to zero
local function ensure_wnd_hook()
	if wndhooks > 0 then
		return
	end

	wndhooks = wndhooks + 1
	local types = {"tui", "accessibility", "terminal"}

-- enable on existing windows of supported types
	for _, type in ipairs(types) do
		for wnd in all_windows(type) do
			table.insert(wnd.handlers["frame"], wnd_frame_hook)
			wnd.tui_track =
			{
				x1 = 6666, y1 = 6666,
				x2 = -1, y2 = -1,
				cx = 0, cy = 0,
				crow = 0
			}
			if valid_vid(wnd.external) then
				target_flags(wnd.external, TARGET_VERBOSE, true)
			end
		end
	end

-- and hook window creation and inject the event handler there
	for d in all_tilers_iter() do
		table.insert(d.on_wnd_create,
			function(wm, wnd, space, active)
				if table.find_i(types, wnd.atype) then
					target_flags(wnd.external, TARGET_VERBOSE, true)
				end
				wnd.tui_track =
				{
					x1 = 6666, y1 = 6666,
					x2 = -1, y2 = -1,
					cx = 0, cy = 0,
					crow = 0
				}
				table.insert(wnd.handlers["frame"], wnd_frame_hook)
			end
		)

	end
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
				timer_add_periodic("tts_start", 1, true, function()
					if valid_vid(source) then
						target_input(source, "the voice" .. name .. " activated")

-- activate spatial if requested
						if map.position then
							voice.positioner = null_surface(1, 1)
							link_image(voice.positioner, source)
							image_mask_clear(voice.positioner, MASK_POSITION)
							move3d_model(voice.positioner, unpack(map.position))
							audio_position(status.source_audio, voice.positioner)
						end
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
	ensure_wnd_hook();
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
			v:message(labels.speak, val)
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
		name = "text_window",
		label = "Text Windows",
		kind = "action",
		submenu = true,
		description = "Controls for speaking out the contents of text-only windows",
		handler = function()
			return voice_tuiwnd_menu(v)
		end
	})

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
				send_label(v.vid, "SETRATE");
			end
		end
	});

	table.insert(ent,
	{
		name = "toggle_key_echo",
		label = "Toggle Echo",
		kind = "action",
		handler = function()
			if tts_in_echo and tts_in_echo ~= v then
				v:message(labels.echo_fail, labels.echo_fail_long)
				return
			end

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

	local isub = {
	}

	for _, lbl in ipairs(v.labels) do
		table.insert(isub,
			{
				name = string.lower(lbl),
				kind = "action",
				description = "forward input to speech service",
				label = lbl,
				handler = function()
					send_label(v.vid, lbl)
				end
			}
		)
	end

	table.insert(ent,
		{
			name = "input",
			label = "Input",
			kind = "action",
			submenu = true,
			description = "TTS Service provided input triggers",
			handler = isub
		}
	)

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

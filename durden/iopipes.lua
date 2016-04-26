-- unsetting these values will prevent all external communication that is not
-- using the nonauth- connection or regular input devices
local sbar_fn = gconfig_get("status_path");
if (sbar_fn ~= nil and string.len(sbar_fn) > 0 and sbar_fn ~= ":disabled") then
	zap_resource(sbar_fn);
	STATUS_CHANNEL = open_nonblock("<" .. sbar_fn);
end

local cchan_fn = gconfig_get("control_path");
if (cchan_fn ~= nil and string.len(cchan_fn) > 0 and cchan_fn ~= ":disabled") then
	zap_resource(cchan_fn);
	CONTROL_CHANNEL = open_nonblock("<" .. cchan_fn);
end

-- grammar:
-- | element splits group
-- %{ ... } gives formatting command
-- %% escape %
--
-- handled formatting commands:
--  Frrggbb - set foreground color
--  F- - set default color
--  S+, S-, Sf, Sl, Sn - switch tiler/display
--
-- ignored formatting commands:
--  l [ align left, not supported   ]
--  r [ align right, not supported  ]
--  c [ align center, not supported ]
--  Brrggbb - set background color, not supported (engine limit)
--  Urrggbb - set underline color, not supported (engine limit)
--  A:oblogout: and empty A - bind command, not supported
--
-- most of these are limited as there are in-durden ways of achieving same res.
--
local function process_fmt(tok, i, disp)
	local col;

-- can support more here (e.g. embed glyph, bold/italic)
	while (tok[i] and tok[i].fmt) do
		if (string.len(tok[i].msg) > 0) then
			if tok[i].msg == "F-" then
				col = gconfig_get("text_color");
			elseif string.match(tok[i].msg, "F%x%x%x%x%x%x") then
				col = "\\#"  .. string.sub(tok[i].msg, 2);
			elseif string.match(tok[i].msg, "S%d") then
				disp = tostring(string.sub(tok[i].msg, 2));
			elseif tok[i].msg == "S+" then
				disp = disp + 1;
				disp = disp > display_count() and 1+(display_count() % disp) or disp;
			elseif tok[i].msg == "S-" then
				disp = disp - 1;
				disp = disp <= 0 and display_count() or disp;
			elseif tok[i].msg == "Sf" then
				disp = 1;
			elseif tok[i].msg == "Sl" then
				disp = display_count();
			else
				if (DEBUGLEVEL > 0) then
					print("status parse, ignoring bad format " .. tok[i].msg);
				end
			end
		end

		i = i + 1;
	end

	return i, disp, col;
end

local function status_parse(line)
	local tok = {};

	local cs = "";
	local i = 1;
	local in_p = false;
	local in_g = false;

-- first tokenize
	while i <= string.len(line) do
		local ni = string.utf8forward(line, i);
		if (not ni) then
			break;
		end
		local ch = string.sub(line, i, ni-1);

-- handle %% %{
		if (ch == '%') then
			if (in_g) then
				warning("status-channel parse, malformed input (pct in fmt-cmd)");
				return {};
			end

			if (in_p) then
				cs = cs .. '%';
				in_p = false;

			elseif (not in_g) then
				in_p = true;
			end

		elseif (in_p and ch ~= '{') then
			warning("status-channel parse, malformed input (pct to npct/bracket)");
			return {};

-- handle transition msg%{ to fmt group state
		elseif (in_p) then
			in_g = true;
			in_p = false;
			if (string.len(cs) > 0) then
				table.insert(tok, {fmt = false, msg = cs});
				cs = "";
			end

-- handle transition fmt-group -> default
		elseif (in_g and ch == '}') then
			in_g = false;
			if (string.len(cs) == 0) then
				warning("status-channel parse, malformed input (empty fmt group)");
				return {};
			end
			table.insert(tok, {fmt = true, msg = cs});
			cs = "";

		elseif (ch == '|') then
			if (not in_g and not in_p) then
				table.insert(tok, {fmt = false, msg = cs});
			end
			cs = "";
			table.insert(tok, {newgrp = true, msg = ""});
		else
			cs = cs .. ch;
		end

		i = ni;
	end

-- handle EoS state
	if (not in_g and not in_p) then
		table.insert(tok, {fmt = false, msg = cs});
	end

-- now parse tok and convert into array of groups of format tables indexed by
-- desired destination display
	local disp = 1;
	local res = { { { } } };
	local i = 1;

-- we use the escaped form of render-text so %2==0 entries are treated as fmtstr
	while i <= #tok do
		local fmt = nil;

		if (string.len(tok[i].msg) > 0) then -- ignore empty
			if (tok[i].fmt) then
				i, disp, fmt = process_fmt(tok, i, disp);
				if (not res[disp]) then
					res[disp] = {};
					res[disp][1] = {};
				end

				if (fmt) then
					if (#res[disp] % 2 == 1) then
						table.insert(res[disp][#res[disp]], "");
					end
					table.insert(res[disp][#res[disp]], fmt);
				end
			else
				if (#res[disp] % 2 == 0) then
					table.insert(res[disp][#res[disp]], "");
				end
				table.insert(res[disp][#res[disp]], tok[i].msg);
				i = i + 1;
			end
		elseif (tok[i].newgrp) then
			if (#res[disp][#res[disp]] > 0) then
				res[disp][#res[disp]+1] = {};
			end
			i = i + 1;
		else
			i = i + 1;
		end
	end

-- now res is a table indexed with display identifiers and with proper fmtstrs
	return res;
end

local function poll_status_channel()
	local line = STATUS_CHANNEL:read();
	if (line == nil or string.len(line) == 0) then
		return;
	end

-- generate render_text compatible tables based on input line and add to
-- the suitable statusbar for each display.
	local lst = status_parse(line);

	local ind = 1;
	for disp in all_displays_iter() do
		if (lst[ind]) then
			for i=#lst[ind],1,-1 do
				local di = #lst[ind]-i+1;
				local btn = disp.statusbar.buttons.right[di];
				if (btn == nil) then
				disp.statusbar:add_button("right", "sbar_msg_bg",
					"sbar_msg_text", lst[ind][i] and lst[ind][i] or "",
					gconfig_get("sbar_tpad") * disp.scalef,
					disp.font_resfn
				);
				else
					local cw = btn.last_label_w;
					disp.statusbar:update("right", di, lst[ind][i] and lst[ind][i] or "");
					if ((not btn.minw or btn.minw == 0 and cw) or (cw and cw > btn.minw)) then
						btn:constrain(nil, cw, nil, nil, nil);
					end
				end
			end
			ind = ind + 1;
		end
	end
end

local function poll_control_channel()
	local line = CONTROL_CHANNEL:read();
	if (line == nil or string.len(line) == 0) then
		return;
	end

	local elem = string.split(line, ":");

-- hotplug event
	if (elem[1] == "rescan_displays") then
		video_displaymodes();
		return;
	end

	if (#elem ~= 2) then
		warning("broken command received on control channel, expected 2 args");
		return;
	end

	if (elem[1] == "screenshot") then
		local rt = active_display(true);
		if (valid_vid(rt)) then
			save_screenshot(elem[2], FORMAT_PNG, rt);
			active_display():message("saved screenshot");
		end

	elseif (DEBUGLEVEL > 0 and elem[1] == "snapshot") then
		system_snapshot("debug/" .. elem[2]);
		active_display():message("saved debug snapshot");
	else
		if (not allowed_commands(elem[2])) then
			warning("unknown/disallowed command: " .. elem[2]);
			return;
		end

		if (elem[1] == "command") then
			dispatch_symbol(elem[2]);
		elseif (elem[1] == "global") then
			dispatch_symbol("!/" .. elem[2]);
		elseif (elem[1] == "target") then
			dispatch_symbol("#/" .. elem[2]);
		else
			warning("unknown command namespace: " .. elem[1]);
		end
	end
end

-- open question is if we should check lock-state here and if we're in locked
-- input, also disable polling status / control
timer_add_periodic("status_control", 8, false,
function()
	if (STATUS_CHANNEL) then
		poll_status_channel();
	end

	if (CONTROL_CHANNEL) then
		poll_control_channel();
	end
end, true
);

-- chain here rather than add some other hook mechanism, then the entire feature
-- can be removed by dropping the system_load() call.
local dshut = durden_shutdown;
durden_shutdown = function()
	dshut();

	if (STATUS_CHANNEL) then
		zap_resource(gconfig_get("status_path"));
	end
	if (CONTROL_CHANNEL) then
		zap_resource(gconfig_get("control_path"));
	end
end

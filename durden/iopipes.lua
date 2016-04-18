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

--
-- text/line command protocol for doing status bar updates, etc.
-- as this grows, move into its own separate module.
--
local function poll_status_channel()
	local line = STATUS_CHANNEL:read();
	if (line == nil or string.len(line) == 0) then
		return;
	end

	print("got cmd:", line);
	local cmd = string.split(line, ":");
	cmd = cmd == nil and {} or cmd;
	local fmt = string.format("%s \\#ffffff", gconfig_get("font_str"));

	if (cmd[1] == "status_1") then
-- escape control characters so we don't get nasty \f etc. commands
		local vid = render_text({fmt, msg});
		if (valid_vid(vid)) then
			active_display():update_statusbar({}, vid);
		end
	else
		dispatch_symbol(cmd[1]);
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

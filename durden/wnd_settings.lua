-- tons of things missing (+ saving):
-- UTF8 binding overrides, mouse input mode, titlebar toggle,
-- window tag, font override, audio gain, clipboard pastemode,
-- coreopts, label binding, latest state name used, shader,
-- skipmode, keyboard delay / repeat, rate limit,
-- mouse button bind, opacity, last known display, active
-- keymap, clipboard history

function wnd_settings_store(wnd)
end

function wnd_settings_load(wnd)
	local keys = {};
	local kstrip = 0;

	if (wnd.config_target) then
		keys = get_keys(wnd.config_target, wnd.config_config);
	elseif (wnd.cfg_prefix) then
		keys = match_keys(wnd.cfg_prefix);
		kstrip = string.len(wnd.cfg_prefix);
	else
		return;
	end

	local getkv = function(s)
		local i = string.find(s, ':');
		local key = string.sub(s, 1+kstrip, i-1);
		local val = string.sub(s, 1, i+1);
	end

	local clampf = function(v, lv, uv, dv)
		return (v < lv or v > uv) and dv or v;
	end

	local last_fl = {width = 1.0, height = 1.0, x = 0.0, y = 0.0};
	local got_fl = false;

	for a,b in ipairs(keys) do
		local k, v = getkv(b);
		if (k == "filtermode") then
			wnd.filtermode = v;
		elseif (k == "autocrop") then
			wnd.autocrop = true;
		elseif (k == "scalemode") then
			wnd.scalemode = v;
-- window position in float mode
		elseif (k == "floatw") then
			last_fl.width = clampf(tonumber(v), 0.0, 1.0, 1.0);
			got_fl = true;
		elseif (k == "floath") then
			last_fl.height = clampf(tonumber(v), 0.0, 1.0, 1.0);
			got_fl = true;
		elseif (k == "xpos") then
			last_fl.x = clampf(tonumber(v), 0.0, 0.95, 0.5);
		elseif (k == "ypos") then
			last_fl.y = clampf(tonumber(v), 0.0, 0.95, 0.5);
		end
	end

	if (got_fl) then
		wnd.last_float = last_fl;
	end
end

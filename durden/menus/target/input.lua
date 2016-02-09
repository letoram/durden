local function run_input_label(wnd, v)
	if (not valid_vid(wnd.external, TYPE_FRAMESERVER)) then
		return;
	end

	local iotbl = {
		kind = "digital",
		label = v[1],
		translated = true,
		active = true,
		devid = 8,
		subid = 8
	};

	target_input(wnd.external, iotbl);
	iotbl.active = false;
	target_input(wnd.external, iotbl);
end

local function build_labelmenu()
	local wnd = active_display().selected;
	if (not wnd or not wnd.input_labels or #wnd.input_labels == 0) then
		return;
	end

	local res = {};
	for k,v in ipairs(wnd.input_labels) do
		table.insert(res, {
			name = "input_" .. v[1],
			label = v[1],
			kind = "action",
			handler = function()
				run_input_label(wnd, v);
			end
		});
	end

	return res;
end

local function build_bindmenu(wide)
	local wnd = active_display().selected;
	if (not wnd or not wnd.input_labels or #wnd.input_labels == 0) then
		return;
	end
	local bwt = gconfig_get("bind_waittime");
	local res = {};
	for k,v in ipairs(wnd.input_labels) do
		table.insert(res, {
			name = "target_input_" .. v[1],
			label = v[1],
			kind = "action",
			handler = function()
				tiler_bbar(active_display(),
					string.format("Bind: %s, hold desired combination.", v[1]),
					"keyorcombo", bwt, nil, SYSTEM_KEYS["cancel"],
					function(sym)
						wnd.labels[sym] = v[1];
					end
				);
			end
		});
	end

	return res;
end

local label_menu = {
	{
		name = "input",
		label = "Input",
		kind = "action",
		hint = "Input Label:",
		submenu = true,
		handler = build_labelmenu
	},
	{
		name = "target_input_localbind",
		label = "Local-Bind",
		kind = "action",
		hint = "Action:",
		submenu = true,
		handler = function() return build_bindmenu(true); end
	},
	{
		name = "target_input_globalbind",
		label = "Global-Bind",
		kind = "action",
		hint = "Action:",
		submenu = true,
		handler = function() return build_bindmenu(false); end
	}
};

local kbd_menu = {
	{
		name = "target_bind_utf8",
		kind = "action",
		label = "Bind UTF-8",
		eval = function(ctx)
			local sel = active_display().selected;
			return (sel and sel.u8_translation) and true or false;
		end,
		handler = grab_shared_function("bind_utf8")
	},
	{
		name = "target_keyboard_repeat",
		label = "Repeat Period",
		kind = "value",
		initial = function() return tostring(0); end,
		hint = "cps (0:disabled - 100)",
		validator = gen_valid_num(0, 100);
		handler = function()
			warning("set repeat rate");
		end
	},
	{
		name = "target_keyboard_delay",
		label = "Initial Delay",
		kind = "value",
		initial = function() return tostring(0); end,
		hint = "ms (0:disable - 1000)",
		handler = function()
			warning("set repeat delay");
		end
	},
};

local function mouse_lockfun(x, y, rx, ry, wnd)
	print("forward input to target:", x, y, rx, ry, wnd);
end

local mouse_menu = {
	{
		name = "target_mouse_lock",
		label = "Mouse Lock",
		kind = "value",
		set = {"Disabled", "Constrain", "Center"},
		initial = function()
			local wnd = active_display().selected;
			return wnd.mouse_lock and wnd.mouse_lock or "Disabled";
		end,
		handler = function(ctx, val)
			local wnd = active_display().selected;
			if (val == "Disabled") then
				wnd.mouse_lock = nil;
				mouse_lockto(nil, nil);
			else
				wnd.mouse_lock = val;
				mouse_lockto(wnd.canvas, mouse_lockfun, val == "Center", wnd);
			end
		end
	},
	{
		name = "target_mouse_cursor",
		label = "Cursor Mode",
		kind = "value",
		set = {"default", "hidden"},
		initial = function()
			local wnd = active_display().selected;
			return wnd.cursor ==
				"hidden" and "hidden" or "default";
		end,
		handler = function(ctx, val)
			if (val == "hidden") then
				mouse_hide();
			else
				mouse_show();
			end
			active_display().selected.cursor = val;
		end
	},
	{
		name = "target_mouse_rlimit",
		label = "Rate Limit",
		kind = "value",
		set = {LBL_YES, LBL_NO},
		initial = function()
			return active_display().selected.rate_unlimited and LBL_NO or LBL_YES;
		end,
		handler = function(ctx, val)
			if (val == LBL_YES) then
				active_display().selected.rate_unlimited = false;
			else
				active_display().selected.rate_unlimited = true;
			end
		end
	},
};

return {
	{
		name = "target_input_labels",
		label = "Labels",
		kind = "action",
		submenu = true,
		eval = function(ctx)
			local sel = active_display().selected;
			return sel and sel.input_labels and #sel.input_labels > 0;
		end,
		handler = label_menu
	},
	{
		name = "target_input_keyboard",
		label = "Keyboard",
		kind = "action",
		submenu = true,
		handler = kbd_menu
	},
	{
		name = "target_input_bindcustom",
		label = "Bind Custom",
		kind = "action",
		handler = grab_shared_function("bind_custom"),
	},
	{
		name = "target_input_mouse",
		label = "Mouse",
		kind = "action",
		submenu = true,
		handler = mouse_menu
	}
};

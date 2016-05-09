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

local function build_unbindmenu()
	local res = {};
	local wnd = active_display().selected;
	for k,v in pairs(wnd.labels) do
		table.insert(res, {
			name = "input_" .. v,
			label = k .. "=>" .. v,
			kind = "action",
			handler = function()
				wnd.labels[k] = nil;
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
			name = "input_" .. v[1],
			label = v[1],
			kind = "action",
			handler = function()
				tiler_bbar(active_display(),
					string.format("Bind: %s, hold desired combination.", v[1]),
					"keyorcombo", bwt, nil, SYSTEM_KEYS["cancel"],
					function(sym, done, aggsym)
						if (done) then
							wnd.labels[aggsym and aggsym or sym] = v[1];
						end
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
-- not finished yet, part of the whole "settings per target" problem
	{
		name = "localbind",
		label = "Temporary-Bind",
		kind = "action",
		hint = "Action:",
		submenu = true,
		handler = function() return build_bindmenu(true); end
	},
	{
		name = "globalbind",
		label = "Class-Bind",
		kind = "action",
		eval = function() return false; end,
		hint = "Action:",
		submenu = true,
		handler = function() return build_bindmenu(false); end
	},
	{
		name = "labelunbind",
		label = "Unbind",
		kind = "action",
		hint = "Unbind",
		submenu = true,
		handler = function() return build_unbindmenu(); end
	}
};

local kbd_menu = {
	{
		name = "utf8",
		kind = "action",
		label = "Bind UTF-8",
		eval = function(ctx)
			local sel = active_display().selected;
			return (sel and sel.u8_translation) and true or false;
		end,
		handler = grab_shared_function("bind_utf8")
	},
	{
		name = "bindcustom",
		label = "Bind Custom",
		kind = "action",
		handler = grab_shared_function("bind_custom"),
	},
	{
		name = "unbind",
		label = "Unbind",
		kind = "action",
		handler = grab_shared_function("unbind_custom")
	},
	{
		name = "repeat",
		label = "Repeat Period",
		kind = "value",
		initial = function() return tostring(0); end,
		hint = "cps (0:disabled - 100)",
		validator = gen_valid_num(0, 100);
		handler = function(ctx, num)
			iostatem_repeat(tonumber(num));
		end
	},
	{
		name = "delay",
		label = "Initial Delay",
		kind = "value",
		initial = function() return tostring(0); end,
		hint = "ms (0:disable - 1000)",
		handler = function(ctx, num)
			iostatem_repeat(nil, tonumber(num));
		end
	},
};

local function mouse_lockfun(rx, ry, x, y, wnd)
	if (wnd) then
		wnd.mousemotion({tag = wnd}, x, y);
	end
end

local mouse_menu = {
	{
		name = "lock",
		label = "Lock",
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
				wnd.mouse_lock_center = false;
				mouse_lockto(nil, nil);
			else
				wnd.mouse_lock = mouse_lockfun;
				wnd.mouse_lock_center = val == "Center";
				mouse_lockto(wnd.canvas, nil, wnd.mouse_lock_center, wnd);
			end
		end
	},
	{
		name = "cursor",
		label = "Cursor",
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
		name = "rlimit",
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
		name = "labels",
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
		name = "keyboard",
		label = "Keyboard",
		kind = "action",
		submenu = true,
		handler = kbd_menu
	},
	{
		name = "mouse",
		label = "Mouse",
		kind = "action",
		submenu = true,
		handler = mouse_menu
	}
};

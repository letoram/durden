local function run_input_label(wnd, v)
	if (not valid_vid(wnd.external, TYPE_FRAMESERVER)) then
		return;
	end

	local iotbl = {
		kind = "digital",
		label = v.label,
		translated = true,
		active = true,
		devid = 8,
		subid = 8
	};

	wnd:input_table(iotbl);
	iotbl.active = false;
	wnd:input_table(iotbl);
end

local function build_labelmenu()
	local wnd = active_display().selected;
	if (not wnd or not wnd.input_labels or #wnd.input_labels == 0) then
		return;
	end

	local res = {};
	for k,v in ipairs(wnd.input_labels) do
		table.insert(res, {
			name = "input_" .. v.label,
			label = string.format("%s%s", v.label,
				#v.symbol > 0 and "(" .. v.symbol .. ")" or ""),
			description = string.format("%s - %s", v.label, v.description),
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

local kbd_menu = {
	{
		name = "utf8",
		kind = "action",
		label = "Bind UTF-8",
		description = "Add a window-local keyboard key to unicode codepoint binding",
		eval = function(ctx)
			local sel = active_display().selected;
			return (sel and sel.u8_translation) and true or false;
		end,
		handler = function()
			suppl_bind_u8(function(sym, str, sym2)
				local wnd = active_display().selected;
				wnd.u8_translation[sym2 and sym2 or sym] = str;
				SYMTABLE:translation_overlay(wnd.u8_translation);
			end);
		end
	},
	{
		name = "repeat",
		label = "Repeat Period",
		kind = "value",
		description = "Set window-local rate for how fast keyboard inputs should repeat",
		initial = function()
			local rate, delay = iostatem_repeat();
			return rate;
		end,
		hint = "cps (0:disabled - 100)",
		validator = gen_valid_num(0, 100),
		handler = function(ctx, num)
			iostatem_repeat(tonumber(num));
		end
	},
	{
		name = "delay",
		label = "Initial Delay",
		description = "Set window-local delay before keyboard input repeats",
		kind = "value",
		initial = function()
			local rate, delay = iostatem_repeat();
			return delay * (1000 / CLOCKRATE);
		end,
		hint = "ms (0:disable - 1000)",
		handler = function(ctx, num)
			iostatem_repeat(nil, tonumber(num));
		end
	},
	{
		name = "send_map",
		label = "Send Keymap",
		description = "Send active or specified input platform keymap",
		kind = "value",
		eval = function()
			return string.match(API_ENGINE_BUILD, "evdev") ~= nil and
			       valid_vid(active_display().selected.external, TYPE_FRAMESERVER);
		end,
		hint = "(us,cz,de pc104 basic grp:alt_shift_toggle)",
		handler =
		function(ctx, val)
			local ios, msg;
			if val and #val > 0 then
				local set = string.split(val, " ");
-- we need layout, model, variant, options
				ios, msg = input_remap_translation(-1, TRANSLATION_SET, true, unpack(set));
			else
				ios, msg = input_remap_translation(-1, TRANSLATION_REMAP, true);
			end

			if type(ios) == "userdata" then
				open_nonblock(active_display().selected.external, false, "xkb", ios);
			end
		end
	}
};

local function mouse_lockfun(rx, ry, x, y, wnd, ind, act)
-- simulate the normal mouse motion in the case of constrained input
	if not wnd or not wnd.mousebutton then
		mouse_lockto(nil, nil);
		return;
	end

	if (ind) then
		wnd:mousebutton(ind, act, x, y);
	else
		wnd:mousemotion(x, y, rx, ry);
	end
end

local scroll_menu = {
	{
		name = "absolute",
		label = "Absolute",
		description = "Reposition visible content to a specific position",
		kind = "value",
		hint = function()
			local wnd = active_display().selected;
			return string.format("0..1:step=%f", wnd.got_scroll[2]);
		end,
		initial =
		function()
			local wnd = active_display().selected;
			return string.format("0..1:step=%f", wnd.got_scroll[1]);
		end,
		validator = gen_valid_float(0, 1),
		handler = function(ctx, val)
			seek_target(active_display().selected.external, tonumber(val), false, false);
		end
	},
};

local seek_menu = {
};

local mouse_menu = {
	{
		name = "lock",
		label = "Lock",
		kind = "value",
		description = "Lock mouse input to this window",
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
				mouse_lockto(wnd.canvas,
					mouse_lockfun, wnd.mouse_lock_center, wnd);
			end
		end
	},
	{
		name = "cursor",
		label = "Cursor",
		kind = "value",
		description = "Control whether the global cursor should be visible or not",
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
		description = "Limit the rate of mouse events being forwarded",
		kind = "value",
		set = {LBL_YES, LBL_NO, LBL_FLIP},
		initial = function()
			return active_display().selected.rate_unlimited and LBL_NO or LBL_YES;
		end,
		handler = function(ctx, val)
			local wnd = active_display().selected;
			if (val == LBL_FLIP) then
				val = not wnd.rate_unlimited;
			else
				val = val == LBL_YES;
			end
			wnd.rate_unlimited = val;
		end
	},
};

return {
	{
		name = "labels",
		label = "Labels",
		kind = "action",
		submenu = true,
		description = "Custom client-provided inputs",
		eval = function(ctx)
			local sel = active_display().selected;
			return sel and sel.input_labels and #sel.input_labels > 0;
		end,
		handler = build_labelmenu
	},
	{
		name = "custom",
		label = "Bind Custom",
		kind = "action",
		description = "Create a custom/local meta+key menu path binding",
		handler = function()
			local m1, m2 = dispatch_meta();
			suppl_binding_helper("", "",
			function(bind, path)
				active_display().selected.bindings[bind] = path;
			end);
		end
	},
	{
		name = "unbind",
		label = "Unbind",
		kind = "value",
		description = "Remove a custom/local binding",
		eval = function()
			for k,v in pairs(active_display().selected.bindings) do
				return true;
			end
			return false;
		end,
		set = function()
			local wnd = active_display().selected;
			local lst = {};
			for k,v in pairs(active_display().selected.bindings) do
				table.insert(lst, k);
			end
			table.sort(lst);
			return lst;
		end,
		handler = function(ctx, val)
			active_display().selected.bindings[val] = nil;
		end
	},
	{
		name = "keyboard",
		label = "Keyboard",
		kind = "action",
		description = "Local keyboard settings",
		submenu = true,
		handler = kbd_menu
	},
	{
		name = "mouse",
		label = "Mouse",
		kind = "action",
		submenu = true,
		description = "Local mouse settings",
		eval = function() return not mouse_blocked(); end,
		handler = mouse_menu
	},
	{
		name = "scroll",
		kind = "action",
		label = "Scroll",
		description = "Pan window contents to a specific absolute or relative position",
		eval = function()
			return active_display().selected.got_scroll ~= nil;
		end,
		submenu = true,
		handler = scroll_menu
	},
	{
		name = "seek",
		kind = "action",
		label = "Seek",
		description = "Seek to a specific or relative point in time",
		eval = function()
			return active_display().selected.streamstatus ~= nil;
		end,
		submenu = true,
		handler = seek_menu
	},
	{
		name = "multicast",
		label = "Multicast",
		kind = "value",
		description = "Enable multicast where input is mirrored to children (tile)",
		set = {LBL_YES, LBL_NO, LBL_FLIP},
		initial = function()
			return active_display().selected.multicast and LBL_YES or LBL_NO;
		end,
		handler = function(ctx, val)
			local wnd = active_display().selected;
			if (val == LBL_FLIP) then
				val = not wnd.multicast;
			else
				val = val == LBL_YES;
			end
			wnd.multicast = val;
		end
	}
};

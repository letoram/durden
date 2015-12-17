--
-- Specialized singleton window that monitors input events,
-- state changes, messages etc.
--

local debug_metatbl = {
	__index = function(t, k)
	end
};

local TARGET_EVGRP = 1;
local TARGET_DISPGRP = 2;
local INPUT_EVGRP = 3;
local SYSTEM_GRP = 4;
local SYMBOL_GRP = 5;

local function debugwnd_resize(wnd, w, h)
	wnd:refresh();
end

local function target_event(self, wnd, src, tbl)
	local ostr = "";
	if (tbl.kind == "framestatus") then
-- noisy and mostly useless debuggingwise
	elseif (tbl.kind == "input_label") then
		self:add_event(TARGET_EVGRP, string.format(
			"[%s] label: %s", wnd.name, tbl.labelhint));
	else
		local fields = {};
		for k,v in pairs(tbl) do
			if (k ~= "kind") then
				table.insert(fields, string.format("%s(%s)", k, tostring(v)));
			end
		end
		self:add_event(TARGET_EVGRP, string.format(
		"[%s] kind: %s [%s]", wnd.name, tbl.kind, table.concat(fields, ',')));
	end
end

local function event_dispatch(wnd, tgt, kind, tbl)
	wnd:add_event(TARGET_DISPGRP, string.format(
		"[%s] <= %s", kind, tgt.name));
end

local function add_input(wnd, iotbl, target)
	if (iotbl.kind == "digital") then
		if (iotbl.translated) then
			wnd:add_event(INPUT_EVGRP, string.format(
			"target: %s, keyboard %s: dev:sub=%d:%d mod=%s, " ..
			"sym: %s=%s, scancode=%d, utf8=%s",
				target ~= nil and tostring(target) or "none",
				iotbl.active and "press" or "release", iotbl.devid, iotbl.subid,
				table.concat(decode_modifiers(iotbl.modifiers), "+"),
				iotbl.keysym and iotbl.keysym or "none",
				SYMTABLE[iotbl.keysym] and SYMTABLE[iotbl.keysym] or "none",
				iotbl.number, iotbl.utf8)
			);
		else
			wnd:add_event(INPUT_EVGRP, string.format(
				"target: %s, digital %s: dev:sub=%d:%d",
				target ~= nil and tostring(target) or "none",
				iotbl.active and "press" or "release",
				iotbl.devid, iotbl.subid
			));
		end
	elseif (iotbl.kind == "analog") then
		wnd:add_event(INPUT_EVGRP, string.format(
		"target: %s, analog(%d:%d), sv[%s]",
			target ~= nil and tostring(target) or "none",
			iotbl.devid, iotbl.subid,
			table.concat(iotbl.samples, ",")
		));

	elseif (iotbl.kind == "touch") then
		wnd:add_event(INPUT_EVGRP, string.format(
			"target: %s, touch:(%d:%d), @x,y=%d,%d pressure=%d size=%d",
			target ~= nil and tostring(target) or "none",
			iotbl.devid, iotbl.subid, iotbl.x, iotbl.y,
			iotbl.pressure, iotbl.size)
		);
	end
end

local function add_sevent(wnd, msg)
	wnd:add_event(SYSTEM_GRP, msg);
end

local function add_symbol(wnd, msg)
	wnd:add_event(SYMBOL_GRP, msg);
end

local function refresh(wnd)
	if (valid_vid(wnd.history)) then
		delete_image(wnd.history);
	end
	local nr = math.ceil(wnd.height / (1.75 * gconfig_get("font_sz") - 0.5));
	if (nr > 0) then
		local ec = #wnd.events[wnd.gind].ent;
		nr = nr > ec and ec or nr;
		local str = string.format("%s %s",
			gconfig_get("font_str"),
			table.concat(wnd.events[wnd.gind].ent, [[\n\r]], ec - nr + 1, ec)
		);

		if (valid_vid(wnd.history)) then
			render_text(wnd.history, str);
		else
			wnd.history = render_text(str);
			if (valid_vid(wnd.history)) then
				show_image(wnd.history);
				link_image(wnd.history, wnd.canvas);
				image_clip_on(wnd.history, CLIP_SHALLOW);
				image_mask_set(wnd.history, MASK_UNPICKABLE);
				image_inherit_order(wnd.history, true);
				order_image(wnd.history, 1);
			end
		end
	else
		wnd.history = nil;
	end
end

local function add_event(wnd, ind, str)
	if (wnd.out_file) then
		wnd.out_file:write(tostring(ind)..":"..str.."\n");
	end

	if (str) then
		local str = string.gsub(str, "\\", "\\\\");
		table.insert(wnd.events[ind].ent, str);
	end
	if (#wnd.events[ind].ent> 100) then
		table.remove(wnd.events[ind].ent, 1);
	end
	if (ind == wnd.gind) then
		wnd:refresh();
	end
end

local function wnd_destroy(wnd)
	if (valid_vid(wnd.history)) then
		delete_image(wnd.history);
	end
end

local function wnd_input(wnd, sym, iotbl)
	if (iotbl.active and sym == SYSTEM_KEYS["previous"]) then
		wnd.gind = wnd.gind == 1 and #wnd.events or wnd.gind - 1;
		wnd:set_prefix(wnd.events[wnd.gind].tag);
		wnd:refresh();
	elseif (iotbl.active and sym == SYSTEM_KEYS["next"]) then
		wnd.gind = (wnd.gind + 1)
			> #wnd.events and 1 or (wnd.gind + 1);
		wnd:set_prefix(wnd.events[wnd.gind].tag);
		wnd:refresh();
	end
end

local function query_outf(ctx, wnd)
	local bar = tiler_lbar(active_display(),
	function(ctx, msg, done, set)
		local wnd = active_display().selected;
		if (done and wnd) then
			if (wnd.out_file) then
				wnd.out_file:close();
				wnd.out_file = nil;
			else
				zap_resource("debug/" .. msg);
				wnd.out_file = open_nonblock("debug/" .. msg, true);
			end
		end
	end, "filename (debug/):");
end

local function debugwnd_spawn()
	if (active_display().debug_console) then
		return;
	end

	local img = fill_surface(100, 100, 0, 0, 0, 100, 100);
	show_image(img);

	local wnd = active_display():add_window(img, {});
	wnd.tick = function() end
	wnd.target_event = target_event;
	wnd.event_dispatch = event_dispatch;
	wnd.system_event = add_sevent;
	wnd.add_input = add_input;
	wnd.add_symbol = add_symbol;
	wnd.key_input = wnd_input;
	wnd.add_event = add_event;
	wnd.refresh = refresh;
	wnd:add_handler("destroy", wnd_destroy);
	wnd:set_title("Debug Console");
	wnd.no_shared = true;
	wnd.scalemode = "stretch";
	wnd.gind = 3;

	wnd.events = {};
	wnd.events[TARGET_EVGRP] = {
		tag = "target-event handler",
		ent= {}
	};
	wnd.events[TARGET_DISPGRP] = {
		tag = "target-event dispatch",
		ent= {}
	};
	wnd.events[INPUT_EVGRP] = {
		tag = "input-event handler",
		ent= {}
	};
	wnd.events[SYSTEM_GRP] = {
		tag = "system events",
		ent = {}
	};
	wnd.events[SYMBOL_GRP] = {
		tag = "symbol bindings",
		ent = {}
	};
	wnd.actions = {
		{
			name = "debug_outfile",
			label = "Toggle File Output",
			handler = query_outf,
			kind = "action"
		}
	};

	table.insert(wnd.handlers.destroy, function()
		 active_display().debug_console = nil;
		 if (wnd.out_file) then
				wnd.out_file:close();
		 end
	end);
	table.insert(wnd.handlers.resize, debugwnd_resize);
	setmetatable(wnd, debug_metatbl);
	active_display().debug_console = wnd;
	wnd:refresh();
end

if (DEBUGLEVEL > 0) then
	register_global("debug_debugwnd", debugwnd_spawn);
end

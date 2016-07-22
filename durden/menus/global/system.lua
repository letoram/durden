local exit_query = {
{
	name = "no",
	label = "No",
	kind = "action",
	handler = function() end
},
{
	name = "yes",
	label = "Yes",
	kind = "action",
	dangerous = true,
	handler = function() shutdown(); end
}
};

-- Lockscreen States:
-- [Idle-setup] -(idle_wakeup)-> [lock_query] -> (cancel: Idle-setup,
-- ok/verify: Idle-restore, ok/fail: Idle-setup)

local ef = function() end;
local idle_wakeup = ef;
local idle_setup = function(val, failed)
	if (failed > 0) then
		local fp = gconfig_get("lock_fail_" .. tostring(failed));
		if (fp) then
			dispatch_symbol(fp);
		end
	end

	active_display():set_input_lock(ef);
	timer_add_idle("idle_wakeup", 10, true, ef, function()
		idle_wakeup(val, failed);
	end);
end

local function idle_restore()
	durden_input = durden_normal_input;
	for d in all_tilers_iter() do
		show_image(d.anchor);
	end
	active_display():set_input_lock();
end

idle_wakeup = function(key, failed)
	local bar = active_display():lbar(
		function(ctx, msg, done, lastset)
			if (not done) then
				return true;
			end

-- accept, note that this comparison is early-out timing side channel
-- sensitive, but for the threat model here it does not really matter
			if (msg == key) then
				idle_restore();
				if (gconfig_get("lock_ok")) then
					dispatch_symbol(gconfig_get("lock_ok"));
				end
			else
				idle_setup(key, failed + 1);
			end
			iostatem_restore();
		end,
		{}, {label = string.format(
			"Key (%d Failed Attempts):", failed),
			password_mask = gconfig_get("passmask")
		}
	);
	bar.on_cancel = function()
		idle_setup(key, failed);
	end
end

local function lock_value(ctx, val)
-- don't go through the normal input lock as events could then
-- still be forwarded to the selected window, input should trigger
-- lbar that, on escape, immediately jumps into idle state.
	if (durden_input == durden_locked_input) then
		warning("already in locked state, ignoring");
		return;
	end

	durden_input = durden_locked_input;
	iostatem_save();

-- this doesn't allow things like a background image / "screensaver"
	for d in all_tilers_iter() do
		hide_image(d.anchor);
	end

	local fn = gconfig_get("lock_on");
	if (fn) then
		dispatch_symbol(fn);
	end

	idle_setup(val, 0);
end

local reset_query = {
	{
		name = "no",
		label = "No",
		kind = "action",
		handler = function() end
	},
	{
		name = "yes",
		label = "Yes",
		kind = "action",
		dangerous = true,
		handler = function()
			durden_shutdown();
			system_collapse();
		end
	},
};

local function query_dump()
	local bar = tiler_lbar(active_display(), function(ctx, msg, done, set)
		if (done) then
			zap_resource("debug/" .. msg);
			system_snapshot("debug/" .. msg);
		end
		return {};
	end);
	bar:set_label("filename (debug/):");
end

local function spawn_debug_wnd(vid, title)
	show_image(vid);
	local wnd = active_display():add_window(vid, {scalemode = "stretch"});
	wnd:set_title(title);
end

local function gen_displaywnd_menu()
	local res = {};
	for disp in all_displays_iter() do
		table.insert(res, {
			name = "disp_" .. tostring(disp.name),
			handler = function()
				local nsrf = null_surface(disp.tiler.width, disp.tiler.height);
				image_sharestorage(disp.rt, nsrf);
				if (valid_vid(nsrf)) then
					spawn_debug_wnd(nsrf, "display: " .. tostring(k));
				end
			end,
			label = disp.name,
			kind = "action"
		});
	end

	return res;
end

local counter = 0;

local function gettitle(wnd)
	return string.format("%s:%s", wnd.title_prefix and wnd.title_prefix or "unk",
			wnd.title_text and wnd.title_text or "unk");
end

local debug_menu = {
	{
		name = "dump",
		label = "Dump",
		kind = "action",
		handler = query_dump
	},
	-- for testing fallback application handover
	{
		name = "broken",
		label = "Broken Call (Crash)",
		kind = "action",
		handler = function() does_not_exist(); end
	},
	{
		name = "testwnd",
		label = "Color window",
		kind = "action",
		handler = function()
			counter = counter + 1;
			spawn_debug_wnd(
				fill_surface(math.random(200, 600), math.random(200, 600),
					math.random(64, 255), math.random(64, 255), math.random(64, 255)),
				"color_window_" .. tostring(counter)
			);
		end
	},
	{
		name = "worldid_wnd",
		label = "WORLDID window",
		kind = "action",
		handler = function()
			local wm = active_display();
			local newid = null_surface(wm.width, wm.height);
			if (valid_vid(newid)) then
				image_sharestorage(WORLDID, newid);
				spawn_debug_wnd(newid, "worldid");
			end
		end
	},
	{
		name = "display_wnd",
		label = "display_window",
		kind = "action",
		submenu = true,
		eval = function()
			return not gconfig_get("display_simple");
		end,
		handler = gen_displaywnd_menu
	},
	{
		name = "alert",
		label = "Random Alert",
		kind = "action",
		handler = function()
			timer_add_idle("random_alert" .. tostring(math.random(1000)),
				math.random(1000), false, function()
				local tiler = active_display();
				tiler.windows[math.random(#tiler.windows)]:alert();
			end);
		end
	},
	{
		name = "stall",
		label = "Frameserver Debugstall",
		kind = "value",
		eval = function() return frameserver_debugstall ~= nil; end,
		validator = gen_valid_num(0, 100),
		handler = function(ctx,val) frameserver_debugstall(tonumber(val)*10); end
	},
	{
		name = "dump_tree",
		label = "Dump Space-Tree",
		kind = "action",
		eval = function() return active_display().spaces[
			active_display().space_ind] ~= nil; end,
		handler = function(ctx)
			local space = active_display().spaces[active_display().space_ind];
			local fun;
			print("<space>");
			fun = function(node, level)
				print(string.format("%s<node id='%s' horiz=%f vert=%f>",
					string.rep("\t", level), gettitle(node),
					node.weight, node.vweight));
				for k,v in ipairs(node.children) do
					fun(v, level+1);
				end
				print(string.rep("\t", level) .. "</node>");
			end
			fun(space, 0);
			print("</space>");
		end
	}
};

local system_menu = {
	{
		name = "shutdown",
		label = "Shutdown",
		kind = "action",
		submenu = true,
		handler = exit_query
	},
	{
		name = "reset",
		label = "Reset",
		kind = "action",
		submenu = true,
		handler = reset_query
	},
	{
		name = "ouput_msg",
		label = "IPC-Output",
		kind = "value",
		invisible = true,
		validator = function(val) return string.len(val) > 0; end,
		handler = function(ctx, val)
			if (OUTPUT_CHANNEL) then
				OUTPUT_CHANNEL:write(val .. "\n");
			end
		end
	},
	{
		name = "debug",
		label = "Debug",
		kind = "action",
		eval = function() return DEBUGLEVEL > 0; end,
		submenu = true,
		handler = debug_menu,
	},
	{
		name = "lock",
		label = "Lock",
		kind = "value",
		dangerous = true,
		password_mask = gconfig_get("passmask"),
		hint = "(unlock key)",
		validator = function(val) return string.len(val) > 0; end,
		handler = lock_value
	}
};

return system_menu;

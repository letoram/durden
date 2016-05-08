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

			if (msg == key) then
				idle_restore();
			else
				idle_setup(key, failed + 1);
			end
			iostatem_restore();
		end,
		{}, {label = string.format(
			"Key (%d Failed Attempts):", failed), password_mask = true}
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
	for d in all_displays_iter() do
		hide_image(d.anchor);
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
		name = "lock",
		label = "Lock",
		kind = "value",
		dangerous = true,
		password_mask = true,
		hint = "(unlock key)",
		validator = function(val) return string.len(val) > 0; end,
		handler = lock_value
	}
};

if (DEBUGLEVEL > 0) then
	table.insert(system_menu,{
		name = "debug",
		label = "Debug",
		kind = "action",
		submenu = true,
		handler = debug_menu,
	});
end

return system_menu;

local exit_query = {
{
	name = "shutdown_no",
	label = "No",
	kind = "action",
	handler = function() end
},
{
	name = "shutdown_yes",
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
local idle_setup = function(val)
	active_display():set_input_lock(ef);
	timer_add_idle("idle_wakeup", 10, true, ef, function()
		idle_wakeup(val);
	end);
end

local function idle_restore()
	durden_input = durden_normal_input;
	for d in all_displays_iter() do
		show_image(d.anchor);
	end
	active_display():set_input_lock();
end

idle_wakeup = function(key)
	local bar = active_display():lbar(
		function(ctx, msg, done, lastset)
			if (not done) then
				return true;
			end

			if (msg == key) then
				idle_restore();
			else
				idle_setup(key);
			end
			iostatem_restore();
		end,
		{}, {label = "Key:", password_mask = true}
	);
	bar.on_cancel = function()
		idle_setup(key);
	end
end

local function lock_value(ctx, val)
-- don't go through the normal input lock as events could then
-- still be forwarded to the selected window, input should trigger
-- lbar that, on escape, immediately jumps into idle state.
	durden_input = durden_locked_input;
	iostatem_save();

-- this doesn't allow things like a background image / "screensaver"
	for d in all_displays_iter() do
		hide_image(d.anchor);
	end

	idle_setup(val);
end

local reset_query = {
	{
		name = "reset_no",
		label = "No",
		kind = "action",
		handler = function() end
	},
	{
		name = "reset_yes",
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
		name = "query_dump",
		label = "Dump",
		kind = "action",
		handler = query_dump
	},
	-- for testing fallback application handover
	{
		name = "debug_broken",
		label = "Broken Call (Crash)",
		kind = "action",
		handler = function() does_not_exist(); end
	},
	{
		name = "debug_stall",
		label = "Frameserver Debugstall",
		kind = "value",
		eval = function() return frameserver_debugstall ~= nil; end,
		validator = gen_valid_num(0, 100),
		handler = function(ctx,val) frameserver_debugstall(tonumber(val)); end
	}
};

local system_menu = {
	{
		name = "shutdown",
		label = "Shutdown",
		kind = "action",
		submenu = true,
		hint = "Shutdown?",
		handler = exit_query
	},
	{
		name = "reset",
		label = "Reset",
		kind = "action",
		submenu = true,
		hint = "Reset?",
		handler = reset_query
	},
	{
		name = "lock",
		label = "Lock",
		kind = "value",
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
		hint = "Debug:",
		handler = debug_menu,
	});
end

return system_menu;

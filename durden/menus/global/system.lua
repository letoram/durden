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
	description = "This will close external connections, any unsaved data will be lost",
	kind = "action",
	dangerous = true,
	handler = function() shutdown(); end
},
{
	name = "silent",
	label = "Silent",
	description = "Shutdown, but don't tell external connections to terminate",
	kind = "action",
	dangerous = true,
	handler = function() shutdown("", EXIT_SILENT); end
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

	active_display():set_input_lock(ef, "idle");
	timer_add_idle("idle_wakeup", 10, true, ef, function()
		idle_wakeup(val, failed);
	end);
end

local function idle_restore()
	durden_input_sethandler()
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
			failed > 0 and
				"Enter Unlock Key (%d Failed Attempts):" or
				"Enter Unlock Key:", failed),
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
	if (not durden_input_sethandler(durden_locked_input, "global/system/lock")) then
		return;
	end

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

local function gen_appl_menu()
	local res = {};
	local tbl = glob_resource("*", SYS_APPL_RESOURCE);
	for i,v in ipairs(tbl) do
		table.insert(res, {
			name = "switch_" .. tostring(i);
			label = v,
			description = "Change the active set of scripts, data or external clients may be lost",
			dangerous = true,
			kind = "action",
			handler = function()
				durden_shutdown();
				system_collapse(v);
			end,
		});
	end
	return res;
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
		description = "Reset / Reload Durden? Unsaved data may be lost",
		kind = "action",
		dangerous = true,
		handler = function()
			durden_shutdown();
			system_collapse();
		end
	},
	{
		name = "switch",
		label = "Switch Appl",
		kind = "action",
		description = "Change the currently active window management scripts",
		submenu = true,
		eval = function() return #glob_resource("*", SYS_APPL_RESOURCE) > 0; end,
		handler = gen_appl_menu
	}
};

local counter = 0;

local system_menu = {
	{
		name = "shutdown",
		label = "Shutdown",
		kind = "action",
		submenu = true,
		description = "Perform a clean shutdown",
		handler = exit_query
	},
	{
		name = "reset",
		label = "Reset",
		kind = "action",
		submenu = true,
		description = "Rebuild the WM state machine",
		handler = reset_query
	},
	{
		name = "status_msg",
		label = "Status-Message",
		kind = "value",
		invisible = true,
		description = "Add a custom string to the statusbar message area",
		validator = function(val) return true; end,
		handler = function(ctx, val)
			active_display():message(val and val or "");
		end
	},
	{
		name = "debug",
		label = "Debug",
		kind = "action",
		eval = function() return DEBUGLEVEL > 0; end,
		submenu = true,
		handler = system_load("menus/global/debug.lua")(),
	},
	{
		name = "lock",
		label = "Lock",
		kind = "value",
		description = "Query for a temporary unlock key and then lock the display",
		dangerous = true,
		password_mask = gconfig_get("passmask"),
		hint = "(unlock key)",
		validator = function(val) return string.len(val) > 0; end,
		handler = lock_value
	}
};

return system_menu;

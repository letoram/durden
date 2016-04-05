local function list_timers(tag, hfun, group, active)
	local names = timer_list(group, active);
	local res = {};
	for k,v in ipairs(names) do
		table.insert(res, {
			name = "t_" .. tag .. "v",
			label = v,
			handler = function() hfun(v); end,
			kind = "action"
		});
	end

	return res;
end

local function timerval(val)
	local num = tonumber(val);
	return num ~= nil and num > 0;
end

local function menu_spawn(cb)
	IN_CUSTOM_BIND = true;
	launch_menu_hook(
		function(path)
			IN_CUSTOM_BIND = false;
			launch_menu_hook(nil);
			cb(path, true);
		end
	);

	local ctx = grab_global_function("global_actions")();
	ctx.on_cancel = function()
		IN_CUSTOM_BIND = false;
		launch_menu_hook(nil);
		cb("", false);
	end
end

local function run_menu(cb, name, doublefun)
	IN_CUSTOM_BIND = true;
	menu_spawn(
	function(path, ok)
		if (not ok) then
			return;
		end

		if (doublefun) then
			menu_spawn(function(path2, ok)
				if (ok) then
					cb(name, path, path2);
				end
			end);
		else
			cb(name, path);
		end
	end
	);
end

local function query_timer_name(cb, doublefun)
	suppl_run_value({
		name = "add_cv",
		hint = "(Name)",
		kind = "value",
		validator = function(val)
			return val and string.len(val) > 0;
		end,
-- get slightly messy here as we want to query two paths,
-- one for timer and one optional for wakeup
		handler = function(ctx, val)
			run_menu(cb, val, doublefun);
		end
	});
end

local function setup_idle(name, val, p1, p2, once)
	timer_add_idle(name, tonumber(val) * CLOCKRATE, once,
		function()
			launch_menu_path(active_display(),
			grab_global_function("global_actions"), p1);
		end,
		p2 and
		function()
			launch_menu_path(active_display(),
			grab_global_function("global_actions"), p2);
		end or nil
	);
end

local timer_add = {
	{
		name = "add_period",
		label = "Periodic",
		hint = "(Period, seconds)",
		kind = "value",
		validator = function(val)
			local num = tonumber(val);
			return num and num > 0;
		end,
		handler = function(ctx, val)
			query_timer_name(
				function(name, p1)
					timer_add_periodic(name, tonumber(val) * CLOCKRATE, false, function()
						launch_menu_path(active_display(),
						grab_global_function("global_actions"), p1);
					end);
				end, false
			);
		end
	},
	{
		name = "add_once",
		label = "Once",
		hint = "(Delay, seconds)",
		kind = "value",
		validator = function(val)
			local num = tonumber(val);
			return num and num > 0;
		end,
		handler = function(ctx, val)
			query_timer_name(
				function(name, p1)
					timer_add_periodic(name, tonumber(val) * CLOCKRATE, true, function()
						launch_menu_path(active_display(),
						grab_global_function("global_actions"), p1);
					end);
				end, false
			);
		end
	},
	{
		name = "add_idle",
		hint = "(Idle time, seconds)",
		label = "Idle",
		kind = "value",
		validator = timerval,
		handler = function(ctx, val)
			query_timer_name(
				function(name, p1, p2)
					setup_idle(name, val, p1, p2, false);
				end, true
			);
		end
	},
	{
		name = "add_idle_once",
		hint = "(Idle time, seconds)",
		label = "Idle-Once",
		kind = "value",
		validator = timerval,
		handler = function(ctx, val)
			query_timer_name(
				function(name, p1, p2)
					setup_idle(name, val, p1, p2, true);
				end, true
			);
		end
	}
};

return {
	{
		name = "delete",
		label = "Delete",
		kind = "action",
		submenu = true,
		eval = function() return #timer_list() > 0; end,
		handler = function()
			return list_timers("delete", function(name) timer_delete(name); end);
		end
	},
	{
		name = "suspend",
		label = "Suspend",
		kind = "action",
		submenu = true,
		eval = function() return #timer_list(nil, true) > 0; end,
		handler = function()
			return list_timers("suspend", function(name)
				timer_suspend(name); end, nil, true);
		end
	},
	{
		name = "resume",
		label = "Resume",
		kind = "action",
		submenu = true,
		eval = function() return #timer_list(nil, false) > 0; end,
		handler = function()
			return list_timers("resume", function(name)
				timer_resume(name); end, nil, false);
		end
	},
	{
		name = "add",
		label = "Add",
		kind = "action",
		submenu = true,
		handler = timer_add
	},
	{
		name = "block_idle",
		label = "Block Idle",
		kind = "action",
		eval = function() return timer_mask_idle() == false; end,
		handler = function() timer_mask_idle(true); end
	},
	{
		name = "unblock_idle",
		label = "Unblock Idle",
		kind = "action",
		eval = function() return timer_mask_idle() == true; end,
		handler = function() timer_mask_idle(false); end
	}
};

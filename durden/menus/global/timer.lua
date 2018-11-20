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

local function query_timer_name(n, cb)
	local paths = {};
	local bind_fun;
	bind_fun = function(path)
		if (not path) then
			return;
		end
		n = n - 1;
		table.insert(paths, path);
		if (n > 0) then
			dispatch_symbol_bind(bind_fun);
		else
			cb(paths);
		end
	end

	dispatch_symbol_bind(bind_fun);
end

local timer_hint = "(name:seconds)";

local function timer_valid(str)
	if (not str or string.len(str) == 0 or str == ":") then
		return false;
	end
	local pos, stop = string.find(str, ":", 1);
	if (not pos) then
		return false;
	end
	local time = string.sub(str, stop + 1);
	return tonumber(time) ~= nil;
end

local function parse_timer(str)
	local pos, stop = string.find(str, ":", 1);
	local name = string.sub(str, 1, pos-1);
	local time = string.sub(str, stop+1);
	return tonumber(time) * CLOCKRATE, name;
end

local timer_add = {
	{
		name = "add_period",
		label = "Periodic",
		hint = timer_hint,
		kind = "value",
		interactive = true,
		description = "Add a periodic timer that repeats after a certain amount of time",
		validator = timer_valid,
		handler = function(ctx, val)
			local period, name = parse_timer(val);
			query_timer_name(1,
				function(paths)
					timer_add_periodic(name, period, false,
					function()
						dispatch_symbol(paths[1])
					end);
				end);
		end
	},
	{
		name = "add_once",
		label = "Once",
		hint = timer_hint,
		kind = "value",
		description = "Add a one-time timer that is removed after activation",
		interactive = true,
		validator = timer_valid,
		handler = function(ctx, val)
			local period, name = parse_timer(val);
			query_timer_name(1,
				function(paths)
					timer_add_periodic(name, period, true,
					function()
						dispatch_symbol(paths[1]);
					end);
				end
			);
		end
	},
	{
		name = "add_idle",
		hint = timer_hint,
		label = "Idle",
		kind = "value",
		interactive = true,
		description = "Activate a path and mark you as idle after a certain amount of time",
		validator = timer_valid,
		handler = function(ctx, val)
			local period, name = parse_timer(val);
			query_timer_name(2,
				function(paths)
					timer_add_idle(name, period, false,
						function() dispatch_symbol(paths[1]); end,
						function() dispatch_symbol(paths[2]); end, false
					);
			end);
		end
	},
	{
		name = "add_idle_once",
		hint = timer_hint,
		label = "Idle-Once",
		description = "Activate a path, mark you as idle and then remove the timer after returning",
		kind = "value",
		interactive = true,
		validator = timer_valid,
		handler = function(ctx, val)
			local period, name = parse_timer(val);
			query_timer_name(2,
				function(paths)
					timer_add_idle(name, period, true,
						function() dispatch_symbol(paths[1]); end,
						function() dispatch_symbol(paths[2]); end, false
					);
				end
			);
		end
	}
};

local function clone_entry(tbl, suffix)
	local res = {
	};
	for k,v in pairs(tbl) do
		if k == "name" then
			res[k] = v .. suffix;
		end

	end
end

return {
	{
		name = "delete",
		label = "Delete",
		kind = "action",
		description = "Delete the active timer",
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
		description = "Temporarily suspend the timer progression",
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
		description = "Resume timer progression",
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
		description = "Add a new timer",
		submenu = true,
		handler = timer_add
	},
	{
		name = "block_idle",
		label = "Block Idle",
		kind = "action",
		description = "Block all idle timers without removing them",
		eval = function() return timer_mask_idle() == false; end,
		handler = function() timer_mask_idle(true); end
	},
	{
		name = "unblock_idle",
		label = "Unblock Idle",
		kind = "action",
		description = "Unblock all idle timers",
		eval = function() return timer_mask_idle() == true; end,
		handler = function() timer_mask_idle(false); end
	}
};

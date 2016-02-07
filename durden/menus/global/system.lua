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
		handler = function() system_collapse(); end
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

register_global("query_exit", query_exit);
register_global("exit", shutdown);
register_global("query_reset", query_reset);
register_global("reset", function() system_collapse(APPLID); end);

return system_menu;

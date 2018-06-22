local function shared_reset(wnd)
	if (valid_vid(wnd.external, TYPE_FRAMESERVER)) then
		reset_target(wnd.external);
	end
end

local function gen_load_menu()
	local res = {};
	local lst = glob_resource("*", APPL_STATE_RESOURCE);
	for i,v in ipairs(lst) do
		table.insert(res, {
			label = v,
			name = "load_" .. util.hash(v),
			kind = "action",
			handler = function(ctx)
				restore_target(active_display().selected.external, v);
			end
		});
	end
	return res;
end

return {
	{
		name = "suspend",
		label = "Suspend",
		kind = "action",
		description = "Block frame-transfers and request that the client enter a wait state",
		handler = function()
			active_display().selected:set_suspend(true);
		end
	},
	{
		name = "resume",
		label = "Resume",
		kind = "action",
		description = "Unblock frame-transfers and request that the client resumes processing",
		handler = function()
			active_display().selected:set_suspend(false);
		end
	},
	{
		name = "toggle",
		label = "Toggle",
		kind = "action",
		description = "Toggle between suspend and resume state",
		handler = function()
			active_display().selected:set_suspend();
		end
	},
	{
		name = "reset",
		label = "Reset",
		kind = "action",
		dangerous = true,
		description = "Request that the client soft-resets to an initial state",
		handler = shared_reset
	},
	{
		name = "load",
		label = "Load",
		kind = "action",
		submenu = true,
		description = "Send a previous save state to the client",
		eval = function()
			return (#glob_resource("*", APPL_STATE_RESOURCE)) > 0;
		end,
		handler = function(ctx, v)
			return gen_load_menu();
		end
	},
	{
		name = "save",
		label = "Save",
		kind = "value",
		submenu = true,
		initial = "",
		description = "Allocate a state store and send to the client for writing",
		validator = function(str) return str and string.len(str) > 0; end,
		prefill = "testy_test",
		handler = function(ctx, val)
			snapshot_target(active_display().selected.external, val);
		end,
		eval = function()
			local wnd = active_display().selected;
			return active_display().selected.stateinf ~= nil;
		end
	}
};

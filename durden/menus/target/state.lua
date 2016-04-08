local function shared_reset(wnd)
	if (wnd.external) then
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

local function find_sibling(wnd)
-- enumerate all windows, if stateinf exist and stateids match
-- and we are not ourself, then we have a sibling...
end

return {
	{
		name = "suspend",
		label = "Suspend",
		kind = "action",
		handler = function()
			active_display().selected:set_suspend(true);
		end
	},
	{
		name = "resume",
		label = "Resume",
		kind = "action",
		handler = function()
			active_display().selected:set_suspend(false);
		end
	},
	{
		name = "reset",
		label = "Reset",
		kind = "action",
		dangerous = true,
		handler = shared_reset
	},
	{
		name = "load",
		label = "Load",
		kind = "action",
		submenu = true,
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

local function shared_reset(wnd)
	if (wnd.external) then
		reset_target(wnd.external);
	end
end

local function find_sibling(wnd)
-- enumerate all windows, if stateinf exist and stateids match
-- and we are not ourself, then we have a sibling...
end

return {
	{
		name = "shared_suspend",
		label = "Suspend",
		kind = "action",
		handler = function()
			active_display().selected:set_suspend(true);
		end
	},
	{
		name = "shared_resume",
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
		name = "state_load",
		label = "Restore",
		kind = "action",
		submenu = true,
		eval = function()
			warning("glob state: state_prefix");
		end,
		handler = function(ctx, v)
			warning("grab wnd, target_load from resname");
		end
	},
	{
		name = "state_save",
		label = "Save",
		kind = "action",
		submenu = true,
		handler = function()
			warning("missing: query state name");
			return {};
		end,
		eval = function()
			local wnd = active_display().selected;
			return active_display().selected.stateinf ~= nil;
		end
	},
	{
		name = "state_import",
		label = "Import",
		kind = "action",
		handler = function()
			local wnd = active_display().selected;
			local subid = find_sibling(wnd);
			if (subid) then
			else
				wnd:message("Couldn't import state, sibling missing.");
			end
		end,
		eval = function()
			return find_sibling();
		end
	}
};

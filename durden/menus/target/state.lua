local function shared_reset(wnd)
	if (wnd.external) then
		reset_target(wnd.external);
	end
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
-- return active_display().selected.statinf ~= nil;
			return false;
		end
	},
};



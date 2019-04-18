--
-- This file can be added to run custom commands at startup,
-- helpful commands:

-- timer_add_idle(name (text), value (seconds), once (bool), enterfn, exitfn)
-- timer_add_periodic(name, delay, once (bool), commandfn)
--
-- symbol paths can be found using arcan durden dump_menus though
--
-- dispatch_symbol("/global/display/target/rescan")
-- active_display().selected gives you a reference handle to the current window
--

-- look after all targets tagged 'autorun' and launch them internally
for i,v in pairs(list_targets()) do
	local tags = list_target_tags(v);
	for i,j in ipairs(tags) do
		if (f == "autorun") then
			break;
		end
	end
end

dispatch_symbol("/global/settings/statusbar/add_external=tray")

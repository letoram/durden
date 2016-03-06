--
-- This file can be added to run custom commands at startup,
-- helpful commands:

-- timer_add_idle(name (text), value (seconds), once (bool), enterfn, exitfn)
-- timer_add_periodic(name, delay, once (bool), commandfn)
--
-- symbol paths can be found using arcan durden dump_menus though
--
-- dispatch_symbol("!display/target/rescan")
-- active_display().selected gives you a reference handle to the current window
--

-- hack timer patched when some state need to be monitored as part of debugging,
-- can be safely removed / ignored of course
if (DEBUGLEVEL > 1) then
	timer_add_periodic("debugstat", 1, false, function()
		local m1, m2 = dispatch_meta();
		local total, used = current_context_usage();
		local period, delay, counter = iostatem_state();

		local wndapp = "";
		local wnd = active_display().selected;

-- mstate, keyboardstate, clipboard mode, global gain

		active_display():message(string.format(
			"[SYS:vid-use(%d/%d),mevh(%d),meta(%d, %d),iostate(%d, %d, %d)] %s",
			used, total, mouse_handlercount(), m1 and 1 or 0, m2 and 1 or 0,
			period, delay, counter, wndapp
		));
	end);
end

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
	local periodic_msg = "";
	timer_add_periodic("debugstat", 1, false, function()
		local m1, m2 = dispatch_meta();
		local total, used = current_context_usage();

		local wndapp = "none";
		local wnd = active_display().selected;
		if (wnd) then
			local sp = image_storage_properties(wnd.canvas);
			wndapp = string.format("gain: %.2f, w/h: %.2f/%.2f, effw/h: %.2f, " ..
				"%.2f s_w/h: %.2f, %.2f, type: %s, pastemode: %s", wnd.gain, wnd.width,
				wnd.height, wnd.effective_w, wnd.effective_h, sp.width, sp.height, wnd.atype and
				wnd.atype or "unknown", wnd.pastemode and wnd.pastemode or "unknown");
		end

		local iostate_dbg = iostatem_debug();

		local new_msg = string.format(
			"wnd: [%s] [SYS:vid-use(%d/%d),mevh(%d),meta(%d, %d),iostate(%s)]",
			wndapp, used, total, mouse_handlercount(), m1 and 1 or 0, m2 and 1 or 0,
			iostate_dbg and iostate_dbg or "(iostate-brk)"
		);
		if (new_msg ~= periodic_msg) then
			active_display():message(new_msg);
			periodic_msg = new_msg;
		end
	end);
end

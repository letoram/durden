--
-- Clipboard- primary segment bridge
--
return {
	atype = "clipboard-paste",
	default_shader = {"simple", "noalpha"},
	actions = {
	},
-- props will be projected upon the window during setup (unless there
-- are overridden defaults)
	props = {
	},
	intercept = function(tbl, wnd, source, tbl)
		if (gconfig_get("clipboard_access") == "none" or
			gconfig_get("clipboard_access") == "active") then
			active_display():message(
				"rejected clipboard monitor connection attempt");
			return false;
		end

-- set us as the clipboard monitor, protect against danglers,
-- try to dump the entire history (whatever that is)
		CLIPBOARD:set_monitor(function(msg, done)
			if (done) then
				if (wnd.destroy) then
					wnd:destroy();
				elseif (valid_vid(source)) then
					delete_image(source);
				end
				return;
			end
			print("paste:", msg);
		end);

-- only manage lifecycle, and guard against the wnd being destroyed out-of-band
		target_updatehandler(source,
		function(src, stat)
			if (stat.kind == "terminated") then
				if (wnd.destroy) then
					wnd:destroy();
				else
					delete_image(src);
				end
			end
		end);
		return true;
	end,
	dispatch = {
	}
};

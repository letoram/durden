--
-- Clipboard- primary segment bridge
--
return {
	atype = "clipboard",
	default_shader = {"simple", "noalpha"},
	actions = {
	},
-- props will be projected upon the window during setup (unless there
-- are overridden defaults)
	props = {
	},
	intercept = function(ctx, wnd, source, tbl)
		if (gconfig_get("clipboard_access") == "none" or
			gconfig_get("clipboard_access") == "passive") then
			active_display():message(
				"rejected clipboard injection connection attempt");
			return false;
		end

		target_updatehandler(source,
			function(src, stat)
				if (stat.kind == "terminated") then
					delete_image(source);
				elseif (stat.kind == "message") then
					CLIPBOARD:add(source, stat.message, stat.multipart);
				end
			end
		)
		return true;
	end,
-- won't be used
	dispatch = {
	}
};

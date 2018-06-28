--
-- quick and dirty first notification controls, more will come as part of
-- widgets and tools, yet the path is provided so that they can reigster
-- here.
--
return {
	{
		name = "enable",
		label = "Enable",
		kind = "value",
		description = "Enable tools and widgets to receive event notifications",
		set = {LBL_YES, LBL_NO, LBL_FLIP},
		initial = function() return
			gconfig_get("hide_titlebar") and LBL_YES or LBL_NO end,
		handler = suppl_flip_handler("hide_titlebar")
	},
	{
		name = "send",
		label = "Send",
		kind = "value",
		hint = "severity(0..3):name(str):short(str)[:long(str)]",
		description = "Emitt a notification",
		validator = function(val)
			if (not val or string.len(val) == 0) then
				return false;
			end
			local lst = string.split(val, ":");
			if (not lst or #lst < 3) then
				return false;
			end
			local sev = tonumber(lst[1]);
			if (not sev or sev < 0 or sev > 3) then
				return false;
			end
			if (string.len(lst[2]) == 0 or string.len(lst[3]) == 0) then
				return false;
			end
			return true;
		end,
		handler = function(ctx, val)
			local lst = string.split(val, ":");
			local sev = tonumber(lst[1]);
			notification_add(lst[2], lst[3], lst[4], sev);
		end
	}
};

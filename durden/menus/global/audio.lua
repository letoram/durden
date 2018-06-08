local function allgain(val)
	audio_gain(BADID, val);
	for wnd in all_windows() do
		if (wnd.source_audio) then
			audio_gain(wnd.source_audio,
				val * (wnd.gain and wnd.gain or 1.0),
		  	gconfig_get("gain_fade"));
		end
	end
end

return {
	{
		name = "enabled",
		label = "Enabled",
		kind = "value",
		set = {LBL_YES, LBL_NO, LBL_FLIP},
		description = "Set audio-enable state globally",
		initial = function() return gconfig_get("global_mute"); end,
		handler = function(ctx, val)
			if (val == LBL_FLIP) then
				val = not gconfig_get("global_mute");
			else
				val = val == LBL_YES;
			end
			allgain(val and 0.0 or gconfig_get("global_gain"));
			gconfig_set("global_mute", val);
		end
	},
	{
		name = "volume",
		label = "Volume",
		kind = "action",
		hint = "(0..1)",
		kind = "value",
		description = "Change the global audio volume",
		validator = shared_valid01_float,
		initial = function()
			return tostring(gconfig_get("global_gain"));
		end,
		handler = function(ctx, val)
			gconfig_set("global_gain", tonumber(val));
			if (not gconfig_get("global_mute")) then
				allgain(gconfig_get("global_gain"));
			end
		end
	},
	{
		name = "vol_p10",
		label = "+10%",
		kind = "action",
		description = "Increment the global audio volume by 10%",
		handler = function()
			local gainv = gconfig_get("global_gain");
			gainv = math.clamp(gainv + 0.1, 0.0, 1.0);
			gconfig_set("global_gain", gainv);
			if (not gconfig_get("global_mute")) then
				allgain(gainv);
			end
		end
	},
	{
		name = "vol_n10",
		label = "-10%",
		kind = "action",
		description = "Decrement the global audio volume by 10%",
		handler = function()
			local gainv = gconfig_get("global_gain");
			gainv = math.clamp(gainv - 0.1, 0.0, 1.0);
			gconfig_set("global_gain", gainv);
			if (not gconfig_get("global_mute")) then
				allgain(gainv);
			end
		end
	}
};

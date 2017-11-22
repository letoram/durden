return {
	{
		name = "toggle",
		label = "Toggle On/Off",
		kind = "action",
		description = "Toggle all audio playback",
		handler = grab_global_function("toggle_audio")
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
			grab_global_function("global_gain")(tonumber(val));
		end
	},
	{
		name = "vol_p10",
		label = "+10%",
		kind = "action",
		description = "Increment the global audio volume by 10%",
		handler = function()
			grab_global_function("gain_stepv")(0.1);
		end
	},
	{
		name = "vol_n10",
		label = "-10%",
		kind = "action",
		description = "Decrement the global audio volume by 10%",
		handler = function()
			grab_global_function("gain_stepv")(-0.1);
		end
	}
};

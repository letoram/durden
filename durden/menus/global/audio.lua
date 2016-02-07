return {
	{
		name = "toggle_audio",
		label = "Toggle On/Off",
		kind = "action",
		handler = grab_global_function("toggle_audio")
	},
	{
		name = "global_gain",
		label = "Global Gain",
		kind = "action",
		hint = "(0..1)",
		kind = "value",
		validator = shared_valid01_float,
		initial = function()
			return tostring(gconfig_get("global_gain"));
		end,
		handler = function(ctx, val)
			grab_global_function("global_gain")(tonumber(val));
		end
	},
	{
		name = "gain_pos10",
		label = "+10%",
		kind = "action",
		handler = function()
			grab_global_function("gain_stepv")(0.1);
		end
	},
	{
		name = "gain_neg10",
		label = "-10%",
		kind = "action",
		handler = function()
			grab_global_function("gain_stepv")(-0.1);
		end
	}
};

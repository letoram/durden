local function gain_stepv(gainv, abs)
	local wnd = active_display().selected;
	if (not wnd or not wnd.source_audio) then
		return;
	end

	if (not abs) then
		gainv = gainv + (wnd.gain and wnd.gain or 1.0);
	end

	gainv = gainv < 0.0 and 0.0 or gainv;
	gainv = gainv > 1.0 and 1.0 or gainv;
	gainv = gainv * gconfig_get("global_gain");
	wnd.gain = gainv;
	audio_gain(wnd.source_audio, gainv, gconfig_get("gain_fade"));
end

return {
	{
		name = "toggle",
		label = "Toggle On/Off",
		kind = "action",
		description = "Toggle audio playback on/off for this window",
		handler = grab_shared_function("toggle_audio")
	},
	{
		name = "vol_p10",
		label = "+10%",
		kind = "action",
		description = "Increment local volume by 10%",
		handler = function() gain_stepv(0.1); end
	},
	{
		name = "vol_n10",
		label = "-10%",
		kind = "action",
		description = "Decrement local volume by 10%",
		handler = function() gain_stepv(-0.1); end
	},
	{
		name ="vol_set",
		label = "Volume",
		hint = "(0..1)",
		kind = "value",
		description = "Set the volume level to a specific value",
		validator = shared_valid01_float,
		handler = function(ctx, val) gain_stepv(tonumber(val), true); end
	},
};

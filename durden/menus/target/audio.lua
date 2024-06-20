local function gain_stepv(gainv, abs)
	local wnd = active_display().selected;
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
		handler = function()
			local wnd = active_display().selected;
			if (wnd.save_gain) then
				wnd.gain = wnd.save_gain;
				audio_gain(wnd.source_audio, gconfig_get("global_gain") * wnd.gain);
				wnd.save_gain = nil;
			else
				wnd.save_gain = wnd.gain;
				wnd.gain = 0.0;
				audio_gain(wnd.source_audio, 0.0);
			end
		end
	},
	{
		name = "position",
		label = "Position",
		kind = "value",
		hint = "(x y z dt)(0..200)",
		validator = suppl_valid_typestr("ffff", 0, 200, 0),
		description = "Move window audio playback to a specific room point",
		eval = function()
			return audio_listener ~= nil;
		end,
		handler = function(ctx, val)
			local arg = suppl_unpack_typestr("ffff", val, 0, 200)
			local wnd = active_display().selected;
			if not valid_vid(wnd.external) or not arg then
				return
			end

			if not valid_vid(wnd.audio_anchor) then
				wnd.audio_anchor = null_surface(1, 1)
				link_image(wnd.audio_anchor, wnd.anchor)
				image_mask_set(wnd.audio_anchor, MASK_POSITION)
			end
			move3d_model(wnd.audio_anchor, unpack(arg))
			audio_listener(wnd.source_audio, wnd.audio_anchor)
		end,
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

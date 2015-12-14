--
-- Decode archetype, settings and menus specific for decode- frameserver
-- session (e.g. stream selection, language, subtitle overlays)
--
local rtbl = {
	atype = "multimedia",
	actions = {
	},
	bindings = {},
	dispatch = {
-- special case, FFT packed in video stream and unpacked by shader,
		streaminfo = function(wnd, source, tbl)
			if (tbl.lang == "AUD") then
				wnd.shaderflt = {"fft"};
				wnd.scalemode = "stretch";
				local lst = shader_list(wnd.shaderflt);
				if (#lst > 0) then
					shader_setup(wnd, shader_getkey(lst[1]));
				end
			end
		end
	},
	props = {
		kbd_period = 0,
		kbd_delay = 0,
		scalemode = "aspect",
		filtermode = FILTER_BILINEAR,
		clipboard_block = true
	},
};

rtbl.bindings["LEFT"] = function(wnd)
	if (valid_vid(wnd.external, TYPE_FRAMESERVER)) then
		target_seek(wnd.external, -10);
	end
end

rtbl.bindings["UP"] = function(wnd)
	if (valid_vid(wnd.external, TYPE_FRAMESERVER)) then
		target_seek(wnd.external, 100);
	end
end

rtbl.bindings["RIGHT"] = function(wnd)
	if (valid_vid(wnd.external, TYPE_FRAMESERVER)) then
		target_seek(wnd.external, 10);
	end
end

rtbl.bindings["DOWN"] = function(wnd)
	if (valid_vid(wnd.external, TYPE_FRAMESERVER)) then
		target_seek(wnd.external, -100);
	end
end

return rtbl;

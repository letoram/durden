local function inputh(wnd, source, status)
	if (status.kind == "terminated") then
		wnd:destroy();
	else
	end
end

return function(val)
	suppl_region_select(255, 255, 0,
	function(x1, y1, x2, y2)
		local dw = x2 - x1;
		local dh = y2 - y1;
		if (dw % 2 > 0) then
			x2 = x2 + 1;
		end

		if (dh % 2 > 0) then
			y2 = y2 + 1;
		end

		local dvid, vgrp, agrp = suppl_region_setup(x1, y1, x2, y2, true, false);
		show_image(dvid);
		local wnd = active_display():add_window(dvid, {scalemode = "stretch"});
		local infn = function(source, status)
			inputh(wnd, source, status);
		end

		local argstr, srate, fn = suppl_build_recargs(vgrp, agrp, false, val);
		define_recordtarget(dvid, fn, argstr, vgrp, agrp,
			RENDERTARGET_DETACH, RENDERTARGET_NOSCALE, srate, infn);
		wnd:set_title("recording");
	end);
end

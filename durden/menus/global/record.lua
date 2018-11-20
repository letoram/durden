local function inputh(wnd, source, status)
	if (status.kind == "terminated") then
		if (wnd.destroy) then
			wnd:destroy();
		else
			delete_image(source);
		end
	end
end

return function(val, lbl)
	suppl_region_select(255, 255, 0,
	function(x1, y1, x2, y2)
		x1 = math.floor(x1);
		y1 = math.floor(y1);
		x2 = math.ceil(x2);
		y2 = math.ceil(y2);

		local dw = x2 - x1;
		local dh = y2 - y1;

		if (dw % 2 > 0) then
			x2 = x2 + 1;
		end

		if (dh % 2 > 0) then
			y2 = y2 + 1;
		end

		local dvid, vgrp, agrp = suppl_region_setup(x1, y1, x2, y2, true, false);
		if (not valid_vid(dvid)) then
			return;
		end
		show_image(dvid);

-- bind to a timer so the window gets set up outside of the callback,
-- this is important due to the feedback loop with the attach hook in advfloat
-- reusing the suppl_region..

		timer_add_periodic("recwnd" .. tostring(CLOCK), 2, true, function()
			local wnd = active_display():add_window(dvid, {scalemode = "stretch"});
			local infn = function(source, status)
				inputh(wnd, source, status);
			end

			if (type(val) == "number" and valid_vid(val)) then
				define_recordtarget(dvid, val, "", vgrp, agrp,
					RENDERTARGET_DETACH, RENDERTARGET_NOSCALE, -1, infn);
					wnd:set_title("forwarding("..lbl..")");
			else
				local argstr, srate, fn = suppl_build_recargs(vgrp, agrp, false, val);
				define_recordtarget(dvid, fn, argstr, vgrp, agrp,
					RENDERTARGET_DETACH, RENDERTARGET_NOSCALE, srate, infn);
				wnd:set_title("recording");
			end
		end, true);
	end);
end

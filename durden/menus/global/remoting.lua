local function inputh(wnd, source, status)
	if (status.kind == "terminated") then
		wnd:destroy();
	else
-- alert about connections, route / forward input, map
-- cursor motion to window surface, ...
	end
end

return function()
	suppl_region_select(127, 255, 64,
	function(x1, y1, x2, y2)
		local dvid, vgrp, agrp = suppl_region_setup(x1, y1, x2, y2, true, false);
		show_image(dvid);
		local wnd = active_display():add_window(dvid, {scalemode = "stretch"});
		local infn = function(source, status)
			inputh(wnd, source, status);
		end
		define_recordtarget(dvid, "stream", string.format(
			"protocol=vnc:port=%d:pass=%s", gconfig_get("remote_port"),
			gconfig_get("remote_pass")), vgrp, agrp,
			RENDERTARGET_DETACH, RENDERTARGET_NOSCALE, -1, infn);
		wnd:set_title(string.format("shared(%d,%s)", gconfig_get("remote_port"),
			gconfig_get("remote_pass")));
	end);
end

return function()
	local wnd = active_display().selected;
	if (not wnd) then
		return;
	end

	local x, y = mouse_xy();
-- warp the mouse to use that as the positioning
	mouse_absinput_masked(
		wnd.x + wnd.pad_left, wnd.y + wnd.pad_top, true);

	local r, g, b = suppl_hexstr_to_rgb(HC_PALETTE[1]);
	suppl_region_select(
		r, g, b,
		function(x1, y1, x2, y2)
-- protect against toctu
			if (not wnd or not wnd.move) then
				return;
			end

			local w = x2 - x1;
			local h = y2 - y1;

			if valid_vid(wnd.external) then
				wnd:displayhint(w, h, wnd.dispmask);
			else
				wnd:resize_effective(w, h);
			end

			mouse_absinput_masked(x, y, true);
		end
	);

	mouse_absinput(
		wnd.x + wnd.pad_left + wnd.effective_w,
		wnd.y + wnd.pad_top + wnd.effective_h
	)
end

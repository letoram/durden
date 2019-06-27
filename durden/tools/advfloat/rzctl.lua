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

			x1 = x1 - wnd.pad_left;
			y1 = y1 - wnd.pad_top;

			wnd:move(x1, y1, false, true);
			local w = x2 - x1;
			local h = y2 - y1;
			wnd:resize(w, h);
			mouse_absinput_masked(x, y, true);
		end
	);
end

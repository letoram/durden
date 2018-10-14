return function()
	local wnd = active_display().selected;
	if (not wnd) then
		return;
	end

-- warp the mouse to use that as the positioning
	mouse_absinput_masked(
		wnd.x + wnd.pad_left, wnd.y + wnd.pad_top, true);

	suppl_region_select(
		128, 168, 128,
		function(x1, y1, x2, y2)
-- protect against tocu
			if (not wnd or not wnd.move) then
				return;
			end

			x1 = x1 - wnd.pad_left;
			y1 = y1 - wnd.pad_top;

			wnd:move(x1, y1, false, true);
			local w = x2 - x1;
			local h = y2 - y1;
			wnd:resize(w, h);
		end
	);
end

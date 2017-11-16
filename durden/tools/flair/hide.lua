local function scale_effect(wm, wnd, x, y, w, h, hide)
	local dx, dy, dw, dh, dopa;
	dx = x; dy = y; dw = w; dh = h; dopa = 0.0;

	if (not hide) then
		local props = image_surface_resolve(wnd.canvas);
		dx = props.x;
		dy = props.y;
		dw = props.width;
		dh = props.height;
		dopa = 1.0;
	else
		wnd:hide();
	end

	local vid = flair_supp_clone(wnd);
	local tv = gconfig_get("flair_speed");
	if (valid_vid(vid)) then
		if (not hide) then
			move_image(vid, x, y);
			resize_image(vid, w, h);
			blend_image(vid, dopa, tv);
			tag_image_transform(vid, MASK_OPACITY,
			function()
				wnd:show();
			end);
		else
			blend_image(vid, dopa, tv);
		end
		move_image(vid, dx, dy, tv, hide and INTERP_EXPOUT);
		resize_image(vid, dw, dh, tv, hide and INTERP_EXPOUT);
	else
		wnd:show();
	end
end

return {
	scale = scale_effect
};

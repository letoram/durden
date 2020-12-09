

return {
	flash = function(wm, wnd, space, space_active, popup)
		if (popup or not space_active or wm ~= active_display()) then
			return;
		end

-- this might be a bit icky if the window also animate resize, we don't
-- have a reliable mechanism to say (match parent size), though we should.
		local cw = image_surface_resolve(wnd.canvas);
		local surface = color_surface(cw.width, cw.height, 255, 255, 255);
		if not valid_vid(surface) then
			return;
		end

		link_image(surface, wnd.canvas, ANCHOR_UL, ANCHOR_SCALE_WH);
		image_inherit_order(surface, true);
		image_mask_set(surface, MASK_UNPICKABLE);

-- cover popups, subsurfaces and other crap
		order_image(surface, 9);
		blend_image(surface, 0.5, 5);
		blend_image(surface, 0.0, 5);
		expire_image(surface, 10);
	end,
	shake = function(wm, wnd, space, space_active, popup)
		if not space_active or wm ~= active_display() then
			return;
		end
		for i=1,2 do
			local dx = math.random(5, 10);
			local dy = math.random(5, 10);
			move_image(wnd.anchor, wnd.x + dx, wnd.y + dy, 1);
			move_image(wnd.anchor, wnd.x - dx, wnd.y - dy, 1);
		end
			move_image(wnd.anchor, wnd.x, wnd.y, 1);
	end
};

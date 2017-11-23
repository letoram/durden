--
-- This file describes 'cursor action' regions, rectangular regions
-- in floating workspace mode where some action will be taken if you
-- drag a window around. They can be used to implement behavior like
-- "drag window to edge to resize to fixed size", trigger migration
-- to a specific screen and so on.
--

local cactions = {};

-- this example, if uncommented, would exec the overview tool if the
-- cursor in its non-drag state is moved to the top left corner
--
-- table.insert(cactions, {
--	region = {0.0, 0.0, 0.001, 0.001},
--	visible = false,
--	on_over = function()
--		dispatch_symbol("#tools/overview/workspace_tile")
--	end
--});

-- this example, if uncommented, would trigger a window center
-- if dropped to the left edge of the user area, with a preview on
-- how that would look. It's slightly more complicated as it needs
-- to create / manage the "center- preview".
-- table.insert(cactions, {
--	region = {0.0, 0.0, 0.05, 1.0},
--	visible = true,
--	on_drag_over = function(ctx, wnd, vid)
--		local nsrf = color_surface(wnd.width, wnd.height, 0, 255, 0);
--		blend_image(nsrf, 0.5, gconfig_get("transition"));
--		order_image(nsrf, 65532);
--		move_image(nsrf,
--			0.5 * (wnd.wm.width - wnd.width), 0.5 * ( wnd.wm.height - wnd.height));
--		ctx.temp_vid = nsrf;
--		image_mask_set(nsrf, MASK_UNPICKABLE);
--		blend_image(vid, 0.7, gconfig_get("transition"));
--	end,
--	on_drag_out = function(ctx, wnd, vid)
--		if (valid_vid(ctx.temp_vid)) then
--			expire_image(ctx.temp_vid, 10);
--			blend_image(ctx.temp_vid, 0.0, 10);
--			ctx.temp_vid = nil;
--		end
--	end,
--	on_drop = function(ctx, wnd)
--		if (valid_vid(ctx.temp_vid)) then
--			expire_image(ctx.temp_vid, 10);
--			blend_image(ctx.temp_vid, 0.0, 10);
--			ctx.temp_vid = nil;
--		end

--		if (wnd.move) then
--			wnd:move(0.5*(wnd.wm.width - wnd.width),
--				0.5*(wnd.wm.height - wnd.height), false, true);
--		end
--	end
--});

return cactions;

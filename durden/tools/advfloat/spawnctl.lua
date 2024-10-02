gconfig_register("advfloat_spawn", "auto");
gconfig_register("advfloat_actionreg", false);

local pending, pending_vid;

local function setup_cursor_pick(wm, wnd)
	wnd:hide();
	pending = wnd;
	local w = math.ceil(wm.width * 0.15);
	local h = math.ceil(wm.height * 0.15);
	pending_vid = null_surface(w, h);
	link_image(pending_vid, mouse_state().cursor);
	image_sharestorage(wnd.canvas, pending_vid);
	blend_image(pending_vid, 1.0, 10);
	image_inherit_order(pending_vid, true);
	order_image(pending_vid, -1);
	nudge_image(pending_vid,
	mouse_state().size[1] * 0.75, mouse_state().size[2] * 0.75);
	local ctx = {anchor = pending_vid};
	suppl_region_shadow(ctx, w+20, h+20, {shader = "regsel"});
	if valid_vid(ctx.shadow) then
		nudge_image(ctx.shadow, -10, -10);
	end
end

local function activate_pending()
	delete_image(pending_vid);
	pending = nil;
end

local function wnd_attach(wm, wnd)
	local res = wnd:ws_attach(true);

-- died during attach
	if not wnd.wm then
		return;
	end

	if (wnd.wm:active_space().mode ~= "float") then
		return res;
	end

	if (pending) then
		activate_pending();
		if (DURDEN_REGIONSEL_TRIGGER) then
			suppl_region_stop();
		end
	end

	local mode = gconfig_get("advfloat_spawn");
	if (mode == "click") then
		setup_cursor_pick(wm, wnd);
		iostatem_save();
		local col = null_surface(1, 1);
		mouse_select_begin(col);
		dispatch_meta_reset();
		dispatch_symbol_lock();
		durden_input_sethandler(durden_regionsel_input, "draw-to-spawn");

-- the region setup and accept/fail is really ugly, but reworking it
-- right now is not really an option
		DURDEN_REGIONFAIL_TRIGGER = function()
			activate_pending();
			wnd:show();
			DURDEN_REGIONFAIL_TRIGGER = nil;
		end
		DURDEN_REGIONSEL_TRIGGER = function()
			activate_pending();
			if (wnd.show) then
				wnd:show();
			end
			DURDEN_REGIONFAIL_TRIGGER = nil;
		end
	elseif (mode == "draw") then
		setup_cursor_pick(wm, wnd);
		DURDEN_REGIONFAIL_TRIGGER = function()
			activate_pending();
			DURDEN_REGIONFAIL_TRIGGER = nil;
		end
		suppl_region_select(200, 198, 36, function(x1, y1, x2, y2)
			activate_pending();
			local w = x2 - x1;
			local h = y2 - y1;

-- dangling ref to a window that got deleted while we were picking
			if not wnd.move or not wnd.resize or not wnd.show then
				return;
			end

-- set the drawing constraints to keep the window in check
-- (or the scalemode might just fill)
			if (w > 64 and h > 64) then
				wnd.max_w = w
				wnd.max_h = h
				wnd:resize(w, h, true);
			end
			wnd:move(x1, y1, false, true, 0);
			wnd:show();
		end);
-- auto should really be to try and calculate the best fitting free space
	elseif (mode == "cursor") then
		local x, y = mouse_xy();
		if (x + wnd.width > wnd.wm.effective_width) then
			x = wnd.wm.effective_width - wnd.width;
		end

		if (y + wnd.width > wnd.wm.effective_height) then
			y = wnd.wm.effective_height - wnd.height;
		end
		wnd:move(x, y, false, true, true);
	else
	end

	return res;
end

--- hook displays so we can decide spawn mode between things like
--- spawn hidden, cursor-click to position, draw to spawn
display_add_listener(
	function(event, name, tiler, id)
		if (event == "added" and tiler) then
			tiler.attach_hook = wnd_attach;
		end
	end
);

--
-- All uiprim/* will become increasingly generalised for re-use outside durden.
-- To facilitate that, these functions provide the glue needed for the uiprims
-- to handle the input routing and context sensitive semantics that can't be
-- generalised inside uiprim.
--
-- One thing to note is that right now, these popups have their own chaining
-- and positioning that that is distinct from the wnd_popup approach in
-- tiler.lua. This could probably be consolidated, though the wnd setup is
-- primarily for external- client logic that has restrictions we don't need
-- to care about.
--
local log = suppl_add_logfn("wm");

local function position_popup(vid, x, y, w, h)
	move_image(vid, x, y);
end

function uimap_popup(menu, x, y)
	local wm = active_display();
	local ml = {
		name = "grab_surface"
	};

	local prefix = wm:font_resfn();
	local shadow_h = 10;

	local popup = uiprim_popup_spawn(menu, {
		border_attach =
		function(tbl, anchor, w, h)
-- now we can position the popup based on intended spawn
			image_inherit_order(anchor, true);
			order_image(anchor, 65534);
			position_popup(anchor, x, y, w, h);

-- but set our own shadow/border/cursor thing, the offset calculations
-- aren't particularly nice though, and should probably also use wm.scale
			shadow_h = h + 20;
			local ssurf = color_surface(w + 20, h + 20, 0, 0, 0);
			move_image(ssurf, -10, -10);
			tbl.shid = shader_ui_lookup(ssurf, "ui", "popup", "active");
			link_image(ssurf, anchor);
			image_inherit_order(ssurf, true);
			blend_image(ssurf, 1.0);
			force_image_blend(ssurf, BLEND_NORMAL);
			order_image(ssurf, -1);
		end,
		cursor_at = function(ctx, vid, xofs, yofs, max_w, h)
			if (not ctx.shid) then
				return;
			end
			shader_uniform(ctx.shid,
				"range", "ff", (yofs + 10) / shadow_h, (yofs + 10 + h) / shadow_h);
		end,
-- all paths return true == we take control over invocation
		on_finish =
		function(ctx, ent)
			dispatch_symbol_unlock(true);
			active_display():set_input_lock();

			if not ent then
				log("tool=popup:kind=cancelled");
				return;
			end
			log("tool=popup:kind=selected:item=" .. ent.name);
			mouse_droplistener(ml);

-- block submenus for now
			if (ent.submenu) then
				log("tool=popup:kind=chain:item=" .. ent.name);
				ctx:cancel();
				return true;
			end

-- and forward normal items (will just trigger handle and cancel)
			return false;
		end,
		text_valid = prefix .. "\\#aaaaaa",
		text_invalid = prefix .. "\\#666666",
		animation_in = gconfig_get("animation") * 0.5,
		animation_out = gconfig_get("animation") * 0.5,
	});

-- big invisible surface that will absorb mouse events
	local surf = null_surface(wm.width, wm.height);
	show_image(surf);
	link_image(surf, popup.anchor);
	image_mask_clear(surf, MASK_POSITION);
	image_inherit_order(surf, true);
	order_image(surf, -2);
	ml.own = function(ctx, vid)
		return vid == surf;
	end;
	ml.button = function(ctx, index, active, ...)
		if (active) then
			log("tool=popup:kind=send_cancel");
			popup:cancel();
		end
	end;
	mouse_addlistener(ml, {"button"});

-- grab the translated keysym routing and forward to popup cursor,
-- since this also has 'dibs' on mouse input, reroute through there
	active_display():set_input_lock(
	function(wm, sym, iotbl, lutsym, meta)
		if iotbl.mouse then
			mouse_iotbl_input(iotbl);
			return;
		end

		if not iotbl.active then
			return;
		end

		if (sym == SYSTEM_KEYS["accept"]) then
			popup:trigger();
		elseif (sym == SYSTEM_KEYS["cancel"]) then
			popup:cancel();
		elseif (sym == SYSTEM_KEYS["previous"] or sym == SYSTEM_KEYS["right"]) then
			popup:step_down();
		elseif (sym == SYSTEM_KEYS["next"] or sym == SYSTEM_KEYS["left"]) then
			popup:step_up();
		else
-- scan menu for matching prefix and jump to there?
		end
		return true;
	end, "uimap/popup");

-- block all possible interrupts from the menu path dispatch
	dispatch_symbol_lock();
end
--
--

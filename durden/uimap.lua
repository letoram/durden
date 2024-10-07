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

local function position_popup(vid, x, y, w, h, anchor_vid)
	local wm = active_display();

	if valid_vid(anchor_vid) then
		link_image(vid, anchor_vid)
		order_image(vid, 65530)
	end

	if (x + w > wm.width) then
		x = x - (x + w - wm.width) - 20;
	end

	if (x < 0) then
		x = 0;
	end

	if (y + h > wm.height) then
		y = y - (y + h - wm.height) - 20;
	end

	move_image(vid, x, y);
end

local function vent_to_menu(ent)
	local res = {
	};

	local set = type(ent.set) == "function" and ent.set() or ent.set;
	for i,v in ipairs(set) do
		table.insert(res, {
			name = ent.name .. "_set_" .. tonumber(i),
			kind = "action",
			label = v,
			handler = function(ctx)
				ent.handler(ctx, v);
			end
		});
	end

	return res;
end

function uimap_popup(menu, x, y, anchor_vid, closure, opts)
	opts = opts and opts or {};
	local wm = active_display();
	local ml = {
		name = "grab_surface"
	};

	local prefix = wm:font_resfn();
	local shadow_h = 10;
	local speed = gconfig_get("popup_animation");
	local hw = suppl_display_ui_pad();
	local ilock;

	local popup, popup_closure;
	popup, popup_closure =
	uiprim_popup_spawn(menu, {
		border_attach =
		function(tbl, anchor, w, h)
-- now we can position the popup based on intended spawn
			image_inherit_order(anchor, true);
			order_image(anchor, 65534);
			shadow_h = h + hw + hw;
			position_popup(anchor, x + hw, y + hw, w, h, anchor_vid);

-- but set our own shadow/border/cursor
			local ssurf = color_surface(w + hw + hw, shadow_h, 0, 0, 0);
			move_image(ssurf, -hw, -hw);
			tbl.shid = shader_ui_lookup(ssurf, "ui", "popup", "active");
			link_image(ssurf, anchor);
			image_inherit_order(ssurf, true);
			blend_image(ssurf, 1.0);
			order_image(ssurf, -1);
		end,
		cursor_at = function(ctx, vid, xofs, yofs, max_w, h, i)
			if (not ctx.shid) then
				return;
			end
			shader_uniform(ctx.shid,
				"range", "ff", (yofs + hw) / shadow_h, (yofs + hw + h) / shadow_h);
			if opts.a11y_hook then
				opts.a11y_hook(menu[i].label)
			end
		end,
-- all paths return true == we take control over invocation
		on_finish =
		function(ctx, ent)
			mouse_droplistener(ml);
			popup_closure();
			dispatch_symbol_unlock(true);
			active_display():set_input_lock(ilock, "uimap_popup_over");

			if opts.a11y_hook then
				opts.a11y_hook(ent and ent.label, ent ~= nil)
			end

-- let the activation be intercepted
			if closure and not closure(ent) then
				return;
			end

			if not ent then
				log("tool=popup:kind=cancelled");
				return;
			end
			log("tool=popup:kind=selected:item=" .. ent.name);

			if (ent.submenu) then
				log("tool=popup:kind=chain:item=" .. ent.name);

--
-- There is a problematic nuance here in how to implement 'back' as we are so
-- deep in generated trees of dynamic menus that events happening in the
-- background might invalidate the contents of the current menu. The eval()
-- function was intended to counter that, but it turned out that when it was
-- applied to dynamic submenus, all local (to the menu) items assumed the
-- eval() of the menu having been applied, so some items would just break.
--
-- On top of that, our popup root can be a dynamic set that comes from all
-- over, so we'd actually need to rebuild the path up until the one we were
-- at - so a stack is needed. Not impossible at all but just more work.
--
-- The other bit would be to revisit the paths that mutate their own
-- circumstances as that set must be much smaller necessarily.
--
				opts.dir = "r";
				local menu = type(ent.handler) ==
					"function" and ent.handler() or ent.handler;
				ctx:cancel();
				uimap_popup(menu, x, y, anchor_vid, nil, opts);
				return true;
			end

-- value-sets can be provided as popups without needing to provide other IMEs
			if (ent.kind == "value") then
				if (ent.set or type(ent.preset) == "table") then
					local menu = vent_to_menu(ent);
					ctx:cancel();
					opts.dir = "r";
					uimap_popup(menu, x, y, anchor_vid, nil, opts);
					return true;

-- inject the preset
				elseif ent.preset then
					ctx:cancel();
					if not ent.validator or ent.validator(ent.present) then
						ent:handler(ent.preset);
					end
					return true;

-- fallback to trigger the HUD on the entry path, this should be replaced
-- with different helpers depending on value type.
				else
					ctx:cancel();
					menu_query_value(ent, nil, true);
				end

				return true;
			end

-- and forward normal items (will just trigger handle and cancel)
			return false;
		end,
		text_valid = prefix .. HC_PALETTE[1],
		text_invalid = prefix .. "\\#666666",
		text_menu = prefix .. HC_PALETTE[2],
		text_menu_suf = " »",
		animation_in = speed,
		animation_out = speed
	});
	if not popup then
		return;
	end

	if opts.block_cancel then
		popup.cancel = function()
		end
	end

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

	ml.button = function(ctx, vid, index, active)
		if (not active) then
			return;
		end

		if (index < MOUSE_WHEELPY) then
			log("tool=popup:kind=send_cancel");

			if (popup.wheel_event and index == MOUSE_LBUTTON) then
				popup:trigger();
			else
				popup:cancel();
			end

-- if wheel navigation has been used, have the left mouse button mean accept
		elseif index == MOUSE_WHEELPY then
			popup.wheel_event = true;
			popup:step_up();

		elseif index == MOUSE_WHEELNY then
			popup.wheel_event = true;
			popup:step_down();
		end
	end;
	mouse_addlistener(ml, {"button"});

-- grab the translated keysym routing and forward to popup cursor,
-- since this also has 'dibs' on mouse input, reroute through there
	ilock =
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

-- animate on spawn based on window position
	local dx = x;
	local dx2 = math.abs(wm.effective_width - x);
	local dy = y;
	local dy2 = math.abs(wm.effective_height - y);

	local delta = 100 * wm.scalef;

	local dir = opts.dir;
	if not dir then
		if (dx < dx2 and dx < dy and dx < dy2) then
			dir = "l";
		elseif (dx2 < dx and dx2 < dy and dx2 < dy2) then
			dir = "r";
		elseif (dy < dx and dy < dx2 and dy < dy2) then
			dir = "t";
		else
			dir = "d";
		end

-- override if we are not at the edges
		local edge_w = wm.effective_width * 0.1;
		local edge_h = wm.effective_height * 0.1;
		if dx > edge_w and dx2 > edge_w and dy > edge_h and dy2 > edge_h then
			dir = "l"; -- RTL langs would probably pref. 'r' here..
		end
	end

	if dir == "l" then
		nudge_image(popup.anchor, -delta, 0);
		nudge_image(popup.anchor, delta, 0, speed);
	elseif dir == "r" then
		nudge_image(popup.anchor, delta, 0);
		nudge_image(popup.anchor, -delta, 0, speed);
	elseif dir == "t" then
		nudge_image(popup.anchor, 0, -delta, 0);
		nudge_image(popup.anchor, 0, delta, speed);
	else
		nudge_image(popup.anchor, 0, delta, 0);
		nudge_image(popup.anchor, 0, -delta, speed);
	end

-- block all possible interrupts from the menu path dispatch
	dispatch_symbol_lock();
end
--
--

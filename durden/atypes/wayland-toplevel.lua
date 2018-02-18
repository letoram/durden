--
-- most of these functions come mapped via the waybridge- handler as subseg
-- requests, though the same setup and mapping need to work via reset-adopt
-- as well, hence the separation.
--
-- the big work item here is resize related, most of durden is written as
-- forced independent resizes, while wayland only really functions with
-- deferred, client driven ones.
--
-- thus, in_drag_rz, maximimize needs reworking, we need to do some autocrop,
-- pan for tiling and resize/constraints that account for the geometry of the
-- surface.
--
local toplevel_lut = {};

-- criterion: if the window has input focus (though according to spec
-- it can loose focus during drag for unspecified reasons) and the mouse
-- is clicked, we toggle canvas- drag.
toplevel_lut["move"] = function(wnd, ...)
	if (active_display().selected == wnd) then
		wnd.in_drag_move = true;
	end

	wayland_trace("enter client- initiated drag move");
end

toplevel_lut["maximize"] = function(wnd)
	if (wnd.space.mode == "float") then
		wnd:toggle_maximize();
	end
end

toplevel_lut["menu"] = function(wnd)
	if (active_display().selected == wnd) then
		local fun = grab_shared_function("target_actions");
		fun();
	end
end

local function set_dragrz_state(wnd, mask, from_wl)
	local props = image_storage_properties(wnd.canvas);

-- accumulator gets subtracted the difference between the acked event
-- and the delta that has occured since then
	wnd.last_w = props.width;
	wnd.last_h = props.height;
	wnd.rz_acc_x = 0;
	wnd.rz_acc_y = 0;
	wnd.rz_ofs_x = 0;
	wnd.rz_ofs_y = 0;

-- different masking/moving value interpretation
	if (not from_wl) then
		mask = {
			mask[1],
			mask[2],
			mask[1] < 0 and -1 or 0,
			mask[2] < 0 and -1 or 0
		};
	end

-- if we have geometry, then we need to offset our hints or the initial
-- drag will get a 'jump' based on this difference
	if (wnd.geom) then
		wnd.rz_ofs_x = -(props.width - wnd.geom[3]);
		wnd.rz_ofs_y = -(props.height - wnd.geom[4]);
	end

-- this will be reset on the completion of the drag
	wnd.in_drag_rz =
	function(wnd, ctx, vid, dx, dy, last)
		dx = dx * mask[1];
		dy = dy * mask[2];
		wnd.move_mask = {mask[3], mask[4]};
		wnd.rz_acc_x = wnd.rz_acc_x + dx;
		wnd.rz_acc_y = wnd.rz_acc_y + dy;
		wnd:displayhint(
			wnd.last_w + wnd.rz_acc_x + wnd.rz_ofs_x,
			wnd.last_h + wnd.rz_acc_y + wnd.rz_ofs_y, wnd.dispmask
		);
	end
end

toplevel_lut["resize"] = function(wnd, dx, dy)
	if (active_display().selected ~= wnd or wnd.space.mode ~= "float") then
		return;
	end

-- the dx/dy message comes from a hint as to which side is being dragged
-- we need to mask the canvas- drag event handler accordingly
	dx = tonumber(dx);
	dy = tonumber(dy);
	dx = math.clamp(dx, -1, 1);
	dy = math.clamp(dy, -1, 1);
	local mask = {dx, dy, dx < 0 and -1 or 0, dy < 0 and -1 or 0};

	set_dragrz_state(wnd, mask, true);
end

-- try and center but don't go out of screen boundaries
local function center_to(wnd, parent)
	local dst_x = parent.x + 0.5 * (parent.width - wnd.width);
	local dst_y = parent.y + 0.5 * (parent.height - wnd.height);
	wnd:move(dst_x, dst_y, false, true, true, false);
end

-- this is also triggered on_destroy for the toplevel window so the id
-- always gets relinked before
local function set_parent(wnd, id)
	if (id == 0) then
		local ip = wnd.indirect_parent;
		if (ip and ip.anchor) then
			assert(ip.indirect_child == wnd);
			ip:drop_overlay("wayland");
			ip.delete_protect = ip.old_protect;
			local pvid = image_parent(ip.anchor);
			ip.old_protect = nil;
			ip.select = ip.old_select;
			ip.indirect_child = nil;
			ip.old_select = nil;
		end
		wnd.indirect_parent = nil;
		return;
	end

	local parent = wayland_wndcookie(id);
	if (parent == wnd) then
		wayland_trace("set_parent, id resolved to self!");
		return;
	end

	if (parent.indirect_child and parent.indirect_child ~= wnd) then
		wayland_trace("multiple toplevels fighting for the same parent");
		return;
	end

	if (not parent) then
		wayland_trace("toplevel tried to reparent to unknown window");
		return;
	end

-- switch selection (brings to front), dim the parent and make it invincible
-- delete protect, input block, select block (delete will unset)
	if (active_display().selected == parent) then
		wnd:select();
	end

	local xofs = 0;
	local yofs = 0;
	local wofs = 0;
	local hofs = 0;
	if (parent.geom) then
		xofs = parent.geom[1];
		yofs = parent.geom[2];
		wofs = parent.effective_w - parent.geom[3] - xofs;
		hofs = parent.effective_h - parent.geom[4] - yofs;
	end

-- configure the size of the toplevel to match that of the parent..

-- for tile, we should set the window as an 'alternate' until it reparents
-- or when the client die

	parent:add_overlay("wayland", color_surface(1, 1, 0, 0, 0), {
		stretch = true,
		blend = 0.5,
		mouse_handler = {
			click = function(ctx)
-- this should select the deepest child window in the chain
				parent:to_front();
				wnd:select();
				wnd:to_front();
			end,
			drag = function(ctx, vid, dx, dy)
-- in float, this should of course move the window
				wnd:move(dx, dy, false, false, true, false);
				parent:move(dx, dy, false, false, true, false);
			end
		},
		xofs = xofs,
		yofs = yofs,
		wofs = wofs,
		hofs = hofs
	});

	parent.old_protect = parent.delete_protect;

-- override the parent selection to move to the new window, UNLESS
-- another toplevel window has already performed this action
	if (not parent.old_select) then
		parent.old_select = parent.select;
		parent.select = function(...)
			if (wnd.select) then
				wnd:select(...)
			end
		end
	end

-- track the reference so we know the state of the window on release
	parent.indirect_child = wnd;
	wnd.indirect_parent = parent;

-- since the surface might not have been presented yet, we want to
-- try and center on the first resize event as well
	wnd.pending_center = parent;
	center_to(wnd, parent);
end

function wayland_toplevel_handler(wnd, source, status)
	if (status.kind == "terminated") then
		wayland_lostwnd(source);
		wnd:destroy();
		return;

	elseif (status.kind == "registered") then
		wnd:set_guid(status.guid);

-- reparenting to another surface, this may or may not also grab input
	elseif (status.kind == "viewport") then
		wayland_trace("reparent toplevel:" .. tostring(status.parent));
		set_parent(wnd, status.parent);

	elseif (status.kind == "message") then
		local opts = string.split(status.message, ":");
		if (not opts or not opts[1]) then
			wayland_trace("unknown opts field in message");
			return;
		end

		if (opts[1] == "shell" and opts[2] == "xdg_top" and opts[3] ~= nil) then
			if (not toplevel_lut[opts[3]]) then
				wayland_trace("unknown xdg- toplevel method:", opts[3]);
			else
				toplevel_lut[opts[3]](wnd, opts[4], opts[5]);
			end
		elseif (opts[1] == "geom") then
			local x, y, w, h;
			x = tonumber(opts[2]);
			y = tonumber(opts[3]);
			w = tonumber(opts[4]);
			h = tonumber(opts[5]);

-- Some clients send this practically every frame, only update if it has
-- actually updated, same with region cropping. This is not entirely correct
-- when there's subsurfaces that define the outer rim of the geometry. The
-- safeguard in such cases (no good test case right now) is to cache/only
-- use the geometry crop when there are no subsurfaces that resolve to
-- outside the toplevel.
			if (w and y and w and h) then
				if (not wnd.geom or (wnd.geom[1] ~= x or
					wnd.geom[2] ~= y or wnd.geom[3] ~= w or wnd.geom[4] ~= h)) then
					wnd.geom = {x, y, w, h};

-- new geometry, if we're set to autocrop then do that, if we have an
-- impostor defined, update it now
				end
			end
			if (#opts ~= 5) then
				wayland_trace("unknown number of arguments in geom message");
				return;
			end
		elseif (opts[1] == "scale") then
-- don't really care right now, part otherwise is just to set the
-- resolved factor to wnd:resize_effective
		else
			wayland_trace("unhandled wayland message", status.message);
		end

	elseif (status.kind == "segment_request") then
		wayland_trace("segment request on toplevel, rejected");

	elseif (status.kind == "resized") then
		if (wnd.ws_attach) then
			wnd:ws_attach();

			if (valid_vid(wnd.titlebar.impostor_vid)) then
			else
			end
			wnd.meta_dragmove = true;
		end

		wnd:resize_effective(status.width, status.height, true, true);

-- deferred from drag resize where the move should match the config change
		if (wnd.move_mask) then
			local dx = status.width - wnd.last_w;
			local dy = status.height - wnd.last_h;
			wnd.rz_acc_x = wnd.rz_acc_x - dx;
			wnd.rz_acc_y = wnd.rz_acc_y - dy;
			wnd:move(dx * wnd.move_mask[1], dy * wnd.move_mask[2], false, false, true, false);
			wnd.move_mask = nil;

-- and similar action for toplevel reparenting
		elseif (wnd.pending_center and wnd.pending_center.x) then
			center_to(wnd, wnd.pending_center);
			wnd.pending_center = nil;
		end

		wnd.last_w = status.width;
		wnd.last_h = status.height;
	end
end

--
-- overload the default displayhint handler for the window in order to add
-- our own custom padding function to it that takes the last acknowledged
-- geometry into account.
--
local wl_displayhint = function(wnd, hw, hh, ...)
	if (not valid_vid(wnd.external, TYPE_FRAMESERVER)) then
		return;
	end

--	if (hw > 0 and hh > 0) then
--		active_display():message(string.format("wl-resize to %f, %f", hw, hh));
--		local pad_w, pad_h;
--		if (wnd.geom) then
--			local props = image_storage_properties(wnd.canvas);
--			pad_w = wnd.geom[1] + props.width - (wnd.geom[1] + wnd.geom[3]);
--			pad_h = wnd.geom[2] + props.height - (wnd.geom[2] + wnd.geom[4]);
--			hw = hw;
--			hh = hh;
--		end
--	end

	if (hw ~= 0 or hh ~= 0) then
		hw = math.clamp(hw, 32, MAX_SURFACEW);
		hh = math.clamp(hh, 32, MAX_SURFACEH);
	end

	target_displayhint(wnd.external, hw, hh, ...);
end

wl_destroy = function(wnd, was_selected)
-- if a toplevel was set previously
	if (wnd.indirect_parent and wnd.indirect_parent.anchor) then
		local ip = wnd.indirect_parent;
		set_parent(wnd, 0);
		if (was_selected) then
			ip:select();
		end
	end

-- deregister the toplevel tracking
	if (wnd.bridge and wnd.bridge.wl_children) then
		wnd.bridge.wl_children[wnd.external] = nil;
	end
end

local function wl_resize(wnd, neww, newh, efw, efh)
	local props = image_storage_properties(wnd.canvas);
	local nefw = efw;
	local nefh = efh;
	if (wnd.geom) then
		nefw = wnd.geom[3] + (efw - wnd.last_w);
		nefh = wnd.geom[4] + (efh - wnd.last_h);
	end

	wnd:displayhint(nefw + wnd.dh_pad_w, nefh + wnd.dh_pad_h);
end

local toplevel_menu = {
	{
		name = "crop_geom",
		label = "Crop Geometry",
		kind = "value",
		initial = function() return gconfig_get("wl_autocrop") and LBL_YES or LBL_NO; end,
		set = {LBL_YES, LBL_NO},
		handler = function(ctx, val)
			local wnd = active_display().selected;
			if (val == LBL_YES) then
				wnd.wl_autocrop = true;
				local props = image_storage_properties(wnd.canvas);
				wnd:set_crop(
					wnd.geom[2], wnd.geom[1], -- t, l
					props.height - wnd.geom[4] - wnd.geom[2], -- d
					props.width - wnd.geom[3] - wnd.geom[1] -- r
				);
			else
				wnd.wl_autocrop = false;
				wnd:set_crop(0, 0, 0, 0);
			end
		end
	},
	{
		name = "impostor",
		label = "Impostor Headerbars",
		kind = "value",
		initial = function() return gconfig_get("wl_impostor") and LBL_YES or LBL_NO; end,
		set = {LBL_YES, LBL_NO},
		handler = function(ctx, val)
			local wnd = active_display().selected;
			if (val == LBL_YES) then

			end
		end
	},
	{
		name = "hide_subsurfaces",
		kind = "value",
		set = {"edges", "all", "none"},
		initial = function()
		end,
		handler = function(ctx, val)
-- enumerate current subsurfaces and set/check
		end
	},
};

return {
	atype = "wayland-toplevel",
	actions = {
		{
			name = "wayland",
			label = "Wayland",
			description = "Wayland specific window management options",
			submenu = true,
			kind = "action",
			handler = toplevel_menu
		}
	},
	init = function(atype, wnd, source)
		wnd.last_w = 0;
		wnd.last_h = 0;
		wnd.displayhint = wl_displayhint;
		wnd.drag_rz_enter = set_dragrz_state;
		wnd:add_handler("destroy", wl_destroy);
		wnd:add_handler("resize", wl_resize);
	end,
	props = {
		kbd_period = 0,
		kbd_delay = 0,
		centered = true,
		scalemode = "client",
		filtermode = FILTER_NONE,
		rate_unlimited = true,
-- all wayland windows connected to the same client need the same clipboard
		clipboard_block = true,
		font_block = true,
		block_rz_hint = true,
-- all allocations go on the parent
		allowed_segments = {},
		show_border = false,
		show_titlebar = false
	},
	dispatch = {}
};

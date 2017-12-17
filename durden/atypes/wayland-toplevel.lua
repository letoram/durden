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
-- then we really need a 'crop-shop' tool that allows slicing out the decor,
-- and delegating the titlebar to be an impostor on the normal titlebar.
--
local toplevel_lut = {};
local wl_resize;

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
		wayland_trace("spawn target- menu");
	end
end

-- similar criterion to move
toplevel_lut["resize"] = function(wnd, dx, dy)
	wayland_trace("enter client- initiated drag resize");
	if (active_display().selected == wnd) then
		dx = tonumber(dx);
		dy = tonumber(dy);
		if (not dx or not dy) then
			return;
		end

		dx = math.clamp(dx, -1, 1);
		dy = math.clamp(dy, -1, 1);
		wnd.in_drag_rz_mask = {dx, dy, dx < 0 and 1 or 0, dy < 0 and 1 or 0};

		local ox, oy, ow, oh;

-- ignore dx,dy - use mouse coordinates
		wnd.in_drag_rz = function(wnd, ctx, vid, dx, dy, last)
			if (not ox) then
				ox, oy = mouse_xy();
				ow = wnd.width; oh = wnd.height;
				return;
			end

-- save this so when / if the resize comes, we can move accordingly
			wnd:move(dx * ctx.mask[3], dy * ctx.mask[4]);
			active_display():message(string.format("%f, %f, %f, %f",
				dx, dy, ctx.mask[3], ctx.mask[4]));

			local cx, cy = mouse_xy();
			wl_resize(wnd,
				ow + ctx.mask[1] * (cx - ox),
				oh + ctx.mask[2] * (cy - oy)
			);

-- reset accumulators
			if (last) then
				ox = nil; oy = nil;
			end
		end
	end
end

-- as per usual, the spec barely says anything about how this feature is
-- supposed to behave function, only 'stacked above' and that the parent
-- surface 'must be mapped' as long as this one is, nothing about input/
-- focus/what happens on switching? 1:many, ...
--
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
			link_image(wnd.anchor, pvid);
			ip.old_protect = nil;
			ip.select = ip.old_select;
			ip.indirect_child = nil;
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
	parent:add_overlay("wayland", color_surface(1, 1, 0, 0, 0), {
		stretch = true,
		blend = 0.5,
		block_mouse = true
	});

	parent.old_protect = parent.delete_protect;
	parent.old_select = parent.select;
	parent.select = function(...)
		wnd:select(...)
	end

-- track the reference so we know the state of the window on release
	parent.indirect_child = wnd;
	wnd.indirect_parent = parent;

-- in float mode, we want to do all kinds of 'special' things, i.e. block
-- input on parent, set an overlay that dims the window, anchor and center
-- window coordinate space. These shenanigans won't really work for mode-
-- switch while active though.
	link_image(wnd.anchor, parent.canvas, ANCHOR_C);
	nudge_image(wnd.anchor, -0.5 * wnd.width, -0.5 * wnd.height);

-- for tile, we add the window as an 'alternate' and lock to this
end

function wayland_toplevel_handler(wnd, source, status)
	if (status.kind == "terminated") then
		wayland_lostwnd(source);
		wnd:destroy();
		return;

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
			if (w and y and w and h) then
				wnd.geom = {x, y, w, h};
			end
			if (#opts ~= 5) then
				wayland_trace("unknown number of arguments in geom message");
				return;
			end
		else
			wayland_trace("unhandled wayland message", status.message);
		end

	elseif (status.kind == "segment_request") then
		wayland_trace("segment request on toplevel, rejected");

	elseif (status.kind == "resized") then
		if (wnd.ws_attach) then
			wnd:ws_attach();
			wnd:rebuild_border();

-- the hidekey is used to force- block any attempt at restoring the
-- titlebar, working around an edge- case in workspace layout mode
-- transitions
			wnd.titlebar:hide("wayland");
			wnd.meta_dragmove = true;
		end
		wnd:resize_effective(status.width, status.height, true, true);
	end
end

--
-- so this is fucking retarded, but we can't use the size of the source
-- storage to figure out anything about what visible size the contents of
-- the client actually has. Why? Client decorations and drop-shadows and
-- quite possibly rotation and scaling nonsense and arbitrary subsurfaces
-- with subsurfaces on top of that. The only possible way, it seems, is to
-- actually walk the geometry and the subsurface position+dimensions. This
-- is problematic for tiling to the point that when we do sizing hints, we
-- should actually take the client area, then subtract each subsurface/ etc.
-- but hey, there's no constraints or clipping, so GLHF. A "simple" protocol
-- indeed.
--
-- The configure event (that's how DISPLAYHINT is translated in waybridge)
-- is treated by the client as 'ok, w+A,h+B' where it gets to pick A and
-- B because of decorations. This practically only works on a floating
-- desktop. Our option elsewhere is to burn another resize and take
-- advantage of the last known 'geometry event', but since this event
-- only carries xofs+w,yofs+h we then have to subtract from the storage
-- dimensions as the padding region doesn't have to be symmetric.
--
wl_resize = function(wnd, neww, newh)
	local efw, efh;

	if (neww > 0 and newh > 0) then
		efw = neww - (wnd.hide_border and 0 or (wnd.pad_left - wnd.pad_right));
		efh = newh - (wnd.hide_border and 0 or (wnd.pad_top - wnd.pad_bottom));

		local pad_w, pad_h;
		if (wnd.geom) then
			local props = image_storage_properties(wnd.canvas);
			pad_w = wnd.geom[1] + props.width - (wnd.geom[1] + wnd.geom[3]);
			pad_h = wnd.geom[2] + props.height - (wnd.geom[2] + wnd.geom[4]);
			efw = efw - pad_w;
			efh = efh - pad_h;
		end

		if (efw > 0 and efh > 0) then
			wnd.hint_w = efw;
			wnd.hint_h = efh;
			target_displayhint(wnd.external, efw, efh, wnd.dispmask);
		end
	end
end

wl_destroy = function(wnd, was_selected)
	if (wnd.indirect_parent and wnd.indirect_parent.anchor) then
		local ip = wnd.indirect_parent;
		set_parent(wnd, 0);
		if (was_selected) then
			ip:select();
		end
	end
	if (wnd.bridge and wnd.bridge.wl_children) then
		wnd.bridge.wl_children[wnd.external] = nil;
	end
end

return {
	atype = "wayland-toplevel",
	action = {},
	init = function(atype, wnd, source)
		wnd:add_handler("resize", wl_resize);
		wnd:add_handler("destroy", wl_destroy);
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
		hide_border = true,
		hide_titlebar = true
	},
	dispatch = {}
};

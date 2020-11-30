--
-- Simplified policy/mutation rules for X11 surfaces allocated via
-- wayland->x11-bridge. These are slightly special in that they can
-- possibly change role/behavior as they go along, and current
-- behavior as to visibility etc. is based on that.
--
-- The corresponding low-level implementation is in waybridge/
-- arcan_xwm.
--

local x11_menu = {
-- nothing atm.
};
local log, fmt = suppl_add_logfn("wayland");

local function viewport(wnd, status)
-- the behavior for this varies with type
	log(fmt("name=%s:type=%s:x=%d:y=%d:parent=%d",
		wnd.name, wnd.surface_type, status.rel_x, status.rel_y, status.parent)
	);
end

local function resize(wnd, status)
	wnd:resize_effective(status.width, status.height, true, true);
end

-- In principle, an x11 surface can request a display global coordinate
-- for reparenting and positioning popups and other 'override_redirect'
-- surfaces with a grab.
--
-- Since this can be used for UI- redressing style nastyness, it should
-- be an option if the user wants this or not.
--
local function popup_handler(wnd, source, status, wtype)
	if (status.kind == "viewport") then
		local pid = wayland_wndcookie(status.parent);
		if (not pid or not valid_vid(pid.canvas)) then
			log(fmt("x11-%s:viewport:name=%s:parent_id=%d:x=%d:y=%d:anchor=global",
				wtype, wnd.name, status.parent, status.rel_x, status.rel_y)
			);
-- so some applications ignore the hierarchy of windows and just positions
-- within the same coordinate space as the client
			link_image(source, active_display().order_anchor);
			order_image(source, 1);
		else
			log(fmt("x11-%s:viewport:name=%s:parent=%s:x=%d:y=%d:anchor=parent",
				wtype, wnd.name, pid.name, status.rel_x, status.rel_y)
			);
			link_image(source, active_display().order_anchor);
			order_image(source, 1);
		end
		move_image(source, status.rel_x, status.rel_y);

	elseif (status.kind == "terminated") then
		log(fmt("x11-%s:destroy:name=%s:client_terminated", wtype, wnd.name));
		wayland_lostwnd(source);
		delete_image(source);

	elseif (status.kind == "resized") then
		log(fmt("x11-%s:resized:name=%s:w=%d:h=%d",
			wtype, wnd.name, status.width, status.height)
		);
		resize_image(source, status.width, status.height);
		order_image(source, 2);
		show_image(source);
	end
end

-- tray-icons are also a bit special, a separate window for
-- _NET_SYSTEM_TRAY_S0 are needed along with a SYSTEM_TRAY_REQUEST_DOCK,
-- then the icon itself comes from _NET_WM_ICON, and notifications go
-- as 'balloon messages'.

local function apply_type_size(wnd, source, status)
	image_tracetag(wnd.external, "x11_" .. wnd.surface_type);

	if (wnd.surface_type == "popup" or
		wnd.surface_type == "dropdown" or
		wnd.surface_type == "tooltip" or
		wnd.surface_type == "menu" or
		wnd.surface_type == "utility" or
		wnd.surface_type == "notification") then
-- destroy the 'container', won't be needed with popup, uncertain
-- what the 'rules' say about the same surface mutating in type, but
-- assume for now that it doesn't. Likely need different positioning
-- constraints based on the different types
		log(fmt("x11:type=%s:name=%s", wnd.surface_type, wnd.name));
		local newwnd = {name = wnd.name, surface_type = wnd.surface_type};
		local newvid = wnd.external;
		image_inherit_order(newvid, true);
		image_mask_set(newvid, MASK_UNPICKABLE);

		log("switch-handler:" .. tostring(newvid));
		target_updatehandler(newvid, function(source, status)
			popup_handler(newwnd, source, status, newwnd.surface_type);
		end);

-- register and apply deferred viewport
		wayland_gotwnd(newvid, newwnd);
		if (wnd.last_viewport) then
			popup_handler(newwnd, source, wnd.last_viewport, newwnd.surface_type);
		end

-- forward any possible incoming 'resize' event as well
		if (status) then
			popup_handler(newwnd, source, status, newwnd.surface_type);
		end

-- never attach the window, but don't delete the external vid
		wnd.external = nil;
		wnd:destroy();

	elseif (wnd.surface_type == "icon") then
-- this could be set to just wnd.icon and that should propagate throughout,
-- crux is how to limit the size and transfer it to a decent size / update
-- create so a misbehaving icon doesn't break everything, for now just rm it
--
-- then we should also allow a special systray window (_NET_SYSTEM_TRAY_S0)
		log("x11:message=eimpl:kind=icon");
		wnd:destroy();

-- missing safety bit - this should only work if a previous x surface
-- from the same bridge had input focus before us, and we need more work
-- to actually 'drop' it on a non-X surface
	elseif (wnd.surface_type == "dnd") then

		mouse_cursortag(wnd, "window",
			function(srcwnd, accept, dstwnd)
				log("x11:message=eimpl:kind=dnd_apply");
			end, wnd.external
		);

		target_updatehandler(wnd.external,
		function(source, status)
			if status.kind == "terminated" then
				mouse_cursortag_drop(false, dstwnd);
			end
		end);

		wnd.external = nil;
		wnd:destroy();
	else
-- treat the rest as normal windows
		if (wnd.ws_attach) then
			log(fmt("x11:type=%s:name=%s:status=attach_fwd", wnd.surface_type, wnd.name));
			wnd:ws_attach();
		end

		if (status) then
			resize(wnd, status);
		end
	end
end

function x11_event_handler(wnd, source, status)
	log(fmt("status=event:source=%d:name=%s:event=%s", source, wnd.name, status.kind));

	if (status.kind == "terminated") then
		wayland_lostwnd(source);
		wnd:destroy();

	elseif (status.kind == "registered") then
		wnd:set_guid(status.guid);

	elseif (status.kind == "viewport") then
		if (wnd.surface_type) then
			viewport(wnd, status);
		else
			log(fmt("status=deferred:source=%d:event=%s:name=%s", source, status.kind, wnd.name));
			wnd.last_viewport = status;
		end

	elseif (status.kind == "message") then
			log(status.message);

-- our regular dispatch table of 'special hacks'
		local opts = string.split(status.message, ":");

		if (not opts or not opts[1]) then
			log(fmt("x11:error_message=unknown:source=%d:name=%s:raw=%s", source, wnd.name, status.message));
		end

		if (opts[1] == "type" and opts[2]) then
			log(fmt("x11:set_type=%s:name=%s", opts[2], wnd.name));
			wnd.surface_type = opts[2];
			apply_type_size(wnd, source, wnd.defer_resize);
			wnd.defer_size = nil;

		elseif (opts[1] == "pair" and opts[2] and opts[3]) then
			log(fmt("x11:source=%d:wayland=%s:x11=%s",source, opts[2], opts[3]));

		elseif (opts[1] == "fullscreen" and opts[2]) then
			log(fmt("x11:source=%d:fullscreen=%s", source, opts[2]));
		else
			log(fmt("x11:error_message=unknown:command=%s:name=%s", opts[1], wnd.name));
		end

	elseif (status.kind == "segment_requested") then
		log("x11:error_message=subsegment_request");

	elseif (status.kind == "resized") then
-- we actually only attach on the first buffer delivery when we also know
-- the intended purpose of the mapped window as we don't get that information
-- during the segment allocation stage for wayland/x11
		if (wnd.ws_attach) then
			if (wnd.surface_type) then
				apply_type_size(wnd, source, status);
			else
				log("x11:kind=status:message=no type defer_attach");
				wnd.defer_resize = status;
				return;
			end
		else
			resize(wnd, status);
		end
	else
		log("x11:error_message=unhandled:event=" .. status.kind);
	end
end

return {
	atype = "wayland-x11",
	actions = {
		name = "xwayland",
		label = "Xwayland",
		description = "Surfaces that comes from an Xwayland server",
		submenu = true,
		eval = function() return false; end,
		handler = x11_menu,
	},
	init = function(atype, wnd, source)
		wnd:add_handler("move",
		function(wnd, x, y)
			if (wnd.in_drag_move) then
				return;
			end

-- multiple factors affect the final position, since wnd.canvas is possible
-- being animated we can't just resolve that one, and the trick of creating
-- a null-surface, copy transform, instant transform then resolve is pricey
			local space = image_surface_resolve(wnd.space.anchor);
			local rx = x + wnd.pad_left + wnd.ofs_x + space.x;
			local ry = y + wnd.pad_top + wnd.ofs_y + space.y;

			log(fmt("kind=move-x11:source=%d:x=%d:y=%d:ofs=%d,%d:pad_lr=%d:%d:space_xy=%d,%d",
				wnd.external, rx, ry, wnd.ofs_x, wnd.ofs_y, wnd.pad_left, wnd.pad_top, space.x, space.y));

-- need to send where the anchor is, not where the current position is
			target_input(wnd.external, string.format("kind=move:x=%d:y=%d", rx, ry));
		end);
		wnd:add_handler("resize",
		function(wnd, neww, newh, efw, efh)
			log(fmt("kind=resize-x11:name=%s:neww=%.0f:newh=%.0f", wnd.name, neww, newh));

-- workaround for an odd asynch-rase where a window gets resized even though
-- it is dead -- since we will be moving this to the builtin/wayland helper script
-- eventually, just work around it for now
			if valid_vid(wnd.external, TYPE_FRAMESERVER) then
				target_displayhint(wnd.external, neww, newh);
			end
		end);
		wnd:add_handler("destroy",
			function()
				log(fmt("kind=destroy-x11:name=%s:vid=%d", wnd.name, source));

-- since we link to the space order anchor, it won't be destroyed with the window,
-- but at the same time popups and the likes have different life-cycle management
				if (valid_vid(wnd.external)) then
					delete_image(wnd.external);
				end
			end
		);
	end,
	props = {
		kbd_period = 0,
		kbd_delay = 0,
		centered = true,
		scalemode = "client",
		filtermode = FILTER_NONE,
		rate_unlimited = true,
		clipboard_block = true,
		font_block = true,
		block_rz_hint = false,
-- all allocations come via the parent bridge
		allowed_segments = {}
	},
	dispatch = {}
};

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

local function viewport(wnd, status)
-- the behavior for this varies with type
	wayland_debug(string.format(
		"name=%s:type=%s:x=%d:y=%d:parent=%d",
		wnd.name, wnd.surface_type, status.rel_x, status.rel_y, status.parent)
	);
end

local function resize(wnd, status)
	wnd:resize_effective(status.width, status.height, true, true);
end

-- In principle, an x11 surface can request a display global coordinate
-- for reparenting and positioning popups and other 'override_redirect'
-- surfaces with a grab.
local function popup_handler(wnd, source, status, wtype)
	if (status.kind == "viewport") then
		local pid = wayland_wndcookie(status.parent);
		if (not pid) then
			wayland_debug(string.format(
				"x11-%s:viewport:name=%s:parent_id=%d:x=%d:y=%d",
				wtype, wnd.name, status.parent, status.rel_x, status.rel_y)
			);
			link_image(source, active_display().order_anchor);
			order_image(source, 1);
		else
			wayland_debug(string.format(
				"x11-%s:viewport:name=%s:parent=%s:x=%d:y=%d",
				wtype, wnd.name, pid.name, status.rel_x, status.rel_y)
			);
			link_image(source, pid.canvas);
			order_image(source, 1);
		end
		move_image(source, status.rel_x, status.rel_y);

	elseif (status.kind == "terminated") then
		wayland_debug(string.format(
			"x11-%s:destroy:name=%s", wtype, wnd.name));
		wayland_lostwnd(source);
		delete_image(source);

	elseif (status.kind == "resized") then
		wayland_debug(string.format(
			"x11-%s:resized:name=%s:w=%d:h=%d",
			wtype, wnd.name, status.width, status.height)
		);
		resize_image(source, status.width, status.height);
		order_image(source, 2);
		show_image(source);
		local mx, my = mouse_xy();
		move_image(source, mx, my);
	end
end

local function apply_type_size(wnd, status)
	if (wnd.surface_type == "popup" or
		wnd.surface_type == "tooltip" or
		wnd.surface_type == "menu") then
-- destroy the 'container', won't be needed with popup, uncertain
-- what the 'rules' say about the same surface mutating in type, but
-- assume for now that it doesn't.
		wayland_debug(string.format(
			"x11:type=%s:name=%s", wnd.surface_type, wnd.name));
		local newwnd = {name = wnd.name, surface_type = wnd.surface_type};
		local newvid = wnd.external;
		image_inherit_order(newvid, true);
		image_mask_set(newvid, MASK_UNPICKABLE);

		wayland_debug("switch-handler:" .. tostring(newvid));
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

		wnd.external = nil;
		wnd:destroy();

-- normal? then we just attach as any old window
	else
		wnd:ws_attach();
		if (status) then
			resize(wnd, status);
		end
	end
end

function x11_event_handler(wnd, source, status)
	if (status.kind == "terminated") then
		wayland_lostwnd(source);
		wnd:destroy();

	elseif (status.kind == "registered") then
		wnd:set_guid(status.guid);

	elseif (status.kind == "viewport") then
		if (wnd.surface_type) then
			viewport(wnd, status);
		else
			wnd.last_viewport = status;
		end

	elseif (status.kind == "message") then
-- our regular dispatch table of 'special hacks'
		local opts = string.split(status.message, ":");

		if (not opts or not opts[1]) then
			wayland_debug(string.format(
				"x11:error_message=unknown:name=%s:raw=%s", wnd.name, status.message));
		end

		if (opts[1] == "type") then
			wnd.surface_type = opts[2];
			apply_type_size(wnd, wnd.defer_resize);
			wnd.defer_size = nil;
		else
			wayland_debug(string.format("x11:error_message=unknown:name=%s", wnd.name));
		end

	elseif (status.kind == "segment_requested") then
		wayland_debug("x11:error_message=subsegment_request");

	elseif (status.kind == "resized") then
-- we actually only attach on the first buffer delivery when we also know
-- the intended purpose of the mapped window as we don't get that information
-- during the segment allocation stage for wayland/x11
		if (wnd.ws_attach) then
			if (wnd.surface_type) then
				apply_type_size(wnd, status);
			else
				wnd.defer_resize = status;
				return;
			end
		end
	else
		wayland_debug("x11:error_message=unhandled:event=" .. status.kind);
	end
end

return {
	atype = "x11surface",
	actions = {
		name = "x11surface",
		label = "Xsurface",
		description = "Surfaces that comes from an X server",
		submenu = true,
		eval = function() return false; end,
		handler = x11_menu,
	},
	init = function(atype, wnd, source)
		wnd:add_handler("resize", function(wnd, neww, newh, efw, efh)
			target_displayhint(wnd.external, neww, newh);
		end);
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

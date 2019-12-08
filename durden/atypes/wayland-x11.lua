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
--
-- Since this can be used for UI- redressing style nastyness, it should
-- be an option if the user wants this or not.
--
local function popup_handler(wnd, source, status, wtype)
	if (status.kind == "viewport") then
		local pid = wayland_wndcookie(status.parent);
		if (not pid or not valid_vid(pid.canvas)) then
			wayland_debug(string.format(
				"x11-%s:viewport:name=%s:parent_id=%d:x=%d:y=%d:anchor=global",
				wtype, wnd.name, status.parent, status.rel_x, status.rel_y)
			);
			link_image(source, active_display().order_anchor);
			order_image(source, 1);
		else
			wayland_debug(string.format(
				"x11-%s:viewport:name=%s:parent=%s:x=%d:y=%d:anchor=parent",
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
	end
end

-- tray-icons are also a bit special, a separate window for
-- _NET_SYSTEM_TRAY_S0 are needed along with a SYSTEM_TRAY_REQUEST_DOCK,
-- then the icon itself comes from _NET_WM_ICON, and notifications go
-- as 'balloon messages'.

local function apply_type_size(wnd, source, status)
	if (wnd.surface_type == "popup" or
		wnd.surface_type == "dropdown" or
		wnd.surface_type == "tooltip" or
		wnd.surface_type == "menu" or
		wnd.surface_type == "utility") then
-- destroy the 'container', won't be needed with popup, uncertain
-- what the 'rules' say about the same surface mutating in type, but
-- assume for now that it doesn't. Likely need different positioning
-- constraints based on the different types
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

	elseif (wnd.surface_type == "icon") then
-- treat the rest as normal windows
		wayland_debug("x11:message=eimpl:kind=icon");
	else
		if (wnd.ws_attach) then
			wayland_debug(string.format(
				"x11:type=%s:name=%s:status=attach_fwd", wnd.surface_type, wnd.name));
			wnd:ws_attach();
		end

		if (status) then
			resize(wnd, status);
		end
	end
end

function x11_event_handler(wnd, source, status)
	wayland_debug(string.format(
		"status=event:event=%s:name=%s", status.kind, wnd.name));

	if (status.kind == "terminated") then
		wayland_lostwnd(source);
		wnd:destroy();

	elseif (status.kind == "registered") then
		wnd:set_guid(status.guid);

	elseif (status.kind == "viewport") then
		if (wnd.surface_type) then
			viewport(wnd, status);
		else
			wayland_debug(string.format(
				"status=deferred:event=%s:name=%s", status.kind, wnd.name));
			wnd.last_viewport = status;
		end

	elseif (status.kind == "message") then
-- our regular dispatch table of 'special hacks'
		local opts = string.split(status.message, ":");

		if (not opts or not opts[1]) then
			wayland_debug(string.format(
				"x11:error_message=unknown:name=%s:raw=%s", wnd.name, status.message));
		end

		if (opts[1] == "type" and opts[2]) then
			wayland_debug(string.format("x11:set_type=%s:name=%s", opts[2], wnd.name));
			wnd.surface_type = opts[2];
			apply_type_size(wnd, source, wnd.defer_resize);
			wnd.defer_size = nil;
		else
			wayland_debug(string.format(
				"x11:error_message=unknown:command=%s:name=%s", opts[1], wnd.name));
		end

	elseif (status.kind == "segment_requested") then
		wayland_debug("x11:error_message=subsegment_request");

	elseif (status.kind == "resized") then
-- we actually only attach on the first buffer delivery when we also know
-- the intended purpose of the mapped window as we don't get that information
-- during the segment allocation stage for wayland/x11
		if (wnd.ws_attach) then
			if (wnd.surface_type) then
				apply_type_size(wnd, source, status);
			else
				wayland_debug("x11:kind=status:message=no type defer_attach");
				wnd.defer_resize = status;
				return;
			end
		else
			resize(wnd, status);
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

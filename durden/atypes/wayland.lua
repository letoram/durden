--
-- Wayland- bridge, special protocol considerations for use with
-- arcan/src/tools/wlbridge.
--
local wlwnds = {}; -- vid->window allocation tracking
local wlsurf = {}; -- segment cookie->vi tracking
local wlsubsurf = {}; -- track subsurfaces to build hierarchies [cookie->vid]

-- also used in xdg- ... so global scope
wayland_debug = suppl_add_logfn("wayland");

function wayland_wndcookie(id)
	return wlsurf[id] and wlwnds[wlsurf[id]];
end

function wayland_lostwnd(source, id)
	wayland_debug("dropped:source=" .. tostring(source));
	wlwnds[source] = nil;
	if (id) then
		wlsurf[id] = nil;
		wlsubsurf[id] = nil;
	end
end

function wayland_gotwnd(source, wnd)
	wayland_debug("added:source=" .. tostring(source));
	wlwnds[source] = wnd;
end

local function subsurf_handler(cl, source, status)
	if (status.kind == "resized") then
		resize_image(source, status.width, status.height);
		wayland_debug(
			string.format("subsurface:resize:w=%.0f:h=%.0f", status.width, status.height));

	elseif (status.kind == "viewport") then
-- all subsurfaces need to specify a parent
		wayland_debug(string.format("viewport:x=%.0f:y=%.0f:z=%.0f:parent=%d",
			status.rel_x, status.rel_y, status.rel_order, status.parent));
		if (status.parent == 0) then
			return;
		end

-- it can be either another subsurface or a window
		local pvid;
		if (wlsubsurf[status.parent]) then
			pvid = wlsubsurf[status.parent];
		elseif (wlsurf[status.parent]) then
			pvid = wlsurf[status.parent];
			if (pvid and wlwnds[pvid]) then
				pvid = wlwnds[pvid].canvas;
			else
				pvid = nil;
			end
		end

-- can't reparent to invalid surface
		if (not valid_vid(pvid)) then
			wayland_debug("viewport_error:invalid_parent");
			delete_image(source);
			return;
		end

-- easy for a malicious client to subsurface->hierarchy its way to go
-- outside the range of allowed client order values
		link_image(source, pvid);
		image_inherit_order(source, true);
		move_image(source, status.rel_x, status.rel_y);
		show_image(source);
		order_image(source, status.rel_order);

	elseif (status.kind == "terminated") then
		wayland_debug("subsurface:terminated");
		delete_image(source);
		wlsubsurf[source] = nil;
	end
end

local function popup_handler(cl, source, status)
-- account for popup being able to resize itself
	if (status.kind == "resized") then
		wayland_debug(
			string.format("popup:resize:w=%.0f:h=%.0f", status.width, status.height));
		resize_image(source, status.width, status.height);
		local wnd = wlwnds[source];
		if (not wnd) then
			return;
		end
		wnd:show();
		if (wnd.popup_state) then
			wnd:reposition(wnd.popup_state[1], wnd.popup_state[2],
				wnd.popup_state[3], wnd.popup_state[4], wnd.popup_state[5]);
		end

-- wayland popups aren't very useful unless there's a relation so
-- defer until we receive something
	elseif (status.kind == "viewport") then
		local pid = wlsurf[status.parent];
		if (not pid or not wlwnds[pid]) then
			wayland_debug("popup:viewport_error=no_parent");
			wlwnds[source] = nil;
			delete_image(source);
			return;
		end

-- border attribute isn't used, wayland has geometry for this instead
		wayland_debug(
			string.format("popup:viewport:visible=%s:x=%.0f:y=%.0f:z=%f:w=%.0f:h=%.0f:" ..
				"edge=%d:anchor_edge=%s:anchor_pos=%s:focus=%s",
				status.invisible and "yes" or "no",
				status.rel_x, status.rel_y, status.rel_order,
				status.anchor_w, status.anchor_h, status.edge,
				status.anchor_edge and "yes" or "no",
				status.anchor_pos and "yes" or "no",
				status.focus and "yes" or "no"
			)
		);

-- a popup shares a window container with others
		if (not wlwnds[source]) then
			local pop = wlwnds[pid]:add_popup(source, true,
				function()
					wlwnds[source] = nil;
				end);
			if (not pop) then
				delete_image(source);
				return;
			end
			wlwnds[source] = pop;
		end

		local wnd = wlwnds[source];
-- hide/show?
		wnd[status.invisible and "hide" or "show"](wlwnds[source]);

		local ox = wlwnds[pid].geom and wlwnds[pid].geom[1] or 0;
		local oy = wlwnds[pid].geom and wlwnds[pid].geom[2] or 0;
		status.rel_x = status.rel_x + ox;
		status.rel_y = status.rel_y + oy;
		wnd.popup_state = {
			status.rel_x, status.rel_y, status.rel_x + status.anchor_w,
			status.rel_y + status.anchor_h, status.edge
		};

-- the overflow rules are more complex in xdg, but for now, just have the
-- corner overflows "stack"

		wnd:reposition(wnd.popup_state[1], wnd.popup_state[2],
			wnd.popup_state[3], wnd.popup_state[4], wnd.popup_state[5]);

-- don't allow it to be relatively- ordered outside it's allocated limit
		local order = status.rel_order > 5 and 5 or
			(status.rel_order < -5 and -5 or status.rel_order);
		order_image(wnd.anchor, order);

-- not all popups require input focus (tooltips!), but when they do,
-- we can cascade delete any possible children
		if (status.focus) then
			wnd:focus();
		end

-- note: additional popups are not created on a popup itself, but rather
-- derived from the main client connection
	elseif (status.kind == "terminated") then
		wayland_debug(string.format("popup:source=%d:destroy", source));
		if (wlwnds[source]) then
			wlwnds[source]:destroy();
		else
			delete_image(source);
		end
		wlwnds[source] = nil;
	end
end

local function cursor_handler(cl, source, status)
-- cursor has changed size
	if (status.kind == "resized") then
		cl.seat_cursor = {
			vid = source,
			active = true,
			width = status.width,
			height = status.height,
			hotspot_x = 0,
			hotspot_y = 0
		};
-- propagate to all children on seat
		for k,v in ipairs(cl.wl_children) do
			v.custom_cursor = cl.seat_cursor;
			if (active_display().selected == v) then
				mouse_custom_cursor(v.custom_cursor);
			end
		end
-- if active window is part of wlwnds and has this cursor...
	elseif (status.kind == "message") then
		wayland_debug(string.format("cursor:hotspot=%s", status.message));
	elseif (status.kind == "terminated") then
		delete_image(source);
		wlwnds[source] = nil;
	end
end

local seglut = {};
local function build_application_window(wnd, source, stat, opts, atype, handler)
-- need to wait with assigning a handler since we want to forward a new window
	local ad = active_display();
	local neww, newh = ad:suggest_size();
	local id, aid, cookie = accept_target(neww, newh);
	wayland_debug(string.format("build_window:vid=%d:type=%s", id, atype));

	if (not valid_vid(id)) then
		wayland_debug("build_window:status=error:message=accept alloc failed");
		return false;
	end

-- We need to track these so that reparenting is possible, viewport events
-- carry the cookie of the window they're targeting.
	if (cookie > 0) then
		wayland_debug(string.format("register:cookie=%d", id));
		wlsurf[cookie] = id;
	end

	if (not wnd.wl_children) then
		wnd.wl_children = {};
	end

-- build window, forward options, add our type specific patches as well
	local newwnd = active_display():add_hidden_window(id, opts);
	if (not newwnd) then
		return false;
	end
	newwnd.wl_autossd = opts.auto_ssd;

-- since the 'registered' event won't get routed past the extevh, we need
-- to manually apply the atype for the toplevel here - this does not attach/
-- cascade a resize though
	extevh_apply_atype(newwnd, atype, id, stat);
	newwnd.source_audio = aid;
	newwnd.cookie = cookie;

-- chain to the handler, expose the window to the handler
	target_updatehandler(id,
		function(source, status)
			handler(newwnd, source, status);
		end
	);

-- keep separate track of the wayland windows so that we don't mix and match,
-- a wlwnd shouldn't be able to reparent to one that isn't
	wlwnds[id] = newwnd;
	table.insert(wnd.wl_children, newwnd);

-- and keep track of the bridge node where this was allocated, as there might
-- be multiple that we want to keep separated
	newwnd.bridge = wnd;

	return true;
end

seglut["application"] = function(wnd, source, stat)
	return build_application_window(wnd, source, stat, {
		show_titlebar = false,
		show_border = false,
		auto_ssd = gconfig_get("wl_decorations") == "autossd",
	}, "wayland-toplevel", wayland_toplevel_handler);
end

seglut["bridge-x11"] = function(wnd, source, stat)
	return build_application_window(wnd, source, stat, {
	}, "x11surface", x11_event_handler);
end

-- so this is part of the s[hi,ea]t concept, the same custom cursor is shared
-- between all windows of the same client. The backing connection should be
-- a singleton.
seglut["cursor"] = function(wnd, source, stat)
	if (wnd.seat_cursor) then
		wayland_debug("cursor:error=multiple cursors on seat");
		return;
	end

	local vid = accept_target(
		function(a, b) cursor_handler(wnd,a,b);
	end);

-- bind lifecycle, custom cursor- tracking struct, etc.
-- is performed in the resized- handler for the callback
	if (valid_vid(vid)) then
		link_image(vid, wnd.anchor);
		return true;
	end
end

seglut["popup"] = function(wnd, source, stat)
	local vid, aid, cookie = accept_target(
		function(...) popup_handler(wnd, ...);
	end);

	if (valid_vid(vid)) then
		wlsurf[cookie] = vid;
		link_image(vid, wnd.anchor);
		return true;
	end
end

seglut["multimedia"] = function(wnd, source, stat)
	local vid, aid, cookie = accept_target(
		function(...)
			subsurf_handler(wnd, ...);
		end
	);
	wlsubsurf[vid] = cookie;

	if (valid_vid(vid)) then
		link_image(vid, wnd.anchor);
		image_mask_set(vid, MASK_UNPICKABLE);
		return true;
	end
end

seglut["clipboard"] = function(wnd, source, stat)
	wayland_debug("clipboard:error=not implemented");
end

local function wayland_buildwnd(wnd, source, stat)
-- register a new window, but we want control over the window setup so we just
-- use the 'launch' function to create and register the window then install our
-- own handler
	wayland_debug(string.format("request:kind=%s", stat.segkind));

	if (seglut[stat.segkind]) then
		seglut[stat.segkind](wnd, source, stat);

	else
		wayland_debug(string.format("request:error=unknown kind %s", stat.segkind));
		wnd:destroy();
	end

	return true;
end

gconfig_register("wl_decorations", "client");
local wayland_settings = {
{
	name = "decorations",
	label = "Decorations",
	kind = "value",
	description = "Set the default decoration policy for new clients",
	set = {"client", "autossd"},
	handler = function(ctx, val)
		gconfig_set("wl_decorations", val);
	end
}
};

menus_register("global", "settings",
{
	name = "wayland",
	label = "Wayland",
	kind = "action",
	submenu = true,
	description = "Global settings for all wayland clients",
-- disable for now, code isn't all too robust
	eval = function() return false; end,
	handler = wayland_settings
});

return {
	atype = "bridge-wayland",
	default_shader = {"simple", "noalpha"},
	actions = {},

-- these are for the BRIDGE surface, that's different for the subsegments
-- that will be requested. Due to how wayland works vs. how arcan works,
-- we need to implement separate handlers for the subsegment requests in
-- order to activate the correct scalemodes, decoration modes and message-
-- handler hacks to have a chance of working around the extension mess.
	props = {
		wl_children = {},
		kbd_period = 0,
		kbd_delay = 0,
		centered = true,
		scalemode = "client",
		filtermode = FILTER_NONE,
		rate_unlimited = true,

-- might need to / want to revisit this and use one shared clipboard for
-- all wayland clients, breaks consistency somewhat but it's wayland ..
		clipboard_block = true,
		font_block = true,
		allowed_segments = {},
		attach_block = true
	},

	dispatch = {
		preroll = function(wnd, source, tbl)

-- (TOREM) the bridge need privileged GPU access in order to bind display
			target_displayhint(source,
				wnd.max_w, wnd.max_h, 0, active_display().disptbl);

			if (TARGET_ALLOWGPU ~= nil and gconfig_get("gpu_auth") == "full") then
				target_flags(source, TARGET_ALLOWGPU);
			end

-- client implements repeat on wayland, se we need to set it here, but
-- quite frankly, just disable it to 0 0 and force server-side repeat
-- is probably the better option.
			message_target(source,
				string.format("seat:rate:%d,%d",
					gconfig_get("kbd_period"), gconfig_get("kbd_delay")));
			return true;
		end,

		segment_request = wayland_buildwnd,
	}
};

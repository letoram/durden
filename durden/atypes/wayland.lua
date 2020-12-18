--
-- Wayland- bridge, special protocol considerations for use with arcan-wayland
-- These should eventually merge with the upstream builtin/wayland and
-- builtin/decorator.
--
local wlwnds = {}; -- vid->window allocation tracking
local wlsurf = {}; -- segment cookie->vi tracking
local wlsubsurf = {}; -- track subsurfaces to build hierarchies [cookie->vid]

local log, fmt = suppl_add_logfn("wayland");
local wayland_buildwnd;

function wayland_wndcookie(id)
	return wlsurf[id] and wlwnds[wlsurf[id]];
end

function wayland_resources()
	return wlwnds, wlsurf, wlsubsurf;
end

function wayland_lostwnd(source, id)
	log("dropped:source=" .. tostring(source));
	wlwnds[source] = nil;
	if (id) then
		wlsurf[id] = nil;
		wlsubsurf[id] = nil;
	end
end

function wayland_gotwnd(source, wnd)
	log("added:source=" .. tostring(source));
	wlwnds[source] = wnd;
end

local bridge_dispatch =
{
	segment_request =
	function(...)
		return wayland_buildwnd(...)
	end,

-- allow the destruction to chain, most windows clean up themselves but
-- we want to de-register as a clipboard provider
	terminated =
	function(wnd, ...)
		CLIPBOARD:set_provider(wnd)
		return false;
	end,
}

bridge_dispatch.preroll =
function(wnd, source, tbl)
-- the bridge needs information about the output, right now we assume this
-- is the same one as the currently active - and then re-send on display
-- migration
	target_displayhint(source,
		active_display().width, active_display().height, 0,
		display_output_table(nil)
	);

-- ideally we should update this when the spawn target changes, but there is
-- currently no plumbing for this, and the spawn-size estimation is also
-- incorrect.
	log("kind=bridge_connected:vid=" .. tostring(source));

	if (TARGET_ALLOWGPU ~= nil and gconfig_get("gpu_auth") == "full") then
		target_flags(source, TARGET_ALLOWGPU);
	end

-- client implements repeat on wayland, se we need to set it here, but
-- quite frankly, just disable it to 0 0 and force server-side repeat
-- is probably the better option.
	message_target(source,
		string.format("seat:rate:%d,%d",
			gconfig_get("kbd_period"), gconfig_get("kbd_delay")));

-- remove whatever handler already exists
	target_updatehandler(source,
	function(source, status, ...)
		if not bridge_dispatch[status.kind] then
			log(fmt("kind=bridge:missing=%s", status.kind))
			return
		else
			return bridge_dispatch[status.kind](wnd, source, status, ...)
		end
	end)
	return true;
end

local function period(wnd, source)
	local inbuf, ok = wnd.ioblock:read(true)

-- no data yet?
	if inbuf == nil and ok then
		return
	end

	if #inbuf > 0 then
		wnd.buffer_sz = wnd.buffer_sz + #inbuf;
		log("clipboard:count=" .. tostring(wnd.buffer_sz))
		table.insert(wnd.clip_buffer, inbuf);
	end

	local overflow = wnd.buffer_sz >= 64 * 256;

-- have we reached a terminal part yet? (eof or overflow)
	if not ok or overflow then
		local msg = table.concat(wnd.clip_buffer, "")
		CLIPBOARD:add(source, msg, false)

		wnd.ioblock:close()
		timer_delete(wnd.timer_name)
		wnd.ioblock = nil
		wnd.clip_buffer = nil
	end
end

bridge_dispatch.message =
function(wnd, source, tbl)
	local cmd, data = string.split_first(tbl.message, ":")
	log(fmt("bridge-messsage=%s", cmd))

	if cmd == "offer" then
		if not wnd.offer_types then
			wnd.offer_types = {}
		end

		if table.find_i(wnd.offer_types, data) then
			return
		end

		table.insert(wnd.offer_types, data)

-- if we get a text-plain, try and sample it and see what's in there -
-- since wayland works on mimetypes and bchunk on sanitised extensions
-- the workaround is a message based selector - if the pre-read data
-- turns out to be less than some buffer size, just add it as a normal
-- clipboard entry - otherwise set it as a possible provider
		if data == "text/plain;charset=utf-8" and not wnd.ioblock then
			message_target(source, "select:" .. data);
			wnd.ioblock = open_nonblock(source, false);

			wnd.clip_buffer = {};
			wnd.timer_name = "wl-clip_" .. wnd.name;
			wnd.buffer_sz = 0;

-- this tells the clipboard that the window is available for offering
-- the specific set of types (wnd act as key/index so repeated calls
-- will update) - the callback is triggered when a paste operation is
-- provided through this provider, the 'dst' is the target window,
-- send a message about the type and bond_target
			CLIPBOARD:set_provider(wnd, wnd.offer_types,
				function(dst, typestr)
					log("request copy of " .. typestr);
				end
			)

-- there is still no callback / interrupt driven non-block interface,
-- when that is fixed in arcan we'll just switch to that
			timer_add_periodic(wnd.timer_name,
				1, false, function() period(wnd, source); end, true);
			period(wnd);

-- the remainder is handled in the target/clipboard/paste style ops
		end

	elseif cmd == "offer-reset" then
		wnd.offer_types = {}
	end
	if cmd ~= "offer" then
		return
	end

end

function wayland_debug_wnd()
	local wnd = active_display().selected;
	local vid = target_alloc(wnd.bridge.external, function() end, "debug");
	if not valid_vid(vid) then
		return;
	end

	local newwnd = durden_launch(vid, "debug", "");
	if (not newwnd) then
		return;
	end

-- let the debug window spawn new terminals
	extevh_apply_atype(newwnd, "tui", vid, {});
	newwnd.allowed_segments = table.copy(newwnd.allowed_segments);
	table.insert(newwnd.allowed_segments, "handover");
end

local function subsurf_handler(cl, source, status)
	if (status.kind == "resized") then
		resize_image(source, status.width, status.height);
		log(fmt("subsurface:resize:w=%.0f:h=%.0f", status.width, status.height));

	elseif (status.kind == "viewport") then
-- all subsurfaces need to specify a parent
		log(fmt("viewport:x=%.0f:y=%.0f:z=%.0f:parent=%d",
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
			log("viewport_error:invalid_parent");
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
		log("subsurface:terminated");
		delete_image(source);
		wlsubsurf[source] = nil;
	end
end

local function popup_handler(cl, source, status)
-- account for popup being able to resize itself
	if (status.kind == "resized") then
		log(fmt("popup:resize:w=%.0f:h=%.0f", status.width, status.height));
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
			log("popup:viewport_error=no_parent");
			wlwnds[source] = nil;
			delete_image(source);
			return;
		end

-- border attribute isn't used, wayland has geometry for this instead
		log(fmt("popup:viewport:visible=%s:x=%.0f:y=%.0f:z=%f:w=%.0f:h=%.0f:" ..
				"edge=%d:anchor_edge=%s:anchor_pos=%s:focus=%s",
				status.invisible and "no" or "yes",
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
		local pwnd = wlwnds[pid];

-- hide/show?
		wnd[status.invisible and "hide" or "show"](wlwnds[source]);
		if pwnd.geom then
			status.rel_x = status.rel_x + pwnd.geom[1];
			status.rel_y = status.rel_y + pwnd.geom[2];
			log(fmt("popup-parent:x=%d:y=%d", pwnd.geom[1], pwnd.geom[2]));
		end

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
		log(fmt("popup:source=%d:destroy", source));
		if (wlwnds[source]) then
			wlwnds[source]:destroy();
		else
			delete_image(source);
		end
		wlwnds[source] = nil;

	elseif (status.kind == "message") then
		local wnd = wlwnds[source];
		if not wnd then
			log(fmt("popup:source=%d:unknown_wnd:message=%s", source, status.message));
			return;
		end

		local opts = string.split(status.message, ":");
		if opts[1] and opts[1] == "geom" then
			local x, y, w, h;
			x = tonumber(opts[2]);
			y = tonumber(opts[3]);
			w = tonumber(opts[4]);
			h = tonumber(opts[5]);
			if x and y and w and h then
				wnd.geom = {x, y, w, h}
			end
		else
			log(fmt("popup:message=%s", status.message))
		end
	else
		log(fmt("popup:unhandled_event:kind=%s", status.kind))
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
		log(fmt("cursor:hotspot=%s", status.message));

	elseif (status.kind == "terminated") then
		delete_image(source);
		cl.seat_cursor = nil;
		wlwnds[source] = nil;
	end
end

local seglut = {};
local function build_application_window(wnd, source, stat, opts, atype, handler)
-- need to wait with assigning a handler since we want to forward a new window
	local ad = active_display();
	local neww, newh = wnd:suggest_size();
	local id, aid, cookie = accept_target(neww, newh);
	log(fmt("build_window:vid=%d:type=%s", id, atype));

	if (not valid_vid(id)) then
		log("build_window:status=error:message=accept alloc failed");
		return false;
	end
	image_tracetag(id, "wl_unknown");

-- We need to track these so that reparenting is possible, viewport events
-- carry the cookie of the window they're targeting.
	if (cookie > 0) then
		log(string.format("register:cookie=%d", id));
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
		block_shadow = true,
	}, "wayland-toplevel", wayland_toplevel_handler);
end


seglut["bridge-x11"] = function(wnd, source, stat)
	return build_application_window(wnd, source, stat, {
	}, "wayland-x11", x11_event_handler);
end

-- when used in service mode, the bridge-subsegment is the control for
-- a new client - so just tie it to the other bridge and keep track of it
-- though we should probably limit depth to 1
seglut["bridge-wayland"] =
function(wnd, source, stat)
	log(fmt("kind=bridge_client:vid=%d", source));

	local id, aid, cookie =
	accept_target(32, 32,
		function(source, status, ...)
			if not bridge_dispatch[status.kind] then
				log(fmt("kind=bridge:missing=%s", status.kind));
				return
			end

			return bridge_dispatch[status.kind](wnd, source, status, ...);
		end
	)

	if not valid_vid(id) then
		return
	end

	image_tracetag(id, "bridge_wayland");
	link_image(id, wnd.anchor);
	return true
end

-- so this is part of the s[hi,ea]t concept, the same custom cursor is shared
-- between all windows of the same client. The backing connection should be
-- a singleton.
seglut["cursor"] = function(wnd, source, stat)
	if (wnd.seat_cursor) then
		log(fmt(
			"cursor:error=multiple cursors on seat:valid=%s:vid=%d",
			valid_vid(wnd.seat_cursor.vid) and "yes" or "no", wnd.seat_cursor.vid));
		return;
	end

	local vid = accept_target(
		function(a, b)
			return cursor_handler(wnd,a,b);
		end
	);

-- bind lifecycle, custom cursor- tracking struct, etc.
-- is performed in the resized- handler for the callback
	if (valid_vid(vid)) then
		link_image(vid, wnd.anchor);
		image_tracetag(vid, "wayland_cursor");
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
		image_tracetag(vid, "wayland_popup");
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
		image_tracetag(vid, "wayland_subsurface");
		return true;
	end
end

seglut["clipboard"] = function(wnd, source, stat)
	log("clipboard:error=not implemented");
end

wayland_buildwnd =
function(wnd, source, stat)
-- register a new window, but we want control over the window setup so we just
-- use the 'launch' function to create and register the window then install our
-- own handler
	if not wnd.wm then
		delete_image(source)
		return
	end

	log(fmt("request:kind=%s", stat.segkind));
	image_tracetag(source, "wl_" .. stat.segkind);

	if (seglut[stat.segkind]) then
		seglut[stat.segkind](wnd, source, stat);

	else
		log(fmt("request:error=unknown kind %s", stat.segkind));
		wnd:destroy();
	end

	return true;
end

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

	dispatch = bridge_dispatch
};

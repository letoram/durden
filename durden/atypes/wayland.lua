--
-- Wayland- bridge, for use with src/tools/waybridge.
--
local wlwnds = {};

local function wayland_trace(msg)
	if (DEBUGLEVEL > 0) then
		print("WAYLAND", msg);
	end
end

local function subsurf_handler(cl, source, status)
	if (status.kind == "resized") then
		resize_image(source, status.width, status.height);
	elseif (status.kind == "viewport") then
-- can't reparent to invalid surface
		if (not wlwnds[status.parent]) then
			wayland_trace("broken viewport request from subsurface");
			delete_image(source);
		end
		link_image(source, wlwnds[status.parent].anchor);
		image_inherit_order(source, true);
		move_image(source, status.rel_x, status.rel_y);
		show_image(source);
	elseif (status.kind == "terminated") then
		delete_image(source);
	end
end

local function popup_handler(cl, source, status)
-- account for popup being able to resize itself
	if (status.kind == "resized") then
		if (wlwnds[source]) then
			resize_image(source, status.width, status.height);
			wlwnds[source]:show();
		end

-- wayland popups aren't very useful unless there's a relation so
-- defer until we receive something
	elseif (status.kind == "viewport") then
		if (not wlwnds[status.parent]) then
-- error condition if the popup doesn't have a real parent
			delete_image(source);
			return;
		end

-- not known in beforehand? (most common)
		if (not wlwnds[source]) then
			local pop = wlwnds[status.parent]:add_popup(source, true,
				function()
					wlwnds[source] = nil;
				end);
			if (not pop) then
				delete_image(source);
				return;
			end
			wlwnds[source] = pop;
		end

-- hide/show?
		wlwnds[source][status.invisible and "hide" or "show"](wlwnds[source]);

-- position relative to parent, taking anchor region into account
-- some difference between anchor edge and positioner edge, not sure
-- how to deal with this yet
		wlwnds[source]:reposition(
			status.rel_x, status.rel_y, status.rel_x + status.anchor_w,
			status.rel_y + status.anchor_h, status.edge);

-- don't allow it to be relatively- ordered outside it's allocated limit
		local order = status.rel_order > 5 and 5 or
			(status.rel_order < -5 and -5 or status.rel_order);
		order_image(wlwnds[source].anchor, order);

-- not all popups require input focus (tooltips!), but when they do, we can
-- cascade delete any possible children
		if (status.focus) then
			wlwnds[source]:focus();
		end

-- note: additional popups are not created on a popup itself
	elseif (status.kind == "terminated") then
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
		active_display():message("cursor hotspot changed");
	elseif (status.kind == "terminated") then
		delete_image(source);
		wlwnds[source] = nil;
	end
end

local function toplevel_handler(wnd, source, status)
	if (status.kind == "terminated") then
		wlwnds[source] = nil;
		wnd:destroy();
		return;
	elseif (status.kind == "message") then
		local opts = string.split(status.message, ":");

		if (opts) then
			if (opts[1] == "geom" and #opts == 5) then
				local x, y, w, h;
				x = tonumber(opts[2]);
				y = tonumber(opts[3]);
				w = tonumber(opts[4]);
				h = tonumber(opts[5]);
				if (w and y and w and h) then
					wnd.geom = {x, y, w, h};
				end
			end
		end

	elseif (status.kind == "segment_request") then
		active_display():message("SEGMENT REQUEST" .. status.segkind);

	elseif (status.kind == "resized") then
		if (wnd.ws_attach) then
			wnd:ws_attach();
		end
		wnd:resize_effective(status.width, status.height);
	end
end

-- so this is fucking retarded, but we can't use the size of the source
-- storage to figure out anything about what visible size the contents of
-- the client actually has. Why? Client decorations and drop-shadows and
-- quite possibly rotation and scaling nonsense.
-- The configure event (that's how DISPLAYHINT is translated in waybridge)
-- is treated by the client as 'ok, w+A,h+B' where it gets to pick A and
-- B because of decorations. This practically only works on a floating
-- desktop. Our option elsewhere is to burn another resize and take
-- advantage of last known 'geometry event', but since this event only
-- carries xofs+w,yofs+h we then have to subtract from the storage
-- dimensions as the padding region doesn't have to be symmetric.
local function wl_resize(wnd, neww, newh, efw, efh)
	if (neww > 0 and newh > 0) then
		efw = wnd.max_w - wnd.pad_left - wnd.pad_right;
		efh = wnd.max_h - wnd.pad_top - wnd.pad_bottom;

		if (wnd.geom) then
			local props = image_storage_properties(wnd.canvas);
			local pad_w = wnd.geom[1] + props.width - (wnd.geom[1] + wnd.geom[3]);
			local pad_h = wnd.geom[2] + props.height - (wnd.geom[2] + wnd.geom[4]);
			efw = efw - pad_w;
			efh = efh - pad_h;
		end

		wnd.hint_w = efw;
		wnd.hint_h = efh;
		target_displayhint(wnd.external, efw, efh, wnd.dispmask);
	end
end

local function wl_select()
	wayland_trace("select");
end

local function wl_deselect()
	wayland_trace("deselect");
end

local function wl_destroy(wnd)
	wayland_trace("destroy");
end

local function setup_toplevel_wnd(cl, wnd, id)
	wlwnds[id] = wnd;
	wnd.external = id;
	wnd.wl_client = cl;
	target_updatehandler(id, function(source, status)
		toplevel_handler(wnd, source, status);
	end);
	wnd:add_handler("resize", wl_resize);
	wnd:add_handler("select", wl_select);
	wnd:add_handler("deselect", wl_deselect);
	wnd:add_handler("destroy", wl_destroy);
	wnd.scalemode = "client";
	wnd.rate_unlimited = true;
	wnd.font_block = true;
	wnd.clipboard_block = true;
	wnd.kbd_period = 0;
	wnd.kbd_delay = 0;
	wnd.hide_border = true;
	wnd.hide_titlebar = true;
	wnd.filtermode = FILTER_NONE;
	wnd.wl_kind = "toplevel";
	show_image(wnd.canvas);

-- We can't be sure of the order here, but this gets updated
-- whenever there is a new cursor so. The only 'odd' part is
-- what to do when a window is selected and only then a cursor
-- is added.
	wnd.custom_cursor = cl.seat_cursor;
	wayland_trace("toplevel");
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
		kbd_period = 0,
		kbd_delay = 0,
		centered = true,
		scalemode = "none",
		filtermode = FILTER_NONE,
		rate_unlimited = true,
		clipboard_block = true,
		font_block = true,

-- for wl_shell or wl_xdg, the translation is bridge->non-visible connection,
-- application -> toplevel
-- toplevel -> popup
--
		allowed_segments = {},
	},
	dispatch = {
		preroll = function(wnd, source, tbl)
-- the bridge need privileged GPU access in order to bind display
			target_displayhint(source,
				wnd.max_w, wnd.max_h, 0, active_display().disptbl);

			if (TARGET_ALLOWGPU ~= nil and gconfig_get("gpu_auth") == "full") then
				target_flags(source, TARGET_ALLOWGPU);
			end
			wnd.wl_children = {};
-- client implements repeat on wayland, se we need to set it here
			message_target(source,
				string.format("seat:rate:%d,%d",
					gconfig_get("kbd_period"), gconfig_get("kbd_delay")));
			return true;
		end,

		segment_request = function(wnd, source, stat)
-- register a new window, but we want control over the window setup so we just
-- use the 'launch' function to create and register the window then install our
-- own handler
			wayland_trace("request: " .. stat.segkind);
			if (stat.segkind == "application") then
				local id = accept_target();
				if (not valid_vid(id)) then
					return true;
				end
				local newwnd = active_display():add_hidden_window(id);
				setup_toplevel_wnd(wnd, newwnd, id);
				table.insert(wnd.wl_children, newwnd);

-- so this is part of the s[hi,ea]t concept, the same custom cursor is shared
-- between all windows of the same client. The backing connection should be
-- a singleton.
			elseif (stat.segkind == "cursor") then
				if (wnd.seat_cursor) then
					wayland_trace("already got cursor on bridge client");
					return;
				end
				local vid = accept_target(function(a, b) cursor_handler(wnd,a,b); end);
				if (valid_vid(vid)) then
-- bind lifecycle, custom cursor- tracking struct and assignment is done in
-- the resized- handler for the callback
					link_image(vid, wnd.anchor);
				end
-- popups and subsurfaces
			elseif (stat.segkind == "popup") then
				local vid = accept_target(function(a,b) popup_handler(wnd, a, b); end);
				if (valid_vid(vid)) then
					link_image(vid, wnd.anchor);
				end
				wayland_trace("popup ok");
			elseif (stat.segkind == "multimedia") then
				local vid = accept_target(function(...) subsurf_handler(wnd, ...); end);
				if (valid_vid(vid)) then
					link_image(vid, wnd.anchor);
				end
				wayland_trace("subsurface ok");
			elseif (stat.segkind == "CLIPBOARD") then
				wayland_trace("data device not supported");
			else
				wayland_trace("unknown: " .. stat.segkind);
			end
			return true;
		end
	}
};

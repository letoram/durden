--
-- Wayland- bridge, for use with src/tools/waybridge.
--
local wlwnds = {};

local function wayland_trace(msg)
	print("WAYLAND", msg);
end

local function popup_handler(source, status)
	if (status.kind == "terminated") then
		delete_image(source);
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
	active_display():message("toplevel:", status.kind);
	if (status.kind == "terminated") then
		wlwnds[source] = nil;
		wnd:destroy();
		return;
	elseif (status.kind == "message") then
		local opts = string.split(status.message, ":");
		if (opts) then
			if (opts[1] == "geom" and #opts == 5) then
				active_display():message(string.format("x: %d, y: %d, w: %d, h: %d"));
			end
		end

	elseif (status.kind == "resized") then
		if (wnd.ws_attach) then
			wnd:ws_attach();
		end
		wnd:resize_effective(status.width, status.height);
	end
end

-- so this is fucking retarded, but we can't use the size of the source
-- storage to figure out anything about what visible size the contents of
-- the client actually has. Why? Client decorations and drop-shadows.
-- The configure event (that's how DISPLAYHINT is translated in waybridge)
-- is treated by the client as 'ok, w+A,h+B' where it gets to pick A and
-- B because of decorations. This practically only works on a floating
-- desktop. Our option elsewhere is essentially just to run with autocrop.
local function wl_resize(wnd, neww, newh, efw, efh)
	if (wnd.space.mode == "float") then
		target_displayhint(wnd.external, neww, newh, wnd.dispmask);
	elseif (neww > 0 and newh > 0) then
		target_displayhint(wnd.external, wnd.max_w, wnd.max_h, wnd.dispmask);
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
-- handler hacks t3o have a chance of working around the extension mess.
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
		allowed_segments = {},
	},
	dispatch = {
		preroll = function(wnd, source, tbl)
-- the bridge need privileged GPU access in order to bind display
			target_displayhint(source, wnd.max_w, wnd.max_h, 0, active_display().disptbl);
			if (TARGET_ALLOWGPU ~= nil and gconfig_get("gpu_auth") == "full") then
				target_flags(source, TARGET_ALLOWGPU);
			end
			wnd.wl_children = {};
-- client implements repeat on wayland, se we need to set it here
			message_target(source,
				string.format("seat:rate:%d,%d", gconfig_get("kbd_period"), gconfig_get("kbd_delay")));
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
			elseif (stat.segkind == "popup") then
				local vid = accept_target(popup_handler);
-- just anchor to window, order it above the normal surface
-- and respect viewport hint to position regardless of mode.
-- This likely fails in fullscreen etc.
				link_image(vid, wnd.anchor);
			else
				wayland_trace("unknown: " .. stat.segkind);
			end
			return true;
		end
	}
};

--
-- Wayland- bridge, for use with src/tools/waybridge.
--

local function popup_handler(source, status)
	if (status.kind == "terminated") then
		delete_image(source);
	end
end

local function cursor_handler(source, status)
	if (status.kind == "terminated") then
		delete_image(source);
	end
end

local function toplevel_handler(wnd, source, status)
	if (status.kind == "terminated") then
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
		wnd:resize(status.width, status.height);
	end

	print("wayland", source, status.kind);
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
	print("wl_select");
end

local function wl_deselect()
	print("wl_deselect");
end

local function wl_destroy(wnd)
	print("wl_destroy");
end

local function setup_toplevel_wnd(wnd, id)
	wnd.external = id;
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
	wnd.filtermode = FILTER_NONE;
	show_image(wnd.canvas);
end

return {
	atype = "bridge-wayland",
	default_shader = {"simple", "noalpha"},
	actions = {},

-- these are for the BRIDGE surface, that's different for the subsegments
-- that will be requested. Due to how wayland works vs. how arcan works,
-- we need to implement separate handlers for the subsegment requests in
-- order to activate the correct scalemodes and decoration modes.
	props = {
		kbd_period = 0,
		kbd_delay = 0,
		centered = true,
		scalemode = "none",
		filtermode = FILTER_NONE,
		rate_unlimited = true,
		clipboard_block = true,
		font_block = true,
-- so, depending on the protocol state we may or may not have decorations
--		hide_titlebar = true,
--		hide_border = true,

-- for wl_shell or wl_xdg, the translation is bridge->non-visible connection,
-- application -> toplevel
-- toplevel -> popup
		allowed_segments = {},
	},
	dispatch = {
		preroll = function(wnd, source, tbl)
			target_displayhint(source, wnd.max_w, wnd.max_h, 0, active_display().disptbl);
			if (TARGET_ALLOWGPU ~= nil and gconfig_get("gpu_auth") == "full") then
				target_flags(source, TARGET_ALLOWGPU);
			end
			return true;
		end,

		segment_request = function(wnd, source, stat)
-- register a new window, but we want control over the window setup so we just
-- use the 'launch' function to create and register the window then install our
-- own handler
			if (stat.segkind == "application") then
				local id = accept_target();
				if (not valid_vid(id)) then
					return true;
				end
				wnd = active_display():add_hidden_window(id);
				setup_toplevel_wnd(wnd, id);
			elseif (stat.segkind == "cursor") then
				local vid = accept_target(cursor_handler);
				if (valid_vid(vid)) then
					link_image(vid, source);
				end
			elseif (stat.segkind == "popup") then
				local vid = accept_target(popup_handler);
				if (valid_vid(vid)) then
					link_image(vid, source);
				end
			else
				print("unknown segkind:", stat.segkind);
			end
			return true;
		end
	}
};

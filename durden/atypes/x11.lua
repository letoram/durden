--
-- X11- bridge, for use with Xarcan.
--

local
function metawm_viewport(wnd, src, tbl)
end

--
-- these serialize the scenegraph changes prior to submitting a frame
local
function metawm_message(wnd, src, tbl)
	local args = string.unpack_shmif_argstr(tbl.message);
end

local
function metawm_preroll(wnd, source, tbl)
	local auto = gconfig_get("xarcan_autows");

-- find an empty workspace, switch to that mode and displayhint based on that window
	if auto ~= "none" then
		local disp = active_display()
		for i=1,10 do
			if disp.spaces[i] == nil then
				wnd.default_workspace = i
				break
			end
		end

-- actually create / attach before we have contents which isn't the default
-- otherwise but now the space would have been created and can be forced to the
-- auto mode with some special sauce for the floating layout.
		if wnd.ws_attach then
			wnd:ws_attach();
			wnd.last_float = {width = 1.0, height = 1.0, x = 0, y = 0};
		end

-- automatically disable the border / shadow / titlebar so it effectively becomes
-- fullscreen with statusbar for float-mode.
		if wnd.space and wnd.space[auto] then
			wnd.space[auto](wnd.space)
-- automatically tag the workspace name with the instance identity so that we see
-- what the corresponding DISPLAY=: should be.
			if gconfig_get("xarcan_autows_tagname") then
				local label = ""
				wnd.set_ident =
				function(wnd, msg)
					wnd.ident = ident
					label = "X11:" .. (msg or "")
					wnd.space:set_label(label)
				end

-- untag the label on destruction so workspace autopruning won't try to save it
			table.insert(
				wnd.handlers.destroy,
				function()
					wnd.space:set_label()
				end
			)
			end
		end

		if gconfig_get("xarcan_autows_nodecor") then
			wnd.want_shadow = false;
			wnd:set_titlebar(false);
			wnd:set_border(false, true, 0);
		end

		if gconfig_get("xarcan_clipboard_autopaste") then
			dispatch_symbol_wnd(wnd, "/target/clipboard/autopaste_on");
		end
	end

-- Allow larger / quicker event dispatches inbound as Xarcan can be quite loud
-- when WM state synch is permitted. This could've been done over a bchunk-
-- stream instead, but with this approach the synchronisation between transfer
-- and frame-update will be in the same band.
	if gconfig_get("xarcan_metawm") then
		target_flags(source, TARGET_VERBOSE);
		target_flags(source, TARGET_DRAINQUEUE);
		target_input(source, "kind=synch");
	end

	target_displayhint(source, wnd.max_w, wnd.max_h, 0, display_output_table(nil));
	if (TARGET_ALLOWGPU ~= nil and gconfig_get("gpu_auth") == "full") then
		target_flags(source, TARGET_ALLOWGPU);
	end
end

return {
	atype = "bridge-x11",
	default_shader = {"simple", "noalpha"},
	actions = {},
-- props will be projected upon the window during setup (unless there
-- are overridden defaults)
	props =
	{
		kbd_period = 0,
		kbd_delay = 0,
		centered = true,
		scalemode = "normal",
		filtermode = FILTER_NONE,
		rate_unlimited = true,
		clipboard_block = false,
		font_block = true,
	},
	dispatch =
	{
		viewport = metawm_viewport,
		message = metawm_message,
		preroll = metawm_preroll
	}
};

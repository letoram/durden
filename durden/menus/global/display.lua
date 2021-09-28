local function orientation_menu(name)
	return {
		{
			name = "default",
			label = "Default",
			description = "Set the display orientation to best for initial size",
			kind = "action",
			handler = function()
				display_reorient(name, 0)
			end
		},
		{
			name = "90_cw",
			label = "+90",
			kind = "action",
			description = "Rotate 90 degrees clockwise",
			handler = function()
				display_reorient(name, HINT_ROTATE_CW_90);
			end
		},
		{
			name = "90_ccw",
			label = "-90",
			kind = "action",
			description = "Rotate 90 degrees counter-clockwise",
			handler = function()
				display_reorient(name, HINT_ROTATE_CCW_90);
			end
		},
		{
			name = "180",
			label = "180",
			kind = "action",
			description = "Invert the Y axis",
			eval = function()
				return HINT_ROTATE_180 ~= nil;
			end,
			handler = function()
				display_reorient(name, HINT_ROTATE_180);
			end,
		},
		{
			name = "flip_y",
			label = "Invert Y",
			kind = "action",
			description = "Invert the Y axis",
			handler = function()
				display_reorient(name, HINT_YFLIP);
			end,
		}
	};
end

local function query_synch()
	local lst = video_synchronization();
	if (lst) then
		local res = {};
-- dynamically populated so we don't expose this globally at the moment
		for k,v in ipairs(lst) do
			res[k] = {
				name = "synch_" .. tostring(k),
				label = v,
				kind = "action",
				description = lst[v] and lst[v] or
					"Set dynamic synchronization strategy to '" .. v .. "'",
				handler = function(ctx)
					video_synchronization(v);
				end
			};
		end
		return res;
	end
end

local function query_dispmenu(ind, name)
	local modes = video_displaymodes(ind);
	if (modes and #modes > 0) then
		local mtbl = {};
		local got_dynamic = true;
		for k,v in ipairs(modes) do
			if (v.dynamic) then
-- incomplete, query for custom desired res?
				got_dynamic = true;
			else
				local modestr = string.format(
						"%d*%d, %d bits @%d Hz", v.width, v.height, v.depth, v.refresh);
				table.insert(mtbl, {
					name = "mode_" .. tostring(k),
					kind = "action",
					description = "Try to set display resolution to (" .. modestr .. ")",
					label = modestr,
					handler = function() display_ressw(name, v); end
				});
			end
		end
		return mtbl;
	else
		return {
			name = "fail",
			label = "Failed",
			description = "Display returned no valid modes, hardware/platform issue",
			kind = "action",
			handler = function()
			end,
		};
	end
end

local function backlight_menu(disp)
	return {
		{
		name = "set",
		label = "Set",
		kind = "value",
		hint = "(0..1)",
		initial = disp.backlight,
		definition = "Control display backlight strength",
		eval = function() return disp.ledctrl ~= nil; end,
		validator = function(val)
			local num = tonumber(val);
			return num and (num >= 0 and num <= 1.0);
		end,
		handler = function(ctx, val)
			disp.backlight = tonumber(val);
			led_intensity(disp.ledctrl, disp.ledid, 255 * disp.backlight);
		end
		},
		{
		name = "step_p",
		label = "+10%",
		description = "Increment backlight intensity by approximately 10%",
		kind = "action",
		definition = "Control display backlight strength",
		handler = function(ctx)
			disp.backlight = math.clamp(disp.backlight + 0.1, 0.0, 1.0);
			led_intensity(disp.ledctrl, disp.ledid, 255 * disp.backlight);
		end
		},
		{
		name = "step_n",
		label = "-10%",
		description = "Decrement backlight intensity by approximately 10%",
		kind = "action",
		definition = "Control display backlight strength",
		handler = function(ctx)
			disp.backlight = math.clamp(disp.backlight - 0.1, 0.0, 1.0);
			led_intensity(disp.ledctrl, disp.ledid, 255 * disp.backlight);
		end
		},
	};
end

local function resolve_xy(disp)
	if (disp.zoom.origo == "mouse") then
		local mx, my = mouse_xy();
		local ad = active_display();
		local lx = math.clamp(mx, 0.001, ad.width) / ad.width;
		local ly = math.clamp(my, 0.001, ad.height) / ad.height;
		return lx, ly;
	else
		return disp.zoom.x, disp.zoom.y;
	end
end

local function get_rt_set()
	local set = {}

-- Though it takes some more thought, there might be more value to adding a
-- full tiler reference. This decoupling should really have been there from
-- the start.
	for d in all_displays_iter() do
		if valid_vid(d.rt) then
			table.insert(set, d.rt);
		end
	end

	return set;
end

local function gen_zoom_menu(disp)
	return {
		{
			name = "cursor",
			kind = "action",
			label = "Cursor",
			description = "Use the last known cursor position as origo",
			handler = function(ctx, val)
				disp.zoom.origo = "mouse";
				local x, y = resolve_xy(disp);
				disp:view_range(x, y, disp.zoom.level);
			end,
		},
		{
			name = "autopan",
			kind = "action",
			label = "Autopan",
			description = "Have the zoom region follow the mouse cursor",
	-- this came with a late change to mouse.lua in upstream arcan, so not
	-- always applicable, keep it here for the time being
			experimental = true,
			eval = function()
--				return mouse_cursorhook ~= nil;
			end,
			handler = function(ctx, val)
				mouse_cursorhook(function()
					autopan(disp)
				end)
			end
		},
		{
			name = "factor",
			kind = "value",
			label = "Factor",
			validator = gen_valid_float(0, 100),
			description = "Set the magnification level",
			initial = disp.zoom.level,
			handler = function(ctx, val)
				local x, y = resolve_xy(disp);
				disp:view_range(x, y, tonumber(val));
			end
		},
-- the cursor needs to be accounted for
		{
			name = "step",
			kind = "value",
			label = "Step",
			validator = gen_valid_float(-10, 10),
			description = "Step magnification relative to the current factor",
			initial = disp.zoom.level,
			handler = function(ctx, val)
				local x, y = resolve_xy(disp);
					disp:view_range(x, y, tonumber(val) + disp.zoom.level);
			end
		}
	};
end

local function gen_disp_menu(disp)
	return {
		{
		name = "focus",
		eval = function() return disp.id ~= nil; end,
		label = "Input Focus",
		kind = "action",
		description = "Move input focus to this display",
		handler = function()
			for v in all_displays_iter() do
				if (v.id == disp.id) then
					display_cycle_active(v.ind);
					return;
				end
			end
		end
		},
		{
		name = "state",
		eval = function() return disp.id ~= nil; end,
		label = "Power State",
		kind = "value",
		set = {"On", "Off", "Suspend", "Standby"},
		description = "Set the Display Power Management State (DPMS)",
		handler = function(ctx, val)
			local set = {
				["On"] = DISPLAY_ON,
				["Off"] = DISPLAY_OFF,
				["Suspend"] = DISPLAY_SUSPEND,
				["Standby"] = DISPLAY_STANDBY
			};
			video_display_state(disp.id, set[val]);
		end
		},
		{
		label = "Zoom",
		name = "zoom",
		kind = "action",
		description = "Large portions of the screen",
		submenu = true,
		handler =
		function()
			return gen_zoom_menu(disp);
		end
		},
		{
		name = "density",
		label = "Density",
		kind = "value",
		hint = "(px/cm)",
		description = "Override detected display density",
		validator = gen_valid_float(10, 600.0),
		initial = function() return tostring(disp.ppcm); end,
		handler = function(ctx, val)
			display_override_density(disp.name, tonumber(val));
		end
		},
		{
		name = "shader",
		label = "Shader",
		kind = "value",
		description = "Change display postprocessing ruleset",
		eval = function() return not display_simple(); end,
		set = function() return shader_list({"display"}); end,
		hint = function() return "(" .. display_shader(disp.name) .. ")"; end,
		handler = function(ctx, val)
			local key = shader_getkey(val, {"display"});
			if (key ~= nil) then
				display_shader(disp.name, key);
			end
		end
		},
		{
		name = "shset",
		label = "Shader Settings",
		kind = "action",
		submenu = true,
		description = "Tune the current display postprocessing ruleset",
		eval = function() return not display_simple() and #shader_uform_menu(
			display_shader(disp.name),"display", disp.name) > 0; end,
		handler = function()
			return shader_uform_menu(display_shader(disp.name),
				"display", disp.name,
-- callback on update
			function(uniform, val)
				display_shader_uniform(disp.name, uniform, val);
			end);
		end
		},
		{
		name = "resolution",
		label = "Resolution",
		kind = "action",
		definition = "Try to reconfigure the display output mode",
		submenu = true,
		eval = function()
	--
	-- removed from causing a storm of rescans on every eval
	-- return #query_dispmenu(disp.id, disp.name) > 0;
			return disp.id ~= nil;
		end,
		handler = function()
			return query_dispmenu(disp.id, disp.name);
		end
		},
		{
		name = "orient",
		label = "Orientation",
		kind = "action",
		description = "Set the display output orientation",
		eval = function() return not display_simple() and disp.id ~= nil; end,
		submenu = true,
		handler = function() return orientation_menu(disp.name); end
		},
		{
		name = "backlight",
		label = "Backlight",
		kind = "action",
		description = "Set or step display backlight controls",
		submenu = true,
		handler = function()
			return backlight_menu(disp);
		end,
		eval = function() return disp.ledctrl ~= nil; end,
		},
		{
		name = "background",
		label = "Background",
		kind = "action",
		description = "Set a default background for all new workspaces on the display",
		handler = function()
			dispatch_symbol_bind(
				function(path)
					local ln, kind = resource(path);
					if (kind ~= "file") then
						active_display():set_background();
						active_display(false, true).background = nil;
					else
						active_display(false, true).background = path;
						active_display():set_background(path);
					end
			end, "/browse/shared");
		end,
		},
		{
		name = "primary_hint",
		label = "Force-Sync",
		kind = "value",
		description = "Set this display as a synch-master",
		set = {LBL_YES, LBL_NO, LBL_FLIP},
		eval = function() return not display_simple(); end,
		initial = function()
			return disp.primary and LBL_YES or LBL_NO;
		end,
		handler = function(ctx, val)
			local opt = disp.primary;
			if (val == LBL_FLIP) then
				opt = not opt;
			else
				opt = val == LBL_YES;
			end
			disp.primary = opt;
			map_video_display(disp.map_rt, disp.id, display_maphint(disp));
		end
		},
		{
		name = "scheme",
		label = "Scheme",
		kind = "action",
		submenu = true,
		description = "Set the UI scheme profile for this display",
		eval = function()	return #(ui_scheme_menu("display", disp)) > 0; end,
		handler = function() return ui_scheme_menu("display", disp); end
		},
		{
		name = "to_window",
		label = "Window",
		kind = "action",
		description = "Create a window with display contents as canvas",
		eval = function()
			return not display_simple();
		end,
		handler = function()
			local nsrf = null_surface(disp.tiler.width, disp.tiler.height);
			if not valid_vid(nsrf) then
				return;
			end
			image_sharestorage(disp.rt, nsrf);
			show_image(nsrf);
			local wnd = active_display():add_window(nsrf, {scalemode = "stretch"});
			if not wnd then
				delete_image(nsrf);
				return;
			end
			wnd:set_title(disp.name);
		end
		},
		{
		name = "remove_add",
		label = "Remove/Add",
		description = "Remove the display then immediately add it back in",
		kind = "action",
		handler = function()
			display_remove_add(disp.id);
		end
		},
		{
		name = "format",
		label = "Format",
		description = "Change the underlying mapping format",
		eval = function()
			return not display_simple();
		end,
		kind = "value",
		set = {"565", "888", "deep", "fp16"},
		handler =
		function(ctx, val)
			local fmt

-- 1. alloc new surface
			if val == "565" then
				fmt = ALLOC_QUALITY_LOW
			elseif val == "888" then
				fmt = ALLOC_QUALITY_NORMAL
			elseif val == "deep" then
				fmt = ALLOC_QUALITY_HIGH
			elseif val == "fp16" then
				fmt = ALLOC_QUALITY_FLOAT16
			end

			display_set_format(disp.name, fmt)
		end
		},
		{
		name = "remap",
		label = "Remap",
		description = "Map the display to the rendertarget of another",
		eval = function()
			return #get_rt_set() > 0;
		end,
		kind = "value",
		set = get_rt_set,
		handler = function(ctx, val)
			local rt = tonumber(val)
			if not valid_vid(rt) then
				return
			end
			disp.map_rt = rt;
			map_video_display(disp.map_rt, disp.id, display_maphint(disp));
		end
		}
	};
end

local function query_displays()
	local res = {};
	local v = active_display(false, true);
	table.insert(res, {
		name = "current",
		label = "Current",
		kind = "action",
		submenu = true,
		description = "Access settings related to the display with input focus",
		handler = function() return gen_disp_menu(v); end
	});
	table.insert(res, {
		name = "all_off",
		label = "All Off",
		kind = "action",
		invisible = true,
		description = "Set the DPMS state for all displays to OFF",
		handler = function()
			display_all_mode(DISPLAY_OFF);
		end
	});
	table.insert(res, {
		name = "all_suspend",
		label = "All Suspend",
		kind = "action",
		invisible = true,
		description = "Set the DPMS state for all displays to SUSPEND",
		handler = function()
			display_all_mode(DISPLAY_SUSPEND);
		end
	});
	table.insert(res, {
		name = "all_standby",
		label = "All Standby",
		kind = "action",
		description = "Set the DPMS state for all displays to STANDBY",
		invisible = true,
		handler = function()
			display_all_mode(DISPLAY_STANDBY);
		end
	});
	table.insert(res, {
		name = "all_on",
		label = "All On",
		kind = "action",
		invisible = true,
		description = "Set the DPMS state for all displays to ON",
		handler = function()
			display_all_mode(DISPLAY_ON);
		end
	});
	for d in all_displays_iter() do
		if (string.len(d.name) > 0) then
			table.insert(res, {
				name = "disp_" .. string.hexenc(d.name),
				label = d.name,
				kind = "action",
				submenu = true,
				handler = function() return gen_disp_menu(d); end
			});
		end
	end
	return res;
end

local function gen_gpu_reset()
	local res = {};
	local n_cards = 1;
	table.insert(res, {
		name = "all",
		label = "Reset All",
		dangerous = true,
		description = "Force all GPUs to be disconnected and rebuilt",
		kind = "action",
		handler = function()
			subsystem_reset("video");
		end
	});

-- with multiple GPUs we need card-IDs tracked
	for i=0,n_cards-1 do
		table.insert(res, {
			name = "swap_" .. tostring(i),
			label = "Reset Card " .. tostring(i),
			description = "Force a GPU swap on card slot " .. tostring(i),
			dangerous = true,
			kind = "action",
			handler = function()
				subsystem_reset("video", i, 1);
			end
		});
	end

	return res;
end

local last_dvid; -- track VID for OCR
local last_msg; -- append message for multipart

local region_menu = {
	{
		name = "snapshot",
		label = "Snapshot",
		kind = "action",
		external_block = true,
		description = "Take a snapshot of a screen region",
		handler = function()
			local r, g, b = suppl_hexstr_to_rgb(HC_PALETTE[1]);
			suppl_region_select(r, g, b, function(x1, y1, x2, y2)
				local dvid = suppl_region_setup(x1, y1, x2, y2, false, true);
				if (not valid_vid(dvid)) then return; end
				show_image(dvid);
				local wnd = active_display():add_window(dvid, {scalemode = "stretch"});
				wnd:set_title("Snapshot" .. tostring(CLOCK));
			end);
		end,
	},
	{
		name = "monitor",
		label = "Monitor",
		kind = "action",
		description = "Create a window that monitors the contents of a screen region",
		external_block = true,
		handler = function()
			local r, g, b = suppl_hexstr_to_rgb(HC_PALETTE[3]);
			suppl_region_select(r, g, b,
			function(x1, y1, x2, y2)
				local dvid = suppl_region_setup(x1, y1, x2, y2, false, false);
				if (not valid_vid(dvid)) then
					return;
				end

-- this requires something more refined in order to do proper sharing, and that
-- is a separate state-tracker for mouse etc. that works off input_table inside
-- wnd.
				local wnd = active_display():add_window(dvid, {scalemode = "stretch"});
				if (wnd) then
					wnd:set_title("Monitor");
				end
			end)
		end,
	},
-- OCR is slightly ineffective now as the frameserver is spawned per invocation
-- and then killed, it doesn't lie dormant and just receive a push due to the
-- resize operation. It could be remanaged by fine-controlling the rendertarget
-- and using stepframe however. Another interesting addition to this feature
-- would be the inclusion of text to speech on an audio source.
	{
		name = "ocr",
		label = "OCR",
		kind = "action",
		external_block = true,
		description = "OCR the contents of a screen region unto the global clipboard",
		handler = function()
			local r, g, b = suppl_hexstr_to_rgb(HC_PALETTE[4]);
			suppl_region_select(r, g, b, function(x1, y1, x2, y2)

-- assume that a new OCR call invalidates the last / pending one
				if (valid_vid(last_dvid)) then
					delete_image(last_dvid);
					last_dvid = nil;
				end

				local dvid, grp = suppl_region_setup(x1, y1, x2, y2, true, false);
				if (not valid_vid(dvid)) then
					return;
				end
				last_dvid = dvid;
				hide_image(dvid);

				define_recordtarget(dvid, "stream", "protocol=ocr", grp, {},
					RENDERTARGET_DETACH, RENDERTARGET_NOSCALE, 0,
				function(source, stat)
					if (stat.kind == "message") then
						last_msg = last_msg and (last_msg .. stat.message) or stat.message;
						if (not stat.multipart) then
							CLIPBOARD:add("OCR", last_msg, false);
							active_display():message("OCR: " .. last_msg);
							last_msg = nil;
							delete_image(source);
						end
					elseif (stat.kind == "terminated") then
						delete_image(source);
					end
				end);

-- make sure the copy in the new rendertarget is updated, then sync down
				rendertarget_forceupdate(dvid);
				stepframe_target(dvid);
			end);
		end
	}
};

local res = {
	{
		name = "rescan",
		label = "Rescan",
		kind = "action",
		description = "Rescan all GPU display output ports for new displays",
		handler = function() video_displaymodes(); end
	},
	{
		name = "displays",
		label = "Displays",
		kind = "action",
		submenu = true,
		description = "List all currently known displays",
		handler = function() return query_displays(); end
	},
	{
		name = "synch",
		label = "Synchronization",
		kind = "action",
		submenu = true,
		description = "Change the global display output synchronization strategy",
		handler = function() return query_synch(); end
	},
	{
		name = "cycle",
		label = "Cycle Active",
		kind = "action",
		description = "Switch input focus to the next display in line",
		eval = function() return not display_simple(); end,
		handler = function()
			display_cycle_active();
		end
	},
	{
		name = "region",
		label = "Region",
		eval = function() return not mouse_blocked(); end,
		kind = "action",
		submenu = true,
		description = "Recording / Sharing actions for custom screen regions",
		handler = region_menu
	},
	{
		name = "fullscreen",
		label = "Dedicated Fullscreen",
		kind = "value",
		description = "Set the default mode for window dedicated fullscreen",
		initial = function() return gconfig_get("disp_fs_mode"); end,
		set = {"Stretch", "Stretch-Switch", "Center", "Center-Switch"},
		handler = function(ctx, val)
			gconfig_set("disp_fs_mode", string.lower(val));
		end
	},
	{
		name = "vppcm",
		label = "Density",
		description = "manual override of the safe density default",
		kind = "value",
		initial = function() return VPPCM; end,
		validator = gen_valid_num(30, 100),
		handler = function(ctx, val)
			VPPCM = tonumber(val);
		end
	},
	{
		name = "reset",
		label = "Reset",
		description = "(Dangerous) Force a video subsystem reset",
		submenu = true,
		kind = "action",
		handler = gen_gpu_reset,
	},
	{
		name = "color",
		label = "Color",
		description = "Color to use when no wallpaper is defined",
	},
};
suppl_append_color_menu(
	gconfig_get("display_color"), res[#res],
	function(fmt, r, g, b)
		for tiler in all_tilers_iter() do
			if (valid_vid(tiler.rtgt_id)) then
				image_color(tiler.rtgt_id, r, g, b);
			end
		end
		gconfig_set("display_color", {r, g, b});
	end
);

return res;

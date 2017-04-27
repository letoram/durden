local function orientation_menu(name)
	return {
		{
			name = "toggle_hv",
			eval = function() return not display_simple(); end,
			label = "Toggle H/V",
			kind = "action",
			handler = function()
				display_reorient(name);
			end
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
				handler = function(ctx)
					video_synchronization(v);
				end
			};
		end
		return res;
	end
end
register_global("query_synch", display_synch);

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
				table.insert(mtbl, {
					name = "mode_" .. tostring(k),
					label = string.format("%d*%d, %d bits @%d Hz",
						v.width, v.height, v.depth, v.refresh),
					kind = "action",
					handler = function() display_ressw(name, v); end
				});
			end
		end
		return mtbl;
	end
end

local function gen_disp_menu(disp)
	return {
		{
		name = "state",
		eval = function() return disp.id ~= nil; end,
		label = "Toggle On/Off",
		kind = "action",
		handler = function()
			local mode = video_display_state(disp.id);
			video_display_state(disp.id,
				mode ~= DISPLAY_ON and DISPLAY_ON or DISPLAY_OFF);
		end
		},
		{
		name = "density",
		label = "Density",
		kind = "value",
		hint = "(px/cm)",
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
		submenu = true,
		eval = function() return disp.id ~= nil and
			#query_dispmenu(disp.id, disp.name) > 0;  end,
		handler = function() return query_dispmenu(disp.id, disp.name); end
		},
		{
		name = "backlight",
		label = "Backlight",
		kind = "value",
		hint = "(0..1)",
		initial = disp.backlight,
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
		name = "orient",
		label = "Orientation",
		kind = "action",
		eval = function() return not display_simple() and disp.id ~= nil; end,
		submenu = true,
		handler = function() return orientation_menu(disp.name); end
		},
		{
		name = "background",
		label = "Set Background",
		kind = "action",
		handler = function()
			local loadfn = function(fn)
				disp.tiler:set_background(fn, true);
				disp.background = fn;
			end
			local imgfiles = {png = loadfn, jpg = loadfn, bmp = loadfn};
			browse_file({}, imgfiles, SHARED_RESOURCE, nil);
		end
		},
		{
		name = "resetbg",
		label = "Reset Background",
		kind = "action",
		handler = function()
			disp.background = "";
		end,
		eval = function() return
			disp.background and string.len(disp.background) > 0;
		end
		},
		{
		name = "primary_hint",
		label = "Force-Sync",
		kind = "value",
		set = {LBL_YES, LBL_NO},
		eval = function() return not display_simple(); end,
		initial = function()
			return disp.primary and LBL_YES or LBL_NO;
		end,
		handler = function(ctx, val)
			disp.primary = val == LBL_YES;
			map_video_display(disp.rt, disp.id, display_maphint(disp));
		end
		},
		{
		name = "record",
		label = "Record",
		kind = "value",
		hint = suppl_recarg_hint,
		eval = function() return disp.share_slot == nil
			 and suppl_recarg_eval();
		end,
		hintsel = suppl_recarg_sel,
		validator = suppl_recarg_valid,
		handler = function(ctx, val)
			local args, ign, path = suppl_build_recargs(val, nil, nil, val);
			display_share(disp, args, path);
		end
		},
		{
		name = "stop_record",
		label = "Stop Recording",
		kind = "action",
		eval = function() return disp.share_slot ~= nil; end,
		handler = function()
			display_share(disp);
		end
		},
		{
		name = "raw",
		label = "Screenshot(raw)",
		kind = "value",
		hint = "(stored in output/)",
		eval = function() return valid_vid(disp.rt); end,
		validator = function(val)
			return string.len(val) > 0 and not resource("output/" .. val) and
				not string.match(val, "%.%.");
		end,
		handler = function(ctx, val)
			save_screenshot("output/" .. val, FORMAT_RAW32, disp.rt);
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
		handler = function() return gen_disp_menu(v); end
	});
	table.insert(res, {
		name = "all_off",
		label = "All Off",
		kind = "action",
		invisible = true,
		handler = function()
			display_all_mode(DISPLAY_OFF);
		end
	});
	table.insert(res, {
		name = "all_suspend",
		label = "All Suspend",
		kind = "action",
		invisible = true,
		handler = function()
			display_all_mode(DISPLAY_SUSPEND);
		end
	});
	table.insert(res, {
		name = "all_standby",
		label = "All Standby",
		kind = "action",
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
		handler = function()
			display_all_mode(DISPLAY_ON);
		end
	});
	for d in all_displays_iter() do
		if (string.len(d.name) > 0) then
			table.insert(res, {
				name = "disp_" .. hexenc(d.name),
				label = d.name,
				kind = "action",
				submenu = true,
				handler = function() return gen_disp_menu(d); end
			});
		end
	end
	return res;
end

local record_handler = system_load("menus/global/record.lua")();
local last_dvid; -- track VID for OCR
local last_msg; -- append message for multipart

local region_menu = {
	{
		name = "snapshot",
		label = "Snapshot",
		kind = "action",
		external_block = true,
		handler = function()
			suppl_region_select(255, 0, 0, function(x1, y1, x2, y2)
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
		external_block = true,
		handler = function()
			suppl_region_select(0, 255, 0, function(x1, y1, x2, y2)
				local dvid = suppl_region_setup(x1, y1, x2, y2, false, false);
				if (not valid_vid(dvid)) then return; end
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
		handler = function()
			suppl_region_select(255, 0, 255, function(x1, y1, x2, y2)

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
	},

-- also need to become more complicated for an 'action connection' rather
-- than 'passive streaming over VNC', with the big change being how lbar,
-- active_display and tiler interact so that the shared subset can become
-- a restricted tiler of its own
	{
		name = "share",
		label = "Share",
		kind = "action",
		eval = function() return string.match(
			FRAMESERVER_MODES, "encode") ~= nil;
		end,
		e3xternal_block = true,
		handler = system_load("menus/global/remoting.lua")();
	},
	{
		name = "record",
		label = "Record",
		kind = "value",
		hint = suppl_recarg_hint,
		hintsel = suppl_recarg_set,
		validator = suppl_recarg_valid,
		eval = suppl_recarg_eval,
		external_block = true,
		handler = function(ctx, val)
			record_handler(val);
		end
	}
};

return {
	{
		name = "rescan",
		label = "Rescan",
		kind = "action",
		handler = function() video_displaymodes(); end
	},
	{
		name = "list",
		label = "Displays",
		kind = "action",
		submenu = true,
		handler = function() return query_displays(); end
	},
	{
		name = "synch",
		label = "Synchronization",
		kind = "action",
		submenu = true,
		handler = function() return query_synch(); end
	},
	{
		name = "cycle",
		label = "Cycle Active",
		kind = "action",
		eval = function() return not display_simple(); end,
		handler = grab_global_function("display_cycle")
	},
	{
		name = "region",
		label = "Region",
		eval = function() return not mouse_blocked(); end,
		kind = "action",
		submenu = true,
		handler = region_menu
	},
	{
		name = "fullscreen",
		label = "Dedicated Fullscreen",
		kind = "value",
		initial = function() return gconfig_get("disp_fs_mode"); end,
		set = {"Stretch", "Stretch-Switch", "Center", "Center-Switch"},
		handler = function(ctx, val)
			gconfig_set("disp_fs_mode", string.lower(val));
		end
	}
};

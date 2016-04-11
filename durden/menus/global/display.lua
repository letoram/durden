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

local function display_shader_menu(disp)
	return {
	};
end

local function gen_disp_menu(disp)
	return {
		{
		name = "state",
		eval = function() return disp.id ~= nil and disp.primary ~= true; end,
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
		label = "Pixel Density",
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
		kind = "action",
		submenu = true,
		eval = function() return not display_simple(); end,
		handler = function(ctx)
			return display_shader_menu(disp.name);
		end
		},
		{
		name = "resolution",
		label = "Resolution",
		kind = "action",
		submenu = true,
		eval = function() return disp.id ~= nil; end,
		handler = function() return query_dispmenu(disp.id, disp.name); end
		},
		{
		name = "orient",
		label = "Orientation",
		kind = "action",
		eval = function() return not display_simple() and disp.id ~= nil; end,
		submenu = true,
		handler = function() return orientation_menu(disp.name); end
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
	for k,v in pairs(all_displays()) do
		if (string.len(v.name) > 0) then
			table.insert(res, {
				name = "disp_" .. tostring(k),
				label = v.name,
				kind = "action",
				submenu = true,
				handler = function() return gen_disp_menu(v); end
			});
		end
	end
	return res;
end

local record_handler = system_load("menus/global/record.lua")();
local region_menu = {
	{
		name = "snapshot",
		label = "Snapshot",
		kind = "action",
		handler = function()
			suppl_region_select(255, 0, 0, function(x1, y1, x2, y2)
				local dvid = suppl_region_setup(x1, y1, x2, y2, false, true);
				show_image(dvid);
				local wnd = active_display():add_window(dvid, {scalemode = "stretch"});
				wnd:set_title("Snapshot" .. tostring(CLOCK));
			end)
		end,
	},
	{
		name = "monitor",
		label = "Monitor",
		kind = "action",
		handler = function()
			suppl_region_select(0, 255, 0, function(x1, y1, x2, y2)
				local dvid = suppl_region_setup(x1, y1, x2, y2, false, false);
				show_image(dvid);
				local wnd = active_display():add_window(dvid, {scalemode = "stretch"});
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
		eval = function() return false; end,
		handler = function()
			suppl_region_select(255, 0, 255, function(x1, y1, x2, y2)
				local dvid, grp = suppl_region_setup(x1, y1, x2, y2, true, false);
				if (not valid_vid(dvid)) then
					return;
				end
				define_recordtarget(dvid, grp, "protocol=ocr", grp, {},
					RENDERTARGET_DETACH, RENDERTARGET_NOSCALE, 0,
				function(source, stat)
					if (stat.kind == "message") then
-- aggregate and push into global clipboard
					elseif (stat.kind == "terminated") then
						delete_image(source);
					else
					end
				end);
				rendertarget_forceupdate(dvid);
			end);
		end
	},
-- also need to become more complicated for an 'action connection' rather
-- than 'passive streaming over VNC'
	{
		name = "share",
		label = "Share",
		kind = "action",
		eval = function() return string.match(
			FRAMESERVER_MODES, "encode") ~= nil;
		end,
		handler = system_load("menus/global/remoting.lua")();
	},
	{
		name = "record",
		label = "Record",
		kind = "value",
		hint = "(full path)",
		validator = function(val)
			return string.len(val) > 0 and not resource(val);
		end,
		eval = function() return string.match(
			FRAMESERVER_MODES, "encode") ~= nil;
		end,
		handler =
		function(ctx, val)
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
		kind = "action",
		submenu = true,
		handler = region_menu
	}
};

local function orientation_menu(name)
	return {
		{
			name = "disp_orent_toggle_hv",
			eval = function() return gconfig_get("display_simple") == false; end,
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
				name = "set_synch_" .. tostring(k),
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
					name = "set_res_" .. tostring(k),
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
		name = "disp_menu_" .. tostring(disp.name) .. "state",
		eval = function() return disp.primary ~= true; end,
		label = "Toggle On/Off",
		kind = "action",
		handler = function() warning("toggle display"); end
		},
		{
		name = "disp_menu_density_override",
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
		name = "disp_menu_" .. tostring(disp.name) .. "state",
		label = "Resolution",
		kind = "action",
		submenu = true,
		handler = function() return query_dispmenu(disp.id, disp.name); end
		},
		{
		name = "display_mapping",
		label = "Orientation",
		kind = "action",
		eval = function() return gconfig_get("display_simple") == false; end,
		submenu = true,
		handler = function() return orientation_menu(disp.name); end
		}
	};
end

local function query_displays()
	local res = {};
	for k,v in pairs(all_displays()) do
		if (string.len(v.name) > 0) then
			table.insert(res, {
				name = "disp_menu_" .. tostring(k),
				label = v.name,
				kind = "action",
				submenu = true,
				handler = function() return gen_disp_menu(v); end
			});
		end
	end
	return res;
end

local do_regsel = function(handler)
	local col = color_surface(1, 1, 0, 255, 0);
	blend_image(col, 0.2);
	mouse_select_begin(col);
	durden_input = durden_regionsel_input;
	DURDEN_REGIONSEL_TRIGGER = handler;
end

-- use active display rendertarget to create an intermediary region
local function build_rt_reg(x1, y1, w, h, srate)
	if (w <= 0 or h <= 0) then
		return;
	end

	local dst = alloc_surface(w, h);
	if (not valid_vid(dst)) then
		warning("build_rt: failed to create intermediate");
		return;
	end
	local cont = null_surface(w, h);
	if (not valid_vid(cont)) then
		delete_image(dst);
		return;
	end

	local drt = active_display(true);
	rendertarget_forceupdate(drt);
	image_sharestorage(drt, cont);

-- convert to surface coordinates
	local props = image_storage_properties(cont);
	local s1 = x1 / props.width;
	local t1 = y1 / props.height;
	local s2 = (x1+w) / props.width;
	local t2 = (y1+h) / props.height;

	local txcos = {s1, t1, s2, t1, s2, t2, s1, t2};
	image_set_txcos(cont, txcos);
	show_image({cont, dst});

	define_rendertarget(dst,{cont},
		RENDERTARGET_DETACH,RENDERTARGET_NOSCALE, srate);
	return dst;
end

local function regimg_setup(x1, y1, x2, y2, static)
	local w = x2 - x1;
	local h = y2 - y1;
	local img = build_rt_reg(x1, y1, w, h, static and 0 or -1);
	if (valid_vid(img)) then
		rendertarget_forceupdate(img);

		if (static) then
			local dsrf = null_surface(w, h);
			image_sharestorage(img, dsrf);
			delete_image(img);
			img = dsrf;
		end

		show_image(img);
		active_display():add_window(img, {scalemode = "stretch"});
	end
end

local region_menu = {
	{
		name = "display_region_imgwnd",
		label = "Snapshot",
		kind = "action",
		handler = function()
			do_regsel(function(x1, y1, x2, y2)
				regimg_setup(x1, y1, x2, y2, true);
			end)
		end,
	},
	{
		name = "display_region_monitor",
		label = "Monitor",
		kind = "action",
		handler = function()
			do_regsel(function(x1, y1, x2, y2)
				regimg_setup(x1, y1, x2, y2, false);
			end)
		end,
	},
	{
		name = "display_region_ocr",
		label = "OCR",
		kind = "action",
-- eval = should run a probe mode for encode to figure out if we have
-- OCR / share /etc. support
		handler = function()
			do_regsel(function(x1, y1, x2, y2)
				print("display_region_ocr");
			end);
		end
	},
	{
		name = "display_region_record",
		label = "Record",
-- eval = check for encode, we need a way to query arguments better
		kind = "action",
		handler = function()
			do_regsel(function(x1, y1, x2, y2)
				print("display_region_record");
			end);
		end,
	},
};

return {
	{
		name = "display_rescan",
		label = "Rescan",
		kind = "action",
		handler = function() video_displaymodes(); end
	},
	{
		name = "display_list",
		label = "Displays",
		kind = "action",
		submenu = true,
		handler = function() return query_displays(); end
	},
	{
		name = "synchronization_strategies",
		label = "Synchronization",
		kind = "action",
		hint = "Synchronization:",
		submenu = true,
		handler = function() return query_synch(); end
	},
	{
		name = "display_cycle",
		label = "Cycle Active",
		kind = "action",
		eval = function() return gconfig_get("display_simple") == false; end,
		handler = grab_global_function("display_cycle")
	},
	{
		name = "display_region",
		label = "Region Action",
		kind = "action",
		submenu = true,
		handler = region_menu
	}
};

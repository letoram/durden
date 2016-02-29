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
		eval = function() return disp.id ~= nil and disp.primary ~= true; end,
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
		eval = function() return disp.id ~= nil; end,
		handler = function() return query_dispmenu(disp.id, disp.name); end
		},
		{
		name = "display_mapping",
		label = "Orientation",
		kind = "action",
		eval = function() return gconfig_get("display_simple") == false and
			disp.id ~= nil; end,
		submenu = true,
		handler = function() return orientation_menu(disp.name); end
		}
	};
end

local function query_displays()
	local res = {};
	local v = active_display(false, true);
	table.insert(res, {
		name = "disp_menu_current",
		label = "Current",
		kind = "action",
		submenu = true,
		handler = function() return gen_disp_menu(v); end
	});
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

local do_regsel = function(r, g, b, handler)
	local col = color_surface(1, 1, r, g, b);
	blend_image(col, 0.2);
	iostatem_save();
	mouse_select_begin(col);
	durden_input = durden_regionsel_input;
	DURDEN_REGIONSEL_TRIGGER = handler;
end

local function build_rt_reg(drt, x1, y1, w, h, srate)
	if (w <= 0 or h <= 0) then
		return;
	end

-- grab in worldspace, translate
	local props = image_surface_resolve_properties(drt);
	x1 = x1 - props.x;
	y1 = y1 - props.y;

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

	image_sharestorage(drt, cont);

-- convert to surface coordinates
	local s1 = x1 / props.width;
	local t1 = y1 / props.height;
	local s2 = (x1+w) / props.width;
	local t2 = (y1+h) / props.height;

	local txcos = {s1, t1, s2, t1, s2, t2, s1, t2};
	image_set_txcos(cont, txcos);
	show_image({cont, dst});

	local shid = image_shader(drt);
	if (shid) then
		image_shader(cont, shid);
	end

	define_rendertarget(dst,{cont},
		RENDERTARGET_DETACH,RENDERTARGET_NOSCALE, srate);
	return dst;
end

local function regimg_setup(x1, y1, x2, y2, static, title)
	local w = x2 - x1;
	local h = y2 - y1;

-- check sample points if we match a single vid or we need to
-- use the aggregate surface and restrict to the behaviors of rt
	local drt = active_display(true);
	local i1 = pick_items(x1, y1, 1, true, drt);
	local i2 = pick_items(x2, y1, 1, true, drt);
	local i3 = pick_items(x1, y2, 1, true, drt);
	local i4 = pick_items(x2, y2, 1, true, drt);
	local img = drt;
	if (#i1 == 0 or #i2 == 0 or #i3 == 0 or #i4 == 0 or
		i1[1] ~= i2[1] or i1[1] ~= i3[1] or i1[1] ~= i4[1]) then
		rendertarget_forceupdate(drt);
	else
		img = i1[1];
	end
	img = build_rt_reg(img, x1, y1, w, h, static and 0 or -1);

	if (valid_vid(img)) then
		rendertarget_forceupdate(img);

		if (static) then
			local dsrf = null_surface(w, h);
			image_sharestorage(img, dsrf);
			delete_image(img);
			img = dsrf;
		end

		show_image(img);
		local wnd = active_display():add_window(img, {scalemode = "stretch"});
		wnd:set_title(title);
	end
end

local region_menu = {
	{
		name = "display_region_imgwnd",
		label = "Snapshot",
		kind = "action",
		handler = function()
			do_regsel(255, 0, 0, function(x1, y1, x2, y2)
				regimg_setup(x1, y1, x2, y2, true, "Snapshot");
			end)
		end,
	},
	{
		name = "display_region_monitor",
		label = "Monitor",
		kind = "action",
		handler = function()
			do_regsel(0, 255, 0, function(x1, y1, x2, y2)
				regimg_setup(x1, y1, x2, y2, false, "Monitor");
			end)
		end,
	},
	{
		name = "display_region_ocr",
		label = "OCR",
		kind = "action",
		eval = function() return false; end,
		handler = function()
			do_regsel(0, 255, 255, function(x1, y1, x2, y2)
				print("display_region_ocr");
			end);
		end
	},
	{
		name = "display_region_remote",
		label = "Remote",
		kind = "action",
		eval = function() return false; end,
		handler = function()
			do_regsel(255, 255, 0, function(x1, y1, x2, y2)
				print("display_region_remote");
			end);
		end
	},
	{
		name = "display_region_record",
		label = "Record",
		eval = function() return false; end,
		kind = "action",
		handler = function()
			do_regsel(255, 0, 255, function(x1, y1, x2, y2)
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
		label = "Region",
		kind = "action",
		submenu = true,
		handler = region_menu
	}
};

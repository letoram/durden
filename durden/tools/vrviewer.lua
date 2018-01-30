--
-- Trivial VR / panoramic viewer
--

-- local vrsupp = system_load("vrsupport.lua");
-- constructor function, return table with:
--
--  set_stereo(pipeline)
--  set_mono()
--  set_display(dispid)
--  override_distortion(params)
--
-- copy stuff from display patch that dealt with tagging displays
--

local hmd_arg = "";

local vert = [[
uniform mat4 modelview;
uniform mat4 projection;

attribute vec2 texcoord;
attribute vec4 vertex;

uniform vec2 ofs_leye;
uniform vec2 ofs_reye;
uniform vec2 scale_leye;
uniform vec2 scale_reye;

uniform int rtgt_id;

varying vec2 texco;

void main()
{
	vec2 tc = texcoord;
	vec4 vert = vertex;

	if (rtgt_id == 0){
		tc += ofs_leye;
		tc *= scale_leye;
	}
	else {
		tc += ofs_reye;
		tc *= scale_reye;
	}
	texco = tc;
	gl_Position = projection * modelview * vertex;
}
]];

local geomshader = build_shader(vert, nil, "vr_geom");

local function set_model_uniforms(
	leye_x, leye_y, leye_ss, leye_st, reye_x, reye_y, reye_ss, reye_st)
	shader_uniform(geomshader, "ofs_leye", "ff", leye_x, leye_y);
	shader_uniform(geomshader, "scale_leye", "ff", leye_ss, leye_st);
	shader_uniform(geomshader, "ofs_reye", "ff", reye_x, reye_y);
	shader_uniform(geomshader, "scale_reye", "ff", reye_ss, reye_st);
end
set_model_uniforms(0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0);

local function get_valid_windows(cwin, model)
	local lst = {};
	for wnd in all_windows() do
		if (wnd ~= cwin) then
		table.insert(lst, {
			kind = "action",
			name = "map_" .. wnd.name,
			label = wnd.title_text and wnd.title_text or wnd.name,
			eval = function() return valid_vid(cwin.model); end,
			handler = function()
				image_sharestorage(wnd.canvas, cwin.model);
			end
		});
		end
	end
	return lst;
end

local function set_model(wnd, kind)
	local rmmodel = wnd.model;

	if (kind == "cylinder") then
		wnd.model = build_cylinder(1, 0.5, 359, 1);
	elseif (kind == "sphere") then
		wnd.model = build_sphere(0.1, 360, 360, 1, true);
	elseif (kind == "hemisphere") then
		wnd.model = build_sphere(1, 360, 180, 1, true);
--	elseif (kind == "flat") then need this for sbs-3d material
	else
		return;
	end

	attrtag_model(wnd.model, "infinite", true);
	swizzle_model(wnd.model);
	show_image(wnd.model);
	image_shader(wnd.model, geomshader);
	if (wnd.vr_rt) then
		rendertarget_attach(wnd.vr_rt, wnd.model, RENDERTARGET_DETACH);
	end

	if (valid_vid(rmmodel)) then
		if (valid_vid(wnd.model)) then
			image_sharestorage(rmmodel, wnd.model);
		end
		delete_image(rmmodel);
		wnd.model = nil;
	end
end

-- when the VR bridge is active, we still want to be able to tune the
-- distortion, fov, ...

-- distortion[ffff]
-- abberation[ffff] : vs defaults
-- warp_scale
-- l_fov_deg_tan, r_fov_deg_tan
-- ar_l, ar_r,
-- h_sz, v_sz,
-- distortion model (none, fragment)
-- + toggle preview window (just bind rt vid to another storage)
-- just nil the fields that aren't overridden
-- possibly get from display map

local function vrwnd()
-- flip for rendertarget
	local cam = null_surface(1, 1);
	scale3d_model(cam, 1.0, -1.0, 1.0);

	local unm = fill_surface(32, 32, 255, 255, 255);

-- setup a rendetarget for this model alone, use unm as placeholder
	local tgtsurf = alloc_surface(VRESW, VRESH);
	define_rendertarget(tgtsurf, {cam, unm}, RENDERTARGET_DETACH,
		RENDERTARGET_NOSCALE, -1, RENDERTARGET_FULL);
	camtag_model(cam, 0.01, 100.0, 45.0, 1.33, true, true, 0, tgtsurf);

-- and bind to a new window
	local wnd = active_display():add_window(tgtsurf, {scalemode = "stretch"});
	wnd.vr_rt = tgtsurf;
	wnd.rtgt_id = 0;
	rendertarget_id(tgtsurf, 0);
	set_model(wnd, "sphere");
	image_sharestorage(unm, wnd.model);
	delete_image(unm);

	wnd.bindings = {
	TAB = function() wnd.model_move = not wnd.model_move; end
	};
	wnd.clipboard_block = true;
	wnd:set_title(string.format("VR/Panoramic - unmapped"));
	wnd:add_handler("resize", function(ctx, w, h)
		if (not ctx.in_drag_rz) then
			image_resize_storage(tgtsurf, w, h);
			rendertarget_forceupdate(tgtsurf);
		end
		resize_image(tgtsurf, w, h);
	end);

-- switch mouse handler so canvas drag translates to rotating the camera
	wnd.handlers.mouse.canvas.drag = function(ctx, vid, dx, dy)
		rotate3d_model(cam, 0, dy, dx, 0, ROTATE_RELATIVE);
		return true;
	end

	local lst = {};
	for k,v in pairs(wnd.handlers.mouse.canvas) do
		table.insert(lst, k);
	end
	mouse_droplistener(wnd.handlers.mouse.canvas);
	mouse_addlistener(wnd.handlers.mouse.canvas, lst);

	show_image(tgtsurf);
	wnd.menu_input_disable = true;
	wnd.menu_state_disable = true;
	wnd.actions = {
		{
		name = "map",
		label = "Source",
		submenu = true,
		kind = "action",
		description = "Set the contents of another window as the 3D model display",
		eval = function() return  #get_valid_windows(wnd, res); end,
		handler = function() return get_valid_windows(wnd, res); end
		},
		{
		name = "close_vr",
		description = "Terminate the current VR session and release the display",
		kind = "action",
		label = "Close VR",
		eval = function()
			return active_display().selected.in_vr ~= nil;
		end,
		handler = function()
			drop_vr(active_display().selected);
		end
		},
		{
		name = "vr_settings",
		kind = "value",
		label = "VR Settings",
		description = "Set the arguments that will be passed to the VR device",
		handler = vrsettings,
		action = function(ctx, val)
			hmd_arg = val;
		end,
		},
		{
		name = "switch_model",
		label = "Projection Model",
		kind = "value",
		description = "Determine the source mapping projection model",
		set = {"Sphere", "Hemisphere", "Cylinder"},
		handler = function(ctx, val)
			set_model(wnd, string.lower(val));
		end
		},
		{
		name = "eyeswap",
		label = "Swap Left/Right",
		kind = "action",
		description = "Switch left and right eye position when mapping the source",
		handler = function()
			wnd.rtgt_id = wnd.rtgt_id == 0 and 1 or 0;
			rendertarget_id(wnd.vr_rt, wnd.rtgt_id);
			if (wnd.rtgt_vr_r) then
				rendertarget_id(wnd.vr_rt, wnd.rtgt_id == 0 and 1 or 0);
			end
		end,
		},
		{
		name = "stereo",
		label = "Stereoscopic Model",
		kind = "value",
		description = "Determine how the mapped source should be interpreted",
		set = {"side-by-side", "over-under", "monoscopic"},
		handler = function(ctx, val)
			if (val == "side-by-side") then
				set_model_uniforms(
					0.0, 0.0, 0.5, 1.0,
					0.5, 0.0, 0.5, 1.0
				);
			elseif (val == "over-under") then
				set_model_uniforms(
					0.0, 0.0, 1.0, 0.5,
					0.0, 0.5, 1.0, 0.5
				);
			else
				set_model_uniforms(
					0.0, 0.0, 1.0, 1.0,
					0.0, 0.0, 1.0, 1.0
				);
			end
		end
		},
-- FIXME: last piece of the puzzle, query display for VR tags,
-- (and add a "fake" VR window setup as well)
		{
		name = "setup_vr",
		label = "Setup VR",
		kind = "value",
		set = function()
		end,
		eval = function()
			return false;
		end,
		handler = function(ctx, val)
			setup_vr_display(wnd, val);
		end
		},
	};
	return wnd;
end

global_menu_register("tools",
{
	name = "vr",
	label = "VR Viewer",
	description = "Panoramic/VR Viewer",
	kind = "action",
-- engine version check
	eval = function() return build_cylinder ~= nil; end,
	handler = vrwnd
});

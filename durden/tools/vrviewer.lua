--
-- Trivial VR / panoramic viewer
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
		tc *= scale_leye;
		tc += ofs_leye;
	}
	else {
		tc *= scale_reye;
		tc += ofs_reye;
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
			local ident = wnd.title_text and wnd.title_text or wnd.name;
			table.insert(lst, {
				kind = "action",
				name = "map_" .. wnd.name,
				label = "w:" .. ident,
				eval = function() return valid_vid(cwin.model); end,
				handler = function()
					image_sharestorage(wnd.canvas, cwin.model);
					cwin:set_title(string.format("VR/Panoramic: %s", ident));
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
	elseif (kind == "cube") then
		wnd.model = build_3dbox(1, 1, 1, 1);
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

local function setup_vr_display(wnd, name)
	local disp = display_lease(name);
	if (not disp) then
		return;
	end

-- or make these status messages into some kind of logging console,
-- probably best when we can make internal TUI connections and do
-- it that way
	wnd:set_title("Spawning VR Bridge");

-- ideally, we'd get a display with two outputs so that we could map
-- the rendertargets directly to the outputs, getting rid of one step
	local setup_vrpipe = function(bridge, neck)
		local md = vr_metadata(source);

		local dispw = 1920;
		local disph = 1024;
		local halfw = 1920 * 0.5;

-- assume SBS configuration, L/R, combiner is where we apply distortion
-- and the rendertarget we bind to a preview window as well as map to
-- the display
		local combiner = alloc_surface(dispw, disph);
		local l_eye = alloc_surface(halfw, disph);
		local r_eye = alloc_surface(halfw, disph);

		define_rendertarget(combiner, {l_eye, r_eye});
		define_linktarget(l_eye, wnd.vr_pipe);
		define_linktarget(r_eye, wnd.vr_pipe);

-- build the cameras, link them to a shared movable anchor
		local pos = null_surface(1, 1);
		local cam_l = null_surface(1, 1);
		local cam_r = null_surface(1, 1);
		scale3d_model(cam_l, 1.0, -1.0, 1.0);
		scale3d_model(cam_r, 1.0, -1.0, 1.0);
		link_image(cam_l, pos);
		link_image(cam_r, pos);
		show_image({pos, cam_l, cam_r});

-- the distortion model has three options, no distortion, fragment shader
-- distortion and (better) mesh distortion that can be configured with
-- image_tesselation (not too many subdivisions, maybe 30, 40 something

-- ipd is set by moving l_eye to -sep, r_eye to +sep
		vr_map_limb(bridge, cam_l, neck, false, true);
		vr_map_limb(bridge, cam_r, neck, false, true);
	end

	local sc =
	vr_setup(hmd_arg, function(source, status)
		if (status.kind == "terminated") then
			wnd:set_title("VR Bridge shut down (no devices/no permission)");
			table.remove_match(wnd.leases, disp);
			display_release(name);
			delete_image(source);
		end
		if (status.kind == "limb_removed") then
			if (status.name == "neck") then
				delete_image(source);
				display_release(name);
				table.remove_match(wnd.leases, disp);
			end
		elseif (status.kind == "limb_added") then
			if (status.name == "neck") then
				setup_vrpipe(source, status.id);
			end
		end
	end);

	if not sc then
		display_release(name);
		wnd:set_title("vr bridge startup failed");
	end
end

local function vr_destroy(wnd)
	for _,v in ipairs(wnd.leases) do
		display_release(v.name);
	end
end

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
	wmd.vr_pipe = tgtsurf;
	wnd.rtgt_id = 0;
	wnd.leases = {};
	wnd:add_handler("destroy", vr_destroy);

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
		handler = function(ctx, val)
			hmd_arg = val;
		end,
		},
		{
		name = "switch_model",
		label = "Projection Model",
		kind = "value",
		description = "Determine the source mapping projection model",
		set = {"Sphere", "Hemisphere", "Cylinder", "Cube"},
		handler = function(ctx, val)
			set_model(wnd, string.lower(val));
		end
		},
		{
		name = "eyeswap",
		label = "Swap Left/Right",
		kind = "action",
		eval = function() return wnd.vr_rt; end,
		description = "Switch left and right eye position when mapping the source",
		handler = function()
			wnd.rtgt_id = wnd.rtgt_id == 0 and 1 or 0;
			rendertarget_id(wnd.vr_rt_l, wnd.rtgt_id);
			if (wnd.vr_rt_r) then
				rendertarget_id(wnd.vr_rt_r, wnd.rtgt_id == 0 and 1 or 0);
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
		{
		name = "setup_vr",
		label = "Setup VR",
		kind = "value",
		set = function()
			local res = {};
			display_bytag("VR", function(disp) table.insert(res, disp.name); end);
			return res;
		end,
		eval = function()
			local res;
			display_bytag("VR", function(disp) res = true; end);
			return res;
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

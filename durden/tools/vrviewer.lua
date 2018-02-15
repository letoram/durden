--
-- Simple VR window manager and image- /model- viewer
--
-- this is intended to be wrapped around a small stub loader so
-- that it can be broken out into a separate arcan appl of its own,
-- not needing to piggyback on durden.
--
local hmd_arg = "";
local vr_near = 0.01;
local vr_far = 100.0;
local layer_distance = 0.2;
local TIMEVAL = 20;

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

local function relayout_layer(wnd, layer)

end

local function layer_zpos(layer)
	if (layer.fixed) then
		return layer.dz;
	else
		return layer.index * -layer_distance + layer.dz;
	end
end

local function build_model(wnd, layer, kind, name)
	local model;
	local depth = layer.depth;

	if (kind == "cylinder") then
		model = build_cylinder(depth, 0.5 * depth, 359, 1);
	elseif (kind == "sphere") then
		model = build_sphere(depth, 360, 360, 1, true);
	elseif (kind == "hemisphere") then
		model = build_sphere(depth, 360, 180, 1, true);
--	elseif (kind == "flat") then need this for sbs-3d material
	elseif (kind == "cube") then
		model = build_3dbox(depth, depth, depth, 1);
	elseif (kind == "rectangle") then
		local hd = depth * 0.5;
		model = build_3dplane(
			-hd, -hd, hd, hd, depth, depth / 20, depth / 20, 1, true);
	else
		return;
	end

	if (not valid_vid(model)) then
		return;
	end

	swizzle_model(model);
	show_image(model);
	image_shader(model, geomshader);

	image_sharestorage(wnd.placeholder, model);

	rendertarget_attach(wnd.vr_pipe, model, RENDERTARGET_DETACH);
	link_image(model, layer.anchor);

-- need control over where the thing spawns ..
	table.insert(layer.models,
	{
		vid = model,
		name = name
	});
	move3d_model(model, 1.05 * depth * (#layer.models - 1), 0, 0);
end

-- when the VR bridge is active, we still want to be able to tune the
-- distortion, fov, ...

local function setup_vr_display(wnd, name, headless)
	local disp = display_lease(name);
	if (not disp and not headless) then
		return;
	end

-- or make these status messages into some kind of logging console,
-- probably best when we can make internal TUI connections and do
-- it that way
	wnd:set_title("Spawning VR Bridge");

-- ideally, we'd get a display with two outputs so that we could map
-- the rendertargets directly to the outputs, getting rid of one step
	local setup_vrpipe = function(bridge, md, neck)
		local dispw = math.clamp(
			(md.width and md.width > 0) and md.width or 1920, MAX_SURFACEW);
		local disph = math.clamp(
			(md.height and md.height > 0) and md.height or 1024, MAX_SURFACEH);
		local halfw = dispw * 0.5;

-- assume SBS configuration, L/R, combiner is where we apply distortion
-- and the rendertarget we bind to a preview window as well as map to
-- the display
		local combiner = alloc_surface(dispw, disph);
		local l_eye = alloc_surface(halfw, disph);
		local r_eye = alloc_surface(halfw, disph);
		show_image({l_eye, r_eye});

-- since we don't show any other models, this is fine without a depth buffer
		define_rendertarget(combiner, {l_eye, r_eye});
		define_linktarget(l_eye, wnd.vr_pipe);
		define_linktarget(r_eye, wnd.vr_pipe);
		rendertarget_id(l_eye, 0);
		rendertarget_id(r_eye, 1);
		move_image(r_eye, halfw, 0);

		local cam_l = null_surface(1, 1);
		local cam_r = null_surface(1, 1);
		scale3d_model(cam_l, 1.0, -1.0, 1.0);
		scale3d_model(cam_r, 1.0, -1.0, 1.0);

-- adjustable delta?
		local l_fov = (md.left_fov * 180 / 3.14159265359);
		local r_fov = (md.right_fov * 180 / 3.14159265359);

		if (md.left_ar < 0.01) then
			md.left_ar = halfw / disph;
		end

		if (md.right_ar < 0.01) then
			md.right_ar = halfw / disph;
		end

		camtag_model(cam_l, vr_near, vr_far, l_fov, md.right_ar, true, true, 0, l_eye);
		camtag_model(cam_r, vr_near, vr_far, r_fov, md.right_ar, true, true, 0, r_eye);

-- the distortion model has three options, no distortion, fragment shader
-- distortion and (better) mesh distortion that can be configured with
-- image_tesselation (not too many subdivisions, maybe 30, 40 something

-- ipd is set by moving l_eye to -sep, r_eye to +sep
		if (not headless) then
			vr_map_limb(bridge, cam_l, neck, false, true);
			vr_map_limb(bridge, cam_r, neck, false, true);
			wnd.vr_state = {
				l = cam_l, r = cam_r, meta = md,
				rt_l = l_eye, rt_r = r_eye
			};
			wnd:set_title("HMD active");
			link_image(combiner, wnd.anchor);
			map_video_display(combiner, disp.id, HINT_PRIMARY);
		else
			local wnd =
				active_display():add_window(combiner, {scalemode = "stretch"});
			show_image(combiner);
			wnd:set_title("Simulated Output");
		end
	end

-- debugging, fake a hmd and set up a pipe for that
	if (headless) then
		setup_vrpipe(nil, {
			left_fov = 1.80763751, right_fov = 1,80763751,
			left_ar = 0.888885, right_ar = 0.88885}, nil);
		return;
	end

	local sc =
	vr_setup(hmd_arg, function(source, status)
		if (status.kind == "terminated") then
			wnd:set_title("VR Bridge shut down (no devices/no permission)");
			table.remove_match(wnd.leases, disp);
			display_release(name);
			wnd.vr_state = nil;
			delete_image(source);
		end
		if (status.kind == "limb_removed") then
			if (status.name == "neck") then
				delete_image(source);
				display_release(name);
				wnd.vr_state = nil;
				table.remove_match(wnd.leases, disp);
			end
		elseif (status.kind == "limb_added") then
			if (status.name == "neck") then
				if (not wnd.vr_state) then
					local md = vr_metadata(source);
					setup_vrpipe(source, md, status.id);
				else
					warning("vr bridge reported neck limb twice");
				end
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

-- HMD config == parameters from device -> display profile overrides ->
-- temporary UI overrides -> ...
-- tunables:
--  step_ipd
--  step_fov
--  distortion_model
--  distortion_values
--  abberation_values
--  vignetting
--  distortion[ffff]
--  abberation[ffff] : vs defaults
--  warp_scale
--  l_fov_deg_tan, r_fov_deg_tan
--  ar_l, ar_r,
--  h_sz, v_sz,
--  distortion model (none, fragment)
--
local hmdconfig = {
};

local function select_layer(wnd, layer)
	if (wnd.selected_layer) then
		if (wnd.selected_layer == layer) then
			return;
		end
		wnd.selected_layer = nil;
	end

	wnd.selected_layer = layer;
	move3d_model(layer.anchor, 0, 0, layer_zpos(layer), TIMEVAL);
-- here we can set alpha based on distance as well
end

--
-- Layers act as planes of models that are linked together via a shared
-- positional anchor. One selected window per layer, one active layer per
-- scene/window - in essence, a window manager.
--
-- The default layouer layouter puts the active layer at one depth, and
-- the others go outwards, optionally with lower opacity
--
-- In this setup. the user is stationary, no motion controls are mapped,
-- only head tracking.
--

local function reindex_layers(wnd)
	local li = 1;
	for i,v in ipairs(wnd.layers) do
		if (not v.fixed) then
			v.index = li;
			li = li + 1;
		end
	end
end

local function add_layer(wnd, tag)
	local layer = {
		name = tag,
		dx = 0, dy = 0, dz = 0,
		depth = 0.1,
		opacity = 1.0,
		models = {},
		anchor = null_surface(1, 1)
	};

	show_image(layer.anchor);
	table.insert(wnd.layers, layer);
	reindex_layers(wnd);

	return layer;
end

local function add_model_menu(wnd, layer)

-- deal with the 180/360 transition shader-wise
	local lst = {
		pointcloud = "Point Cloud",
		sphere = "Sphere",
		hemisphere = "Hemisphere",
		rectangle = "Rectangle",
		cylinder = "Cylinder",
		cube = "Cube",
	};

	local res = {};
	for k,v in pairs(lst) do
		table.insert(res,
		{
		label = v, name = k, kind = "value",
		validator = function(val)
			return val and string.len(val) > 0;
		end,
		handler = function(ctx, val)
			build_model(wnd, layer, k, val)
		end,
		description = string.format("Add a %s to the layer", v)
		}
		);
	end
	return res;
end

local function get_layer_settings(wnd, layer)
	return {
	{
		name = "depth",
		label = "Depth",
		description = "Set the desired depth for new models",
		kind = "value",
		hint = "(0.001..99)",
		initial = tostring(layer.depth),
		validator = gen_valid_num(0.001, 99.0, 0.1),
		handler = function(ctx, val)
			layer.depth = tonumber(val);
		end
	},
	{
		name = "fixed",
		label = "Fixed",
		initial = layer.fixed and LBL_YES or LBL_NO,
		set = {LBL_YES, LBL_NO},
		kind = "value",
		description = "Lock the layer in place",
		handler = function(ctx, val)
			layer.fixed = val == LBL_YES;
			reindex_layers(wnd);
		end
	},
	{
		name = "ignore",
		label = "Ignore",
		description = "This layer will not be considered for relative selection",
		set = {LBL_YES, LBL_NO},
		kind = "value",
		handler = function(ctx, val)
			layer.ignore = val == LBL_YES;
		end
	},
	};
end

local function set_source_asynch(wnd, layer, model, source, status)
	if (status.kind == "load_failed" or status.kind == "terminated") then
		delete_image(source);
		return;
	end
	image_sharestorage(source, model.vid);
	image_texfilter(source, FILTER_BILINEAR);
end

local function model_settings_menu(wnd, layer, model)
	local res = {
	{
		name = "swap_n",
		label = "Next",
		kind = "action",
		description = "Swap position with the previous one in the list",
		eval = function() return #layer.models > 1; end,
		handler = function()
		end,
	},
	{
		name = "swap_p",
		label = "Previous",
		kind = "action",
		eval = function() return #layer.models > 1; end,
		handler = function()
		end,
	},
	{
		name = "source",
		label = "Source",
		kind = "action",
		description = "Specify the path to a resource that should be mapped to the model",
		validator =
		function(str)
			return str and string.len(str) > 0;
		end,
		handler = function(ctx, res)
			if (not resource(res)) then
				return;
			end
			local vid = load_image_asynch(res,
				function(...)
					set_source_asynch(wnd, layer, model, ...);
				end
			);
			if (valid_vid(vid)) then
				link_image(vid, model.vid);
			end
		end
	},
	{
		name = "destroy",
		label = "Destroy",
		kind = "action",
		description = "Delete the model and all associated/mapped resources",
		handler = function(ctx, res)
			delete_image(model.vid);
			for i,v in ipairs(layer.models) do
				if (v == model) then
					table.remove(layer.models, i);
					return;
				end
			end
		end
	},
	{
		name = "browse",
		label = "Browse",
		description = "Browse for a source image or video to map to the model",
		kind = "action",
		eval = function() return type(browse_file) == "function"; end,
		handler = function()
			local loadfn = function(res)
				local vid = load_image_asynch(res,
					function(...)
						set_source_asynch(wnd, layer, model, ...);
					end
				);
				if (valid_vid(vid)) then
					link_image(vid, model.vid);
				end
			end
			browse_file({},
				{png = loadfn, jpg = loadfn, bmp = loadfn}, SHARED_RESOURCE, nil);
		end
	},
	{
		name = "map",
		label = "Map",
		description = "Map the contents of another window to the model",
		kind = "action",
		handler = function()
		end
	},
	};
-- stereo, source, external connection point
	return res;
end

local function change_model_menu(wnd, layer)
	local res = {};

	for i,v in ipairs(layer.models) do
		table.insert(res,
		{
			name = v.name,
			kind = "action",
			submenu = true,
			label = v.name,
			handler = function()
				return model_settings_menu(wnd, layer, v);
			end,
		});
	end

	return res;
end

local function get_layer_menu(wnd, layer)
	return {
		{
			name = "add_model",
			label = "Add Model",
			description = "Add a new mappable model to the layer",
			submenu = true,
			kind = "action",
			handler = function() return add_model_menu(wnd, layer); end,
		},
		{
			label = "Open Terminal",
			description = "Add a terminal premapped model to the layer",
			kind = "action",
			name = "terminal",
			handler = function()
-- go with model_menu + prespawn and attach, have special path for
-- font size control based on projected near- screen size, font sz
-- and from-terminal spawned connections
			end
		},
		{
			name = "models",
			label = "Models",
			description = "Manipulate individual models",
			submenu = true,
			kind = "action",
			handler = function()
				return change_model_menu(wnd, layer);
			end,
			eval = function() return #layer.models > 0; end,
		},
		{
			name = "swap",
			label = "Swap",
			description = "Switch layer position with another layer",
			kind = "value",
			set = function()
				local lst = {};
				for _, v in ipairs(lst) do
				end
			end,
			eval = function() return #wnd.layers > 1; end,
			handler = function()
print("FIXME");
			end,
		},
		{
			name = "hide",
			label = "Hide",
			kind = "action",
			description = "Hide the layer",
			eval = function() return layer.hidden == nil; end,
			handler = function()
				layer.hidden = true;
				blend_image(layer.anchor, 0.0, TIMEVAL);
			end,
		},
		{
			name = "reveal",
			label = "Reveal",
			kind = "action",
			description = "Show a previously hidden layer",
			eval = function() return layer.hidden == true; end,
			handler = function()
				layer.hidden = nil;
				blend_image(layer.anchor, layer.opacity, TIMEVAL);
			end,
		},
		{
			name = "focus",
			label = "Focus",
			description = "Set this layer as the active focus layer",
			kind = "action",
			eval = function() return #wnd.layers > 1 and wnd.focus_layer ~= layer; end,
			handler = function()
print("FIXME");
			end,
		},
		{
			name = "spin",
			label = "Spin",
			description = "Rotate the layer relatively around the y axis",
			kind = "value",
			initial = "0 0",
			hint = "(degrees time)",
			validator = suppl_valid_typestr("ff", 0.0, 359.0, 0.0),
			handler = function(ctx, val)
				local res = suppl_unpack_typestr("ff", val, -1000, 1000);
				rotate3d_model(layer.anchor, 0, 0, res[1], res[2], ROTATE_RELATIVE);
			end
		},
		{
			name = "orient",
			label = "Orient",
			description = "Set the absolute rotation of the layer",
			kind = "value",
			validator = gen_valid_num(0, 359, 0),
			handler = function()
				local dx, dy, dz, dt = suppl_unpack_typestr("ffff", val, -10, 10);
			end
		},
		{
			name = "nudge",
			label = "Nudge",
			description = "Move the layer anchor relative to its current position",
			hint = "(x y z dt)",
			kind = "value",
			eval = function(ctx, val)
				return not layer.fixed;
			end,
			validator = suppl_valid_typestr("ffff", 0.0, 359.0, 0.0),
			handler = function(ctx, val)
				local res = suppl_unpack_typestr("ffff", val, -10, 10);
				instant_image_transform(layer.anchor);
				layer.dx = layer.dx + res[1];
				layer.dy = layer.dy + res[2];
				layer.dz = layer.dz + res[3];
				move3d_model(layer.anchor, layer.dx, layer.dy, layer_zpos(layer), res[4]);
			end,
		},
		{
			name = "settings",
			label = "Settings",
			description = "Layer specific controls for layouting and window management";
			kind = "action",
			submenu = true,
			handler = function()
				return get_layer_settings(wnd, layer);
			end
		},
	};
end

local function layer_menu(wnd)
	local res = {};
	if (wnd.selected_layer) then
		table.insert(res, {
			name = "current",
			submenu = true,
			kind = "action",
			description = "Currently focused layer",
			label = "Current",
			handler = function() return get_layer_menu(wnd, wnd.selected_layer); end
		});

		table.insert(res, {
			name = "push_pull",
			label = "Push/Pull",
			description = "Move all layers relatively closer (>0) or farther away (<0)",
			kind = "value",
			validator = gen_valid_float(-10, 10),
			handler = function(ctx, val)
				local step = tonumber(val);
				for i,v in ipairs(wnd.layers) do
					instant_image_transform(v.anchor);
					v.dz = v.dz + step;
					move3d_model(v.anchor, v.dx, v.dy, layer_zpos(layer), TIMEVAL);
				end
			end
		});
	end

	table.insert(res, {
	label = "Add",
	description = "Add a new window layer";
	kind = "value",
	name = "add",
	hint = "(tag name)",
-- require layer to be unique
	validator = function(str)
		if (str and string.len(str) > 0) then
			for _,v in ipairs(wnd.layers) do
				if (v.tag == str) then
					return false;
				end
			end
			return true;
		end
		return false;
	end,
	handler = function(ctx, val)
		local layer = add_layer(wnd, val);
		select_layer(wnd, layer);
	end
	});

	for k,v in ipairs(wnd.layers) do
		table.insert(res, {
			name = "layer_" .. v.name,
			submenu = true,
			kind = "action",
			label = v.name,
			handler = function() return get_layer_menu(wnd, v); end
		});
	end

	return res;
end

local function load_presets(wnd, path)
	local lst = system_load("tools/vrpresets/" .. path, false);
	if (not lst) then
		warning("vr-load preset (" .. path .. ") couldn't load/parse script");
		return;
	end
	local cmds = lst();
	if (not type(cmds) == "table") then
		warning("vr-load preset (" .. path .. ") script did not return a table");
	end
	for i,v in ipairs(cmds) do
		dispatch_symbol("#" .. v);
	end
end

local function drag_rotate(ctx, vid, dx, dy)
	rotate3d_model(ctx.wnd.cam, 0, dy, dx, 0, ROTATE_RELATIVE);
end

local function drag_layer(ctx, vid, dx, dy)
	local layer = ctx.wnd.selected_layer;
	if (not layer or layer.fixed) then
		return;
	end

	layer.dz = layer.dz + 0.001 * dy + 0.001 * dx;
	move3d_model(layer.anchor, layer.dx, layer.dy, layer_zpos(layer));
end

local function vrwnd()
-- flip for rendertarget
	local cam = null_surface(1, 1);
	scale3d_model(cam, 1.0, -1.0, 1.0);

-- setup a rendetarget for this model alone, use unm as placeholder
	local tgtsurf = alloc_surface(VRESW, VRESH);
	local placeholder = fill_surface(64, 64, 128, 128, 128);

	define_rendertarget(tgtsurf, {cam, placeholder},
		RENDERTARGET_DETACH, RENDERTARGET_NOSCALE, -1, RENDERTARGET_FULL);
	camtag_model(cam, vr_near, vr_far, 45.0, 1.33, true, true, 0, tgtsurf);

-- and bind to a new window
	local wnd = active_display():add_window(tgtsurf, {scalemode = "stretch"});

	wnd.cam = cam;
	wnd.placeholder = placeholder;
	wnd.vr_pipe = tgtsurf;
	wnd.rtgt_id = 0;
	rendertarget_id(tgtsurf, 0);

-- leases that we have taken from the display manager
	wnd.leases = {};

-- all UI is arranged into layers of models
	wnd.layers = {};

	wnd:add_handler("destroy", vr_destroy);

-- no default symbol bindings
	wnd.bindings = {};

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
	wnd.handlers.mouse.canvas.drag = drag_rotate;

	local lst = {};
	for k,v in pairs(wnd.handlers.mouse.canvas) do
		table.insert(lst, k);
	end
	wnd.handlers.mouse.canvas.wnd = wnd;
	mouse_droplistener(wnd.handlers.mouse.canvas);
	mouse_addlistener(wnd.handlers.mouse.canvas, lst);

	show_image(tgtsurf);
	wnd.menu_state_disable = true;

-- add window specific menus that expose the real controls
	wnd.actions = {
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
		name = "settings",
		kind = "value",
		label = "VR Settings",
		description = "Set the arguments that will be passed to the VR device",
		handler = function(ctx, val)
			hmd_arg = val;
		end,
		},
		{
		name = "layers",
		kind = "action",
		submenu = true,
		label = "Layers",
		description = "Model layers for controlling models and data sources",
		handler = function() return layer_menu(wnd); end
		},
		{
		name = "preset",
		label = "Preset",
		kind = "value",
		set = function()
			local set = glob_resource("tools/vrpresets/*.lua", APPL_RESOURCE);
			return set;
		end,
		eval = function()
			local set = glob_resource("tools/vrpresets/*.lua", APPL_RESOURCE);
			return set and #set > 0;
		end,
		handler = function(ctx, val)
			load_presets(wnd, val);
		end,
		},
		{
		name = "mouse",
		kind = "value",
		description = "Change the current mouse cursor behavior when dragged or locked",
		label = "Mouse",
		set = {"Selected", "View", "Layer Distance"},
		handler = function(ctx, val)
			if (val == "View") then
				wnd.handlers.mouse.canvas.drag = drag_rotate;
			elseif (val == "Layer Distance") then
				wnd.handlers.mouse.canvas.drag = drag_layer;
			end
		end
		},
		{
		name = "hmdconfig",
		label = "HMD Configuration",
		kind = "action",
		submenu = true,
		eval = function() return wnd.vr_state ~= nil; end,
		handler = hmdconfig
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

	if (DEBUGLEVEL > 0) then
		table.insert(wnd.actions, {
			name = "headless_vr";
			label = "Headless VR",
			kind = "action",
			description = "Debug- VR window without a HMD display",
			handler = function(ctx, val)
				setup_vr_display(wnd, val, true);
			end
		});
	end

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

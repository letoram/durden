--
-- This set of scripts provides a basic pipeline setup/config
-- based on a returned configuration function that takes a context
-- to be filled, and a table of tuning options.
--
-- This setup can then be fed to a corresponding function in vrmenus.lua
-- to add a filesystem tree of options and controls.
--
-- Basic use:
-- local vr_setup = system_load("vrsetup.lua")();
-- vr_setup(myctx, myopts);
--
-- Properties:
-- camera(vid) : camera (left eye)
-- vr_pipe(vid) : rendertarget with objects
-- layers(table) : list of current layers
--
-- Methods:
--  :add_layer(name) => layer
--  :setup_vrpipe(opts) => vid
--
-- [Layer]
-- Properties:
--   fixed(bool) : depth manipulation options don't affect the layer
--
-- Methods:
--   :build_model(kind(string), name(string) => model or nil
--                kind :- cylinder, sphere, hemisphere, cube, rectangle.
--
-- [Model]
-- Properties:
--   vid(vid)
--   name(string)
--   ctx(table) : reference back to myctx
--   layer(table) : reference to parent layer
--
-- Methods:
--   destroy()
--   set_external
--

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

local tfrag = [[
uniform sampler2D map_tu0;
varying vec2 texco;
uniform float obj_opacity;
void main()
{
	vec3 col = texture2D(map_tu0, vec2(texco.s, 1.0 - texco.t)).rgb;
	gl_FragColor = vec4(col.rgb, obj_opacity);
}
]];

local vrshaders = {
	geom = build_shader(vert, nil, "vr_geom"),
	term = build_shader(nil, tfrag, "vr_term")
};

local function set_model_uniforms(
	leye_x, leye_y, leye_ss, leye_st, reye_x, reye_y, reye_ss, reye_st)
	shader_uniform(vrshaders.geom, "ofs_leye", "ff", leye_x, leye_y);
	shader_uniform(vrshaders.geom, "scale_leye", "ff", leye_ss, leye_st);
	shader_uniform(vrshaders.geom, "ofs_reye", "ff", reye_x, reye_y);
	shader_uniform(vrshaders.geom, "scale_reye", "ff", reye_ss, reye_st);
end

set_model_uniforms(0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0);

-- when the VR bridge is active, we still want to be able to tune the
-- distortion, fov, ...

local function set_vr_defaults(ctx, opts)
	local tbl = {
		oversample = 1.4,
		msaa = false,
		hmdarg = "",

	};
	for k,v in pairs(tbl) do
		ctx[k] = (opts[k] and opts[k]) or tbl[k];
	end
end

local function setup_vr_display(wnd, headless, opts)
	set_vr_defaults(wnd, opts);

-- or make these status messages into some kind of logging console,
-- probably best when we can make internal TUI connections and do
-- it that way

-- ideally, we'd get a display with two outputs so that we could map
-- the rendertargets directly to the outputs, getting rid of one step
	local setup_vrpipe = function(bridge, md, neck)
		local dispw = math.clamp(
			(md.width and md.width > 0) and md.width or 1920, MAX_SURFACEW);
		local disph = math.clamp(
			(md.height and md.height > 0) and md.height or 1024, MAX_SURFACEH);
		local halfw = dispw * 0.5;

-- Assume SBS configuration, L/R, combiner is where we apply distortion
-- and the rendertarget we bind to a preview window as well as map to
-- the display.
--
-- A few things are missing here, the big one is being able to set MSAA
-- sampling and using the correct shader / sampler for that in the combiner
-- stage.
--
-- The second is actual distortion parameters via a mesh.
--
-- The third is a stencil mask over the rendertarget (missing Lua API).
		local combiner = alloc_surface(dispw, disph);
		local l_eye = alloc_surface(halfw * opts.oversample_x, disph * opts.oversample_y);
		local r_eye = alloc_surface(halfw * opts.oversample_y, disph * opts.oversample_y);
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
			wnd:message("HMD active");
			link_image(combiner, wnd.anchor);
			map_video_display(combiner, disp.id, HINT_PRIMARY);
		else
			show_image(combiner);
			headless(wnd, combiner);
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
			wnd:message("VR Bridge shut down (no devices/no permission)");
			table.remove_match(wnd.leases, disp);
			wnd.vr_state = nil;
			delete_image(source);
		end
		if (status.kind == "limb_removed") then
			if (status.name == "neck") then
				delete_image(source);
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
end

local function model_external(model, vid)
-- do the displayhint based on the current layer depth
end

local function build_model(layer, kind, name)
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
	image_shader(model, vrshaders.geom);

	image_sharestorage(layer.ctx.placeholder, model);

	rendertarget_attach(layer.ctx.vr_pipe, model, RENDERTARGET_DETACH);
	link_image(model, layer.anchor);

-- need control over where the thing spawns ..
	local res = {
		vid = model,
		name = name,
		destroy = function()
			table.remove_match(layer.models, model);
			delete_image(model);
		end,
		set_external = model_external,
		ctx = layer.ctx
	};

-- need something to specify up/down/left/right
-- and animate spawn of course :-)

	return res;
end

local function set_defaults(ctx, opts)
	local tbl = {
		layer_distance = 0.2,
		near_layer_sz = 1024,
		display_density = 33,
		terminal_font = "default.ttf",
		terminal_font_sz = 18,
		animation_speed = 20
	};

	for k,v in pairs(tbl) do
		ctx[k] = (opts[k] and opts[k]) or tbl[k];
	end
end

local function reindex_layers(ctx)
	local li = 1;
	for i,v in ipairs(ctx.layers) do
		if (not v.fixed) then
			v.index = li;
			li = li + 1;
		end
	end
end

local function layer_zpos(layer)
	if (layer.fixed) then
		return layer.dz;
	else
		local dv = layer.index * -layer.ctx.layer_distance + layer.dz;
		return dv;
	end
end

local function layer_add_model(layer, kind, name)
	local model = build_model(layer, kind, name);
	if (not model) then
		return;
	end

	table.insert(layer.models, model);
	move3d_model(model.vid, 1.05 * layer.depth * (#layer.models - 1), 0, 0);
	if (not layer.selected) then
		layer.selected = model;
	end
	model.layer = layer;

	return model;
end

local function layer_step(layer, dx, dy)
	layer.dz = layer.dz + 0.001 * dy + 0.001 * dx;
	move3d_model(layer.anchor, layer.dx, layer.dy, layer_zpos(layer));
end

local function layer_select(layer)
	if (layer.ctx.selected_layer) then
		if (layer.ctx.selected_layer == layer) then
			return;
		end
		layer.ctx.selected_layer = nil;
	end

	layer.ctx.selected_layer = layer;
	move3d_model(layer.anchor, 0, 0, layer_zpos(layer), layer.ctx.animation_speed);
-- here we can set alpha based on distance as well
end

local function layer_set_fixed(layer, fixed)
	layer.fixed = val == LBL_YES;
	reindex_layers(layer.ctx);
end

local function layer_add(ctx, tag)
	local layer = {
		ctx = ctx,
		anchor = null_surface(1, 1),
		models = {},

		add_model = layer_add_model,
		step = layer_step,
		zpos = layer_zpos,
		set_fixed = layer_set_fixed,
		select = layer_select,

		name = tag,

		dx = 0, dy = 0, dz = 0,
		depth = 0.1,
		opacity = 1.0
	};

	show_image(layer.anchor);
	table.insert(ctx.layers, layer);
	reindex_layers(ctx);
	layer:select();

	return layer;
end

return function(ctx, surf, opts)
	set_defaults(ctx, opts);

-- render to texture, so flip y
	local cam = null_surface(1, 1);
	scale3d_model(cam, 1.0, -1.0, 1.0);

-- reference color / texture to use as a placeholder
	local placeholder = fill_surface(64, 64, 128, 128, 128);

-- preview window, don't be picky
	define_rendertarget(surf, {cam, placeholder},
		RENDERTARGET_DETACH, RENDERTARGET_NOSCALE, -1, RENDERTARGET_FULL);
	camtag_model(cam, vr_near, vr_far, 45.0, 1.33, true, true, 0, surf);

-- actual vtable and properties
	ctx.add_layer = layer_add;
	ctx.camera = cam;
	ctx.placeholder = placeholder;
	ctx.vr_pipe = surf;
	ctx.setup_vr = setup_vr_display;

-- special case, always take the left eye view on stereoscopic sources,
-- the real stereo pipe takes the right approach of course
	rendertarget_id(surf, 0);

-- all UI is arranged into layers of models
	ctx.layers = {};
end

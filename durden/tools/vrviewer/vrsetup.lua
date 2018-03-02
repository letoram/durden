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
uniform bool flip;
uniform float curve;

varying vec2 texco;

void main()
{
	vec2 tc = texcoord;
	if (flip){
		tc.t = 1.0 - tc.t;
	}

	vec4 vert = vertex;

	if (rtgt_id == 0){
		tc *= scale_leye;
		tc += ofs_leye;
	}
	else {
		tc *= scale_reye;
		tc += ofs_reye;
	}

	gl_Position = projection * modelview * vert;
	texco = tc;
}
]];

-- shader used on each eye, one possible place for distortion but
-- probably better to just use image_tesselation to displace the
-- vertices on l_eye and r_eye once, and use the shader stage for
-- variable vignette using obj_opacity as strength. We also need
-- variants to handle samplers that force external or multiplanar
local combiner = [[
uniform sampler2D map_tu0;
varying vec2 texco;
uniform float obj_opacity;

void main()
{
	vec3 col = texture2D(map_tu0, texco).rgb;
	gl_FragColor = vec4(col.rgb, 1.0);
}
]];

local vrshaders = {
	geom = build_shader(vert, nil, "vr_geom"),
	left = build_shader(nil, combiner, "vr_eye_l"),
	right = build_shader(nil, combiner, "vr_eye_r")
};

local function set_model_uniforms(
	leye_x, leye_y, leye_ss, leye_st, reye_x, reye_y, reye_ss, reye_st)
	shader_uniform(vrshaders.geom, "ofs_leye", "ff", leye_x, leye_y);
	shader_uniform(vrshaders.geom, "scale_leye", "ff", leye_ss, leye_st);
	shader_uniform(vrshaders.geom, "ofs_reye", "ff", reye_x, reye_y);
	shader_uniform(vrshaders.geom, "scale_reye", "ff", reye_ss, reye_st);
	shader_uniform(vrshaders.geom, "flip", "b", false);
	shader_uniform(vrshaders.geom, "curve", "f", 0);

	vrshaders.geom_inv = shader_ugroup(vrshaders.geom);
	vrshaders.rect = shader_ugroup(vrshaders.geom);
	vrshaders.rect_inv = shader_ugroup(vrshaders.geom);

-- could ofc. just scale-1 the model instead of maintaining the shader state
	shader_uniform(vrshaders.geom_inv, "flip", "b", true);
	shader_uniform(vrshaders.rect_inv, "flip", "b", true);
	shader_uniform(vrshaders.rect, "curve", "f", 0.5);
	shader_uniform(vrshaders.rect_inv, "curve", "f", 0.5);
end

set_model_uniforms(0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0);

-- when the VR bridge is active, we still want to be able to tune the
-- distortion, fov, ...
local function set_vr_defaults(ctx, opts)
	local tbl = {
		oversample_w = 1.4,
		oversample_h = 1.4,
		msaa = false,
		hmdarg = "",

	};
	for k,v in pairs(tbl) do
		ctx[k] = (opts[k] and opts[k]) or tbl[k];
	end
end

local function setup_vr_display(wnd, callback, opts)
	set_vr_defaults(wnd, opts);

-- or make these status messages into some kind of logging console,
-- probably best when we can make internal TUI connections and do
-- it that way

-- ideally, we'd get a display with two outputs so that we could map
-- the rendertargets directly to the outputs, getting rid of one step
	local setup_vrpipe = function(bridge, md, neck)
		local dispw = md.width > 0 and md.width or 1920;
		local disph = md.height > 0 and md.height or 1024;
		dispw = math.clamp(dispw, 256, MAX_SURFACEW);
		disph = math.clamp(disph, 256, MAX_SURFACEH);
		local eyew = math.clamp(dispw * wnd.oversample_w, 256, MAX_SURFACEW);
		local eyeh = math.clamp(disph * wnd.oversample_h, 256, MAX_SURFACEH);
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
		local l_eye = alloc_surface(eyew, eyeh);
		local r_eye = alloc_surface(eyew, eyeh);
		show_image({l_eye, r_eye});

-- since we don't show any other models, this is fine without a depth buffer
		define_rendertarget(combiner, {l_eye, r_eye});
		define_linktarget(l_eye, wnd.vr_pipe);
		define_linktarget(r_eye, wnd.vr_pipe);
		rendertarget_id(l_eye, 0);
		rendertarget_id(r_eye, 1);
		move_image(r_eye, halfw, 0);
		resize_image(l_eye, halfw, disph);
		resize_image(r_eye, halfw, disph);
		image_shader(l_eye, vrshaders.left);
		image_shader(r_eye, vrshaders.right);

		local cam_l = null_surface(1, 1);
		local cam_r = null_surface(1, 1);
		scale3d_model(cam_l, 1.0, -1.0, 1.0);
		scale3d_model(cam_r, 1.0, -1.0, 1.0);

-- adjustable delta?
		local l_fov = (md.left_fov * 180 / math.pi);
		local r_fov = (md.right_fov * 180 / math.pi);

		if (md.left_ar < 0.01) then
			md.left_ar = halfw / disph;
		end

		if (md.right_ar < 0.01) then
			md.right_ar = halfw / disph;
		end

		camtag_model(cam_l, 0.01, 100.0, l_fov, md.left_ar, true, true, 0, l_eye);
		camtag_model(cam_r, 0.01, 100.0, r_fov, md.right_ar, true, true, 0, r_eye);

-- the distortion model has three options, no distortion, fragment shader
-- distortion and (better) mesh distortion that can be configured with
-- image_tesselation (not too many subdivisions, maybe 30, 40 something

-- ipd is set by moving l_eye to -sep, r_eye to +sep
		if (not opts.headless) then
			vr_map_limb(bridge, cam_l, neck, false, true);
			vr_map_limb(bridge, cam_r, neck, false, true);
			wnd.vr_state = {
				l = cam_l, r = cam_r, meta = md,
				rt_l = l_eye, rt_r = r_eye,
				vid = bridge
			};
			wnd:message("HMD active");
			link_image(combiner, wnd.anchor);
			callback(wnd, combiner);
		else
			link_image(cam_l, wnd.camera);
			link_image(cam_r, wnd.camera);
			show_image(combiner);
			callback(wnd, combiner);
		end
	end

-- debugging, fake a hmd and set up a pipe for that
	if (opts.headless) then
		setup_vrpipe(nil, {
			width = 0, height = 0,
			left_fov = 1.80763751, right_fov = 1.80763751,
			left_ar = 0.888885, right_ar = 0.88885}, nil);
		return;
	end

	vr_setup(hmd_arg, function(source, status)
		link_image(source, wnd.camera);

		if (status.kind == "terminated") then
			wnd:message("VR Bridge shut down (no devices/no permission)");
			callback(nil);
			wnd.vr_state = nil;
			delete_image(source);
		end
		if (status.kind == "limb_removed") then
			if (status.name == "neck") then
				delete_image(source);
				callback(nil);
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

local function model_scale(model, sx, sy, sz)
	sx = sx and sx or model.scalev[1];
	sy = sy and sy or model.scalev[2];
	sz = sz and sz or model.scalev[3];
	model.scalev[1] = sx;
	model.scalev[2] = sy;
	model.scalev[3] = sz;
	scale3d_model(model.vid,
		model.scalev[1], model.scalev[2], model.scalev[3], model.ctx.animation_speed);
	model.layer:relayout();
end

local function model_external(model, vid, flip)
	if (not valid_vid(vid, TYPE_FRAMESERVER)) then
		if (model.external) then
			model.external = nil;
		end
		return;
	end

-- it would probably be better to go with projecting the bounding
-- vertices unto the screen and use the display+oversample factor
	local bw = model.ctx.near_layer_sz * (model.layer.index > 1 and
		((model.layer.index-1) * model.ctx.layer_falloff) or 1);

	model.external = vid;
	image_sharestorage(model.external, model.vid);

	local h_ar = model.scalev[1] / model.scalev[2];
	local v_ar = model.scalev[2] / model.scalev[1];

-- note: this will be sent during the preload stage, where the
-- displayhint property for selection/visibility will be ignored.
-- note: The HMD panels tend to have other LED configurations,
-- though the data doesn't seem to be propagated via the VR bridge
-- meaning that subpixel hinting will be a bad idea.
	target_displayhint(model.external,
		bw * h_ar, bw * v_ar, 0,
		{ppcm = model.ctx.display_density}
	);

	image_shader(model.vid,
		flip and model.shader.flip or model.shader.normal);
end

local function model_getsize(model)
	return
		model.scalev[1] * model.size[1],
		model.scalev[2] * model.size[2],
		model.scalev[3] * model.size[3];
end

local function model_destroy(model)
	local layer = model.layer;

	table.remove_match(layer.models, model);
	if (model.layer.selected) then
		model.layer.selected = nil;
	end

-- reparent children
	for _,v in ipairs(model.children) do
		v.parent = model.parent;
		if (model.parent) then
			tabl.insert(model.parent.children, v);
		end
	end

-- abandon parent
	if (model.parent) then
		table.remove(model.parent.children, model);
		model.parent = nil;
	end

-- clean up rendering resources
	delete_image(model.vid);
	if (valid_vid(model.external) and not model.external_protect) then
		delete_image(model.external);
	end

-- make it easier to detect dangling references
	for k,_ in ipairs(model) do
		model[k] = nil;
	end

	layer:relayout();
end

local function model_show(model)
	if (image_surface_properties(model.vid).opacity == model.opacity) then
		return;
	end

	blend_image(model.vid, 1.0, model.ctx.animation_speed);
	if (not model.layer.selected) then
		model:select();
	end

-- note: this does not currently set INVISIBLE state, only FOCUS
	if (valid_vid(model.external, TYPE_FRAMESERVER)) then
		if (model.layer.selected ~= model) then
			target_displayhint(model.external, 0, 0, TD_HINT_UNFOCUSED);
		else
			target_displayhint(model.external, 0, 0, 0);
		end
	end

	model.layer:relayout();
end

local function model_select(model)
	local layer = model.layer;

	if (not valid_vid(model.external, TYPE_FRAMESERVER)) then
		return;
	end

	if (layer.selected) then
		target_displayhint(layer.selected.external, 0, 0, TD_HINT_UNFOCUSED);
		layer.selected = nil;
	end
	layer.selected = model;
	target_displayhint(model.external, 0, 0, 0);
end

local function model_reparent(model, new_parent)
	if (model.parent) then
		table.remove_match(model.parent.children, model);
	end
	if (new_parent) then
		table.insert(new_parent.children, model);
	end
	model.layer:relayout();
end

local function model_mergecollapse(model)
	model.merged = not model.merged;
	model.layer:relayout();
end

local function build_model(layer, kind, name)
	local model;
	local depth = layer.depth;
	local h_depth = depth * 0.5;
	local shader = vrshaders.geom;
	local shader_inv = vrshaders.geom_inv;
	local size = {depth, depth, depth};

	if (kind == "cylinder") then
		model = build_cylinder(h_depth, depth, 359, 1);
	elseif (kind == "sphere") then
		model = build_sphere(h_depth, 360, 360, 1, true);
	elseif (kind == "hemisphere") then
		model = build_sphere(h_depth, 360, 180, 1, true);
	elseif (kind == "cube") then
		model = build_3dbox(depth, depth, depth, 1);
	elseif (kind == "rectangle") then
		size[2] = depth * (9.0 / 16.0);
		size[3] = 0.00001;
		shader = vrshaders.rect;
		shader_inv = vrshaders.rect_inv;
		model = build_3dplane(-h_depth, -0.5*size[2], h_depth, 0.5*size[2], 0,
			(depth / 20) * layer.ctx.subdiv_factor[1],
			(depth / 20) * layer.ctx.subdiv_factor[2], 1, true
		);
	else
		return;
	end

	if (not valid_vid(model)) then
		return;
	end

	swizzle_model(model);
	image_shader(model, shader);

-- in case mapping / loading fails
	image_sharestorage(layer.ctx.placeholder, model);

	rendertarget_attach(layer.ctx.vr_pipe, model, RENDERTARGET_DETACH);
	link_image(model, layer.anchor);

-- need control over where the thing spawns ..
	local res = {
		vid = model,
		name = name,
		opacity = 1.0,
		extctr = 0, -- external windows spawned via this model
		shader = {normal = shader, flip = shader_inv},
		parent = nil,
		children = {},
		select = model_select,
		scale = model_scale,
		show = model_show,
		set_parent = model_reparent,
		get_size = model_getsize,
		mergecollapse = model_mergecollapse,
		size = size,
		scalev = {1, 1, 1},
		destroy = model_destroy,
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
		layer_falloff = 0.8,
		terminal_font = "hack.ttf",
		terminal_font_sz = 12,
		animation_speed = 20,
		subdiv_factor = {1.0, 0.4},
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
	model.layer = layer;

	return model;
end

-- this only changes the offset, the radius stays the same so no need to relayout
local function layer_step(layer, dx, dy)
	layer.dz = layer.dz + 0.001 * dy + 0.001 * dx;
	move3d_model(layer.anchor, layer.dx, layer.dy, layer:zpos());
end

local function layer_select(layer)
	if (layer.ctx.selected_layer) then
		if (layer.ctx.selected_layer == layer) then
			return;
		end
		layer.ctx.selected_layer = nil;
	end

	layer.ctx.selected_layer = layer;
	move3d_model(layer.anchor, 0, 0, layer:zpos(), layer.ctx.animation_speed);
-- here we can set alpha based on distance as well
end

local function model_eventhandler(wnd, model, source, status)
	if (status.kind == "terminated") then
-- need to check if the model is set to reset to placeholder / last set /
-- open connpoint or to die on termination
		model:destroy(EXIT_FAILURE, status.last_words);

	elseif (status.kind == "resized") then
		image_texfilter(source, FILTER_BILINEAR);
		model:show();
	end
end

-- terminal eventhandler behaves similarly to the default, but also send fonts
local function terminal_eventhandler(wnd, model, source, status)
	if (status.kind == "preroll") then
		target_fonthint(source,
			wnd.terminal_font, wnd.terminal_font_sz, FONT_PT_SZ, 4);
	else
		return model_eventhandler(wnd, model, source, status);
	end
end

local clut = {
	application = model_eventhandler,
	terminal = terminal_eventhandler,
	tui = terminal_eventhandler,
	game = model_eventhandler,
	multimedia = model_eventhandler,
	["lightweight arcan"] = model_eventhandler,
	["bridge-x11"] = model_eventhandler,
	bowser = model_eventhandler,

-- handlers to types that we don't accept as primary now
	["bridge-wayland"] = nil,
	clipboard = nil, -- no clipboard managers
	wayland = nil, -- no
	popup = nil,
	icon = nil,
	titlebar = nil,
	sensor = nil,
	service = nil,
	debug = nil,
	widget = nil,
	accessibility = nil,
	clipboard_paste = nil,
	handover = nil
};

local function modelconn_eventhandler(layer, model, source, status)
	if (status.kind == "registered") then
-- based on segment type, install a new event-handler and tie to a new model
		local dstfun = clut[status.segkind];
		if (dstfun == nil) then
			delete_image(source);
			return;
		else
			local new_model =
				layer:add_model("rectangle", model.name .. "_ext_" .. tostring(model.extctr));

			target_updatehandler(source, function(source, status)
				return dstfun(layer.ctx, new_model, source, status);
			end);
			new_model:set_external(source);
			new_model:set_parent(model);
		end
	elseif (status.kind == "resized") then
		model:show();
	elseif (status.kind == "terminated") then
-- connection point died, should we bother allocating a new one?
		delete_image(source);
	end
end

local term_counter = 0;
local function layer_add_terminal(layer)
	term_counter = term_counter + 1;
	local model = layer:add_model("rectangle", "term_" .. tostring(term_counter));
	if (not model) then
		return;
	end

-- setup a new connection point that will bridge connections based on this model
		local cp = "vr_term_";
		for i=1,8 do
			cp = cp .. string.char(string.byte("a") + math.random(1, 10));
		end
	local vid = launch_avfeed("env=ARCAN_CONNPATH="..cp, "terminal",
	function(...)
		return terminal_eventhandler(layer.ctx, model, ...);
	end
	);

	if (valid_vid(vid)) then
		model:set_external(vid, true);
		link_image(vid, model.vid);

-- handover to a 'dispatch lut + create model' intermediate function
		local conn = target_alloc(cp, function(source, status)
			if (status.kind == "connected") then
				target_updatehandler(source, function(...)
					return modelconn_eventhandler(layer, model, ...);
				end);
			elseif (status.kind == "terminated") then
				delete_image(source);
			end
		end);

		if (valid_vid(conn)) then
			link_image(conn, model.vid);
		end
	else
		model:destroy();
	end
end

local function layer_set_fixed(layer, fixed)
	layer.fixed = val == LBL_YES;
	reindex_layers(layer.ctx);
end

-- basic layout algorithm,
-- there are a number of improvements to consider here:
--
-- 1. spherical billboarding for the vertical rows
--
-- 2. even divide terminals per quadrant with larger spacing and
--    only allow overlap / compaction on severe overallocation
--    (though that can possibly be dealt with in spacing)
--
-- 3. scale each quadrant on overallocation relative to the
--    distance from the 0,h_pi,pi,1.5pi,2pi phase angles.
--
-- 4. track left/right allocation so deletion don't get windows
--    to swap sides, but rather rebalance from last round.
--
-- 5. move this code out of vrsetup.lua as this should really
--    be left in the hand of other devs.
--
local function layer_relayout(layer)
-- 1. separate models that have parents and root models
	local root = {};
	local chld = {};
	local chld_collapse = {};
	for _,v in ipairs(layer.models) do
		if not v.parent then
			table.insert(root, v);
		else
			chld[v.parent] = chld[v.parent] and chld[v.parent] or {};
			table.insert(chld, v.parent);
		end
	end

-- make sure we have one element that is selected at least
	if (not layer.selected and
		valid_vid(root[1].external, TYPE_FRAMESERVER)) then
		root[1]:select();
	end

-- select is just about input, creation order is about position,
-- our zero position is at 12 o clock, so add or sub math.pi as
-- translation on the curve
	local max_h = 0;
	local h_pi = math.pi * 0.5;

	local dphi_ccw = math.pi;
	local dphi_cw = math.pi;

-- oversize the placement radius somewhat to account for the
-- alignment problem
	local zp = layer.index * -layer.ctx.layer_distance;
	local radius = math.abs(zp);

	local function getang(phi)
		phi = math.fmod(phi, 2 * math.pi);
		return 180 * phi / math.pi - 180;
	end

-- position in a circle based on the layer z-pos as radius, but
-- recall that the model is linked to the layer anchor so we need
-- to translate first.
	for i,v in ipairs(root) do
		local w, h, d = v:get_size();
		w = w + layer.spacing;
		local z = 0;
		local x = 0;
		local ang = 0;
		local hw = w * 0.5;
		max_h = max_h > h and max_h or h;

-- special case, at 12 o clock is 0, 0 @ 0 rad. ang is for billboarding,
-- there should just be a model_flag for setting spherical/cylindrical
-- billboarding (or just do it in shader) but it's not there at the
-- moment and we don't want more shader variants or flags.
-- would be nice, yet not always solvable, to align positioning at the
-- straight angles (0, half-pi, pi, ...) though the focal point of the
-- user will likely often be straight ahead and that gets special
-- treatment anyhow.
		if (i == 1) then
			dphi_cw = dphi_cw + 1.5 * w;
			dphi_ccw = dphi_ccw - 1.5 * w;
			z = -radius - zp;

		elseif (i % 2 == 0) then
			x = radius * math.sin(dphi_cw + w);
			z = radius * math.cos(dphi_cw + w) - zp;
			ang = getang(dphi_cw);
-- goes bad after one revolution, but that many clients is not very reasonable
			dphi_cw = dphi_cw + w;
		else
			x = radius * math.sin(dphi_ccw - w);
			z = radius * math.cos(dphi_ccw - w) - zp;
			ang = getang(dphi_ccw);
-- goes bad after one revolution, but that many clients is not very reasonable
			dphi_ccw = dphi_ccw - w;
		end

-- unresolved, what to do if n_x or p_x reach pi?
		instant_image_transform(v.vid);
		move3d_model(v.vid, x, 0, z, v.ctx.animation_speed);
		rotate3d_model(v.vid, 0, 0, ang, v.ctx.animation_speed);
		v.layer_ang = ang;
		v.layer_pos = {x, 0, z};
	end

-- avoid linking to stay away from the cascade deletion problem, if it needs
-- to be done for animations, then take the delete- and set a child as the
-- new parent.
	local as = layer.ctx.animation_speed;
	for k,v in pairs(chld) do
		local pw, ph, pd = k:get_size();
		local ch = ph;
		local lp = k.layer_pos;
		local la = k.layer_ang;

-- if collapsed, we increment depth by something symbolic to avoid z-fighting,
-- then offset Y enough to just see the tip, otherwise use a similar strategy
-- to the root, ignore billboarding for the time being.
		for i,j in ipairs(k) do
			if (i % 2 == 0) then
				move_image(j.vid, lp[1], lp[2] - ch, lp[3], as);
				ch = ch + ph;
			else
				move_image(j.vid, lp[1], lp[2] + ch, lp[3], as);
			end
			rotate3d_model(j.vid, k.layer_ang, as);
			pw, ph, pd = j:get_size();
			ch = ch + ph;
		end
	end
end

local function layer_add(ctx, tag)
	local layer = {
		ctx = ctx,
		anchor = null_surface(1, 1),
		models = {},

		add_model = layer_add_model,
		add_terminal = layer_add_terminal,

		step = layer_step,
		zpos = layer_zpos,
		set_fixed = layer_set_fixed,
		select = layer_select,
		relayout = layer_relayout,

		name = tag,

		dx = 0, dy = 0, dz = 0,
		depth = 0.1,
		spacing = 0.05,
		opacity = 1.0
	};

	show_image(layer.anchor);
	table.insert(ctx.layers, layer);
	reindex_layers(ctx);
	layer:select();

	return layer;
end

local function vr_input(ctx, iotbl, multicast)
	if (not ctx.selected_layer or not ctx.selected_layer.selected) then
		return;
	end
	local dst = ctx.selected_layer.selected.external;
	if (not valid_vid(dst, TYPE_FRAMESERVER)) then
		return;
	end
	target_input(dst, iotbl);
end

return function(ctx, surf, opts)
	set_defaults(ctx, opts);

-- render to texture, so flip y, camera is also used as a resource
-- anchor for destroying everything else
	local cam = null_surface(1, 1);
	scale3d_model(cam, 1.0, -1.0, 1.0);

-- reference color / texture to use as a placeholder
	local placeholder = fill_surface(64, 64, 128, 128, 128);

-- preview window, don't be picky
	define_rendertarget(surf, {cam, placeholder},
		RENDERTARGET_DETACH, RENDERTARGET_NOSCALE, -1, RENDERTARGET_FULL);
	camtag_model(cam, 0.01, 100.0, 45.0, 1.33, true, true, 0, surf);

-- actual vtable and properties
	ctx.add_layer = layer_add;
	ctx.camera = cam;
	ctx.placeholder = placeholder;
	ctx.vr_pipe = surf;
	ctx.setup_vr = setup_vr_display;

	ctx.input_table = vr_input;
	ctx.message = function(ctx, msg) print(msg); end;

-- special case, always take the left eye view on stereoscopic sources,
-- the real stereo pipe takes the right approach of course
	rendertarget_id(surf, 0);

-- all UI is arranged into layers of models
	ctx.layers = {};
end

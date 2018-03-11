local vert = [[
uniform mat4 modelview;
uniform mat4 projection;

attribute vec2 texcoord;
attribute vec4 vertex;

/* for sbs- ou- remapping */
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

	if (curve > 0.0){
		vert.z -= sin(3.14 * tc.s) * curve;
	}

	texco = tc;
	gl_Position = projection * modelview * vert;
}
]];

local frag = [[
uniform sampler2D map_tu0;
uniform float obj_opacity;
varying vec2 texco;

void main()
{
	vec3 col = texture2D(map_tu0, texco).rgb;
	gl_FragColor = vec4(col.rgb, obj_opacity);
}
]];

local modelconn_eventhandler;

-- shader used on each eye, one possible place for distortion but
-- probably better to just use image_tesselation to displace the
-- vertices on l_eye and r_eye once, and use the shader stage for
-- variable vignette using obj_opacity as strength. We also need
-- variants to handle samplers that force external or multiplanar
local combiner = [[
uniform sampler2D map_tu0;
uniform float obj_opacity;
varying vec2 texco;

void main()
{
	vec3 col = texture2D(map_tu0, texco).rgb;
	gl_FragColor = vec4(col.rgb, 1.0);
}
]];

local vrshaders = {
	geom = build_shader(vert, frag, "vr_geom"),
	left = build_shader(nil, combiner, "vr_eye_l"),
	right = build_shader(nil, combiner, "vr_eye_r")
};

local function set_model_uniforms(shid,
	leye_x, leye_y, leye_ss, leye_st, reye_x, reye_y, reye_ss, reye_st, flip, curve)
	shader_uniform(shid, "ofs_leye", "ff", leye_x, leye_y);
	shader_uniform(shid, "scale_leye", "ff", leye_ss, leye_st);
	shader_uniform(shid, "ofs_reye", "ff", reye_x, reye_y);
	shader_uniform(shid, "scale_reye", "ff", reye_ss, reye_st);
	shader_uniform(shid, "flip", "b", flip);
	shader_uniform(shid, "curve", "f", curve);
end

local function shader_defaults()
	set_model_uniforms(
		vrshaders.geom, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0, true, 0);

	vrshaders.geom_inv = shader_ugroup(vrshaders.geom);
	vrshaders.rect = shader_ugroup(vrshaders.geom);
	vrshaders.rect_inv = shader_ugroup(vrshaders.geom);

	shader_uniform(vrshaders.geom_inv, "flip", "b", false);
	shader_uniform(vrshaders.rect_inv, "flip", "b", false);
	shader_uniform(vrshaders.rect, "curve", "f", 0.01);
	shader_uniform(vrshaders.rect_inv, "curve", "f", 0.01);
end
shader_defaults();

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
	local setup_vrpipe =
	function(bridge, md, neck)
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

local function model_scale_factor(model, factor, relative)
end

local function model_scale(model, sx, sy, sz, save)
	if (not sx) then
		model.scalev = model.old_scalev;
	else
		model.scalev = {
			sx,
			sy and sy or model.scalev[2],
			sz and sz or model.scalev[3]
		};
	end
	if (save) then
		model.old_scalev = model.scalev;
	end
	scale3d_model(model.vid,
		model.scalev[1], model.scalev[2], model.scalev[3], model.ctx.animation_speed);
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

-- gets updated on_resize with origo_ll
	if (model.force_flip ~= nil) then
		image_shader(model.vid,
				model.force_flip and model.shader.flip or model.shader.normal);
	else
		model.flip = flip;
		image_shader(model.vid,
			flip and model.shader.flip or model.shader.normal);
	end
end

local function model_getsize(model)
	return
		model.scalev[1] * model.size[1],
		model.scalev[2] * model.size[2],
		model.scalev[3] * model.size[3];
end

local function model_destroy(model)
	local layer = model.layer;

-- if we are currently selected, swap in something else
	if (layer.selected == model) then
		layer:swap(true, 1);
		if (layer.selected == model) then
			layer.selected = nil;
		end
	end

	table.remove_match(layer.models, model);

-- rebalance the list of models so the positioning doesn't "flip", we can
-- do this by finding every root after our deletion point and inverting
-- their position
--	local ind;
--	for ind=1,#layer.models do
--		if (layer.models[ind] == model) then
--			break;
--		end
--	end

-- resolve into X = X+1 but ignore non-root node
--	local nexti = function(ind)
--		local res;
--		for res=ind+1, #layer.models do
--			if (not layer.models[res].parent) then
--				return res;
--			end
--		end
--		return nil;
--	end

-- swap next after deletion index with the one after that, preventing
-- the deletion-left/right inversion problem
--	local start = nexti(ind);
--	while start do
--		local st = nexti(start);
--		local tmp = layer.models[start];
--		if (st) then
--			layer.models[start] = layer.models[st];
--			layer.models[st] = tmp;
--			start = layer.models[st];
--		else
--			break;
--		end
--	end
--	table.remove(layer.models, ind);

-- reparent children
	for _,v in ipairs(model.children) do
		v.parent = model.parent;
		if (model.parent) then
			tabl.insert(model.parent.children, v);
		end
	end

	if (model.parent) then
		table.remove(model.parent.children, model);
		model.parent = nil;
	end

-- clean up rendering resources, but defer on animation
	local destroy = function()
	if (model.custom_shaders) then
		for i,v in ipairs(model.custom_shaders) do
			delete_shader(v);
		end
	end

	delete_image(model.vid);
	if (valid_vid(model.external) and not model.external_protect) then
		delete_image(model.external);
	end

-- custom shader? these are derived with shader_ugroup so delete is simple
	if (model.shid) then
		delete_shader(model.shid);
	end

-- make it easier to detect dangling references
	for k,_ in ipairs(model) do
		model[k] = nil;
	end
	end

-- animate fade out if desired
	if (model.ctx.animation_speed > 0) then
		blend_image(model.vid, 0.0, model.ctx.animation_speed);
		tag_image_transform(model.vid, MASK_OPACITY, destroy);
	else
		destroy();
	end

	layer:relayout();
end

-- in any of the external event handlers, we do this on terminated to make sure
-- that the object gets reactivated properly
local function apply_connrole(layer, model, source)
	local rv = false;

	if (model.ext_name) then
		delete_image(source);
		model:set_connpoint(model.ext_name, model.ext_kind);
		rv = true;
	end

	if (model.ext_kind) then
		if (model.ext_kind == "reveal") then
			model.active = false;
			blend_image(model.vid, 0, model.ctx.animation_speed);
			if (layer.models[1] == model) then
				table.insert(layer.models, model);
			end
			model.layer:relayout();
			rv = true;

		elseif (model.ext_kind == "temporary" and valid_vid(model.source)) then
			image_sharestorage(model.source, model.vid);
			rv = true;
		end
	end

	return rv;
end

local function model_show(model)
	model.active = true;
	if (image_surface_properties(model.vid).opacity == model.opacity) then
		return;
	end

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

	blend_image(model.vid, model.opacity, model.ctx.animation_time);
	model.layer:relayout();
end

local function model_split_shader(model)
	if (not model.custom_shaders) then
		model.custom_shaders = {
			shader_ugroup(model.shader.normal),
			shader_ugroup(model.shader.flip)
		};
		model.shader.normal = model.custom_shaders[1];
		model.shader.flip = model.custom_shaders[2];
		image_shader(model.vid, model.custom_shaders[model.flip and 2 or 1]);
	end
end

local function model_stereo(model, args)
	if (#args ~= 8) then
		return;
	end

	model_split_shader(model);

	for i,v in ipairs(model.custom_shaders) do
		shader_uniform(v, "ofs_leye", "ff", args[1], args[2]);
		shader_uniform(v, "scale_leye", "ff", args[3], args[4]);
		shader_uniform(v, "ofs_reye", "ff", args[5], args[6]);
		shader_uniform(v, "scale_reye", "ff", args[7], args[8]);
	end
end

local function model_curvature(model, curv)
	model_split_shader(model);
	for i,v in ipairs(model.custom_shaders) do
		shader_uniform(v, "curve", "f", 0.0);
	end
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

-- same as the terminal spawn setup, just tag the kind so that we can
-- deal with the behavior response in ext_kind
local function model_connpoint(model, name, kind)
	local cp = target_alloc(name,
	function(source, status)
		if (status.kind == "connected") then
			target_updatehandler(source, function(...)
				return modelconn_eventhandler(model.layer, model, ...);
			end);
		elseif (status.kind == "terminated") then
			delete_image(source);
		end
	end);

	if (not valid_vid(cp)) then
		return;
	end

	link_image(cp, model.vid);
	model.ext_kind = kind;

-- special behavior: on termination, just set inactive and relaunch
	if (kind == "reveal") then
		model.ext_name = name;
		model.active = false;
		model.layer:relayout();

	elseif (kind == "temporary") then
		model.ext_name = name;
	end
end

local function build_model(layer, kind, name)
	local model;
	local depth = layer.depth;
	local h_depth = depth * 0.5;
	local shader = vrshaders.geom;
	local shader_inv = vrshaders.geom_inv;
	local size = {depth, depth, depth};

	if (kind == "cylinder") then
		model = build_cylinder(h_depth, depth, 360, 1);
	elseif (kind == "halfcylinder") then
		model = build_cylinder(h_depth, depth, 360, 1, "half");
	elseif (kind == "sphere") then
		model = build_sphere(h_depth, 360, 360, 1, false);
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

	local res = {
		active = true,
		vid = model,
		name = name,
		ctx = layer.ctx,
		extctr = 0, -- external windows spawned via this model
		parent = nil,
		children = {},

-- method vtable
		destroy = model_destroy,
		set_external = model_external,
		select = model_select,
		scale = model_scale,
		show = model_show,
		set_parent = model_reparent,
		get_size = model_getsize,
		mergecollapse = model_mergecollapse,
		set_connpoint = model_connpoint,
		set_stereo = model_stereo,
		set_curvature = model_curvature,

-- positioning / sizing, drawing
		shader = {normal = shader, flip = shader_inv},
		opacity = 1.0,
		size = size,
		scalev = {1, 1, 1},
		old_scalev = {1, 1, 1},
		scale_factor = 1.0,
		layer_ang = 0,
		layer_pos = {0, 0, 0},
		rel_ang = {0, 0, 0},
		rel_pos = {0, 0, 0},
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
	for i,v in ipairs(ctx.layers) do
		v:relayout();
	end
end

local function layer_zpos(layer)
	return layer.dz;
end

local function layer_add_model(layer, kind, name)
	for k,v in ipairs(layer.models) do
		if (v.name == name) then
			return;
		end
	end

	local model = build_model(layer, kind, name);
	if (not model) then
		return;
	end

	if (layer.models[1] and layer.models[1].active == false) then
		table.insert(layer.models, 1, model);
	else
		table.insert(layer.models, model);
	end
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
		if (not apply_connrole(model.layer, model, source)) then
			model:destroy(EXIT_FAILURE, status.last_words);
		end

	elseif (status.kind == "registered") then
		model:set_external(source);

	elseif (status.kind == "resized") then
		image_texfilter(source, FILTER_BILINEAR);
		model:set_external(source, status.origo_ll);
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
	browser = model_eventhandler,

-- handlers to types that we don't accept as primary now
	["bridge-wayland"] = nil,
	clipboard = nil, -- no clipboard managers
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

modelconn_eventhandler = function(layer, model, source, status)
	if (status.kind == "registered") then
-- based on segment type, install a new event-handler and tie to a new model
		local dstfun = clut[status.segkind];
		if (dstfun == nil) then
			delete_image(source);
			return;

-- there is an external connection handler that takes over whatever this model was doing
		elseif (model.ext_kind) then
			target_updatehandler(source, function(source, status)
				return dstfun(layer.ctx, model, source, status);
			end);
			model.external_old = model.external;
			model.external = source;

-- or it should be bound to a new model
		else
			local new_model =
				layer:add_model("rectangle", model.name .. "_ext_" .. tostring(model.extctr));

			target_updatehandler(source, function(source, status)
				return dstfun(layer.ctx, new_model, source, status);
			end);
			dstfun(layer.ctx, new_model, source, status);

-- reparent so that we start building this chain of clients vertically, but
-- invert so that the new window takes precedence over the old one
			if (model.parent) then
				new_model:set_parent(model.parent);
			else
				model:set_parent(new_model);
			end
		end
	elseif (status.kind == "resized") then
		model:show();
	elseif (status.kind == "terminated") then
-- connection point died, should we bother allocating a new one?
		delete_image(source);
		if not (apply_connrole(model.layer, model, source)) then
			model:destroy(EXIT_FAILURE, status.last_words);
		end
	end
end

local term_counter = 0;
local function layer_add_terminal(layer, opts)
	opts = opts and opts or "";
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
	local vid = launch_avfeed("env=ARCAN_CONNPATH="..cp..":"..opts, "terminal",
	function(...)
		return terminal_eventhandler(layer.ctx, model, ...);
	end
	);

	if (not valid_vid(vid)) then
		model:destroy();
		return;
	end

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
end

local function layer_set_fixed(layer, fixed)
	layer.fixed = fixed;
	reindex_layers(layer.ctx);
end

-- these functions are partially dependent on the layout scheme
local function layer_swap(layer, left, count)
	count = count and count or 1;

	if (count < 1) then
		return;
	end

-- swap with index[1], BUT only select if it can receive input and is active
	local set = {};

-- just grab the root nodes
	for i,v in ipairs(layer.models) do
		if (not v.parent) then
			table.insert(set, {i, v});
		end
	end

-- find the matching relative index using count
	local sc = #set;
	if (sc == 1) then
		return;
	end

-- make sure that the starting search index is active
	local ind = (left and 2) or 3;
	while (set[ind] and not set[ind][2].active) do
		ind = ind + 2;
	end

	while (count > 2 and set[ind]) do
		ind = ind + 2;
		if (set[ind][2].active) then
			count = count - 1;
		end
	end

	if (not set[ind]) then
		return;
	end

	local focus = layer.models[1];
	local new = set[ind][2];
	layer.models[set[ind][1]] = focus;
	layer.models[1] = new;

-- offset the old focus point slightly so their animation path doesn't collide
	if (focus.layer_pos) then
		move3d_model(focus.vid, focus.layer_pos[1],
			focus.layer_pos[2], focus.layer_pos[3] + 0.1, 0.5 * layer.ctx.animation_speed);
	end

-- only the focus- window gets to run a >1 scale
	new:scale();
	focus:scale();
	new:select();

	layer:relayout();
end

-- same as _swap, but more movement and more directions
local function layer_cycle(layer, left, step)
end

local function layer_destroy(layer)

	for i,v in ipairs(layer.ctx.layers) do
		if (v == layer) then
			table.remove(layer.ctx.layers, i);
			break;
		end
	end
	if (layer.ctx.selected_layer == layer) then
		layer.ctx.selected_layer = layer.ctx.layers[1];
	end

-- rest will cascade
	delete_image(layer.anchor);

	for k,v in pairs(layer) do
		layer[k] = nil;
	end
end

local function layer_add(ctx, tag)
	for k,v in ipairs(ctx.layers) do
		if (v.name == tag) then
			return;
		end
	end

	local layer = {
		ctx = ctx,
		anchor = null_surface(1, 1),
		models = {},

		add_model = layer_add_model,
		add_terminal = layer_add_terminal,

		swap = layer_swap,
		cycle = layer_cycle,

		step = layer_step,
		zpos = layer_zpos,
		set_fixed = layer_set_fixed,
		select = layer_select,
		relayout = function(...)
			return ctx.default_layouter(...);
		end,
		destroy = layer_destroy,

		name = tag,

		dx = 0, dy = 0, dz = 0,
		radius = 0.5,
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

	local prefix = opts.prefix and opts.prefix or "";

-- actual vtable and properties
	ctx.default_layouter = system_load(prefix .. "/layouters/default.lua")();
	ctx.add_layer = layer_add;
	ctx.camera = cam;
	ctx.placeholder = placeholder;
	ctx.vr_pipe = surf;
	ctx.setup_vr = setup_vr_display;
	ctx.reindex_layers = reindex_layer;
	ctx.input_table = vr_input;
	ctx.message = function(ctx, msg) print(msg); end;

-- special case, always take the left eye view on stereoscopic sources,
-- the real stereo pipe takes the right approach of course
	rendertarget_id(surf, 0);

-- all UI is arranged into layers of models
	ctx.layers = {};
end

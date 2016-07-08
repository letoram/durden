--
-- Quick and dirty model viewing support.
-- The format used here is rather nasty, and merely kept
-- as a legacy curiosity until something more standardized
-- will be integrated around 0.7
--
-- use durden_modelwnd(name) to grab/load a model, map controls,
-- event handlers etc.
--
-- use durden_model_list() to get an enumeration of existing models
--
local display = build_shader(
[[
uniform mat4 modelview;
uniform mat4 projection;

attribute vec4 vertex;
attribute vec2 texcoord;

varying vec2 txco;

void main(){
	txco = texcoord;
	txco.t = 1.0 - txco.t;
	gl_Position = (projection * modelview) * vertex;
}]],
[[
uniform sampler2D map_diffuse;
varying vec2 txco;

void main() {
	vec4 txcol = texture2D(map_diffuse, txco);
	gl_FragColor = txcol;
}
]], "3d_display");

local dir_light = build_shader(
-- vertex
[[
uniform mat4 modelview;
uniform mat4 projection;
uniform vec3 wlightdir;

attribute vec4 vertex;
attribute vec3 normal;
attribute vec2 texcoord;

varying vec3 lightdir;
varying vec2 txco;
varying vec3 fnormal;

void main(){
	fnormal = vec3(modelview * vec4(normal, 0.0));
	lightdir = normalize(wlightdir);

	txco = texcoord;
	gl_Position = (projection * modelview) * vertex;
}
]],
-- fragment
[[
uniform vec3 wdiffuse;
uniform vec3 wambient;
uniform sampler2D map_diffuse;

varying vec3 lightdir;
varying vec3 fnormal;
varying vec2 txco;

void main() {
	vec4 color = vec4(wambient,1.0);
	vec4 txcol = texture2D(map_diffuse, txco);

	float ndl = max( dot(fnormal, lightdir), 0.0);
	if (ndl > 0.0){
		txcol += vec4(wdiffuse * ndl, 0.0);
	}

	gl_FragColor = txcol * color;
}
]], "dir_light");

local fullbright = build_shader(nil,
[[
uniform sampler2D map_diffuse;
varying vec2 texco;

void main() {
	vec4 txcol = texture2D(map_diffuse, texco);
	gl_FragColor = txcol;
}
]], "fullbright");

shader_uniform(dir_light, "map_diffuse", "i", PERSIST, 0);
shader_uniform(dir_light, "wlightdir", "fff", PERSIST, 1, 0, 0);
shader_uniform(dir_light, "wambient",  "fff", PERSIST, 0.3, 0.3, 0.3);
shader_uniform(dir_light, "wdiffuse",  "fff", PERSIST, 0.6, 0.6, 0.6);

local shlut = {
	marquee = fullbright,
	coinlights = fullbright,
	snapshot = fullbright
};

-- slightly more ambitious would be to calc. wlightdir
-- based on geo-position :-)

local function material_loaded(source, statustbl)
	if (statustbl.kind == "load_failed") then
		warning("Material load failed on resource ( "
			.. tostring(statustbl.resource) .. " )\n");
	end
end

local function model_list()
	local lst = glob_resource("models/*");
	local res = {};

	for i,v in ipairs(lst) do
		local r, t = resource("models/" .. v);
		if (t == "directory") then
			table.insert(res, v);
		end
	end

	return res;
end

local function find_material(modelname, meshname)
	local fnameb = string.format("models/%s/textures/%s", modelname, meshname);

	if (resource(fnameb .. ".png")) then
		return fnameb .. ".png";
	elseif (resource(fnameb .. ".jpg")) then
		return fnameb .. ".jpg";
	end

	return nil;
end

-- could possible be used to map additional maps (bump, specular, ...)
local function setup_material(model, modelname, meshname, synth)
	local mat = find_material(modelname, meshname);
	local col = (synth and synth[meshname]) and
		synth[meshname].col or {64, 64 + math.random(64), 64 + math.random(64)};
	local vid = fill_surface(8, 8, col[1], col[2], col[3]);
	set_image_as_frame(model.vid, vid, model.pslot);
	delete_image(vid);

	if (mat) then
		local slot = model.pslot;
		load_image_asynch(mat, function(source, status)
			if (status.kind == "loaded") then
				set_image_as_frame(model.vid, source, slot);
			end
			delete_image(source);
		end);
	end

	model.pslot = model.pslot + 1;
end

-- sort submeshes so that those assumed having alpha gets drawn last
local function sort_meshes(a, b)
	if (a[1] == "bezel" and b[1] ~= "bezel") then
		return false;
	elseif (b[1] == "bezel" and a[1] ~= "bezel") then
		return true;
	else
		return a[1] < b[1]
	end
end

local function get_valid_windows(cwin, model)
	local lst = {};
	for wnd in all_windows() do
		if (valid_vid(wnd.external)) then
			table.insert(lst, {
				kind = "action",
				name = "map_" .. wnd.name,
				label = wnd.title_text and wnd.title_text or wnd.name,
				handler = function()
					mesh_shader(model.vid, display, model.display_mesh);
					set_image_as_frame(model.vid, wnd.external, model.display_slot);
					cwin.menu_input_disable = false;
					cwin.menu_state_disable = false;
					cwin.external = wnd.external;
					cwin.external_prot = true;
				end
			});
		end
	end
	return lst;
end

function load_model_generic(modelname, ignore, synthtbl)
	local basep = "models/" .. modelname .. "/";
	local meshes = glob_resource(basep .. "*.ctm");

	if (not meshes or #meshes == 0) then
		return;
	end

	local model = {
		labels = {}, images = {}
	};

-- build an empty container, populate it with valid submeshes
-- and load corresponding textures
	model.vid = new_3dmodel();
	image_tracetag(model.vid, "3dmodel(" .. modelname ..")");
	if (not valid_vid(model.vid)) then
		return;
	end

-- most textures / models are defined with lower-left Y
	image_framesetsize(model.vid, #meshes + 1);
	model.setsz = #meshes + 1;
	model.pslot = 0;
	switch_default_imageproc(IMAGEPROC_FLIPH);

-- sort on alpha and build list of meshes
	local seqlist = {};
	for i=1, #meshes do
		local ent = {};
		ent[1] = string.sub(meshes[i], 1, -5);
		ent[2] = meshes[i];
		table.insert(seqlist, ent);
	end
	table.sort(seqlist, sort_meshes);

-- generate viewing coordinates and orientation fixup
	model.screenview = {};
	model.default_orientation = {roll = 0, pitch = 0, yaw = 0};
	model.screenview.position = {x = 0, y = 0.5, z = 1.0};
	model.screenview.orientation = {roll = 0, pitch = 0, yaw = 0};

-- load and add to container
	for i,v in ipairs(seqlist) do
		local meshname = v[1];
		local vid = BADID;

		add_3dmesh(model.vid, basep ..v[2], 1);
		model.labels[meshname] = slot;
		mesh_shader(model.vid, shlut[meshname] and shlut[meshname] or dir_light, i-1);

-- 'display' is a reserved name for where we'll map an external image
		if (meshname ~= "display") then
			setup_material(model, modelname, meshname, synthtbl);
		else
			local black = fill_surface(8, 8, 0, 0, 0);
			set_image_as_frame(model.vid, black, model.pslot);
			delete_image(black);
			model.display_slot = model.pslot;
			model.display_mesh = i-1;
			model.pslot = model.pslot + 1;
		end
	end

	switch_default_imageproc(IMAGEPROC_NORMAL);
	return model;
end

local function load_model(modelname)
-- hack around legacy models, to protect against orient3d calls that fight
-- with the ones we perform further down
	local orient3d = orient3d_model;
	local oriented = nil;
	orient3d_model = function(vid, r, p, y)
		oriented = {roll = r, pitch = p, yaw = y};
	end

	local rv = nil;

-- script- specified loader or generic?
	if (resource("models/" .. modelname .. "/" .. modelname .. ".lua")) then
		rv = system_load("models/" .. modelname .. "/" .. modelname .. ".lua")();
	else
		rv = load_model_generic(modelname);
		if (rv ~= nil) then
			rv.format_version = 0.1;
		end
	end

	if (not rv) then
		return;
	end

	orient3d_model = orient3d;

	scale_3dvertices(rv.vid);
-- add some helper functions, view angles etc. are specified
-- absolute rather than relative to the base, so we have to translate
	local o = rv.default_orientation;

-- only re-orient if the default orientation deviates over a certain
-- threshold as the orient3d_ call may reduce precision
	if (o.roll > 0.0001 or o.roll < -0.0001 or
		o.pitch > 0.0001 or o.pitch < -0.0001 or
		o.yaw > 0.0001 or o.yaw < -0.0001) then
		orient3d_model(rv.vid,
			rv.default_orientation.roll,
			rv.default_orientation.pitch,
			rv.default_orientation.yaw
		);
	end

	if (rv.format_version == nil) then
		rv.screenview.orientation.roll  =
			rv.screenview.orientation.roll - rv.default_orientation.roll;

		rv.screenview.orientation.pitch =
			rv.screenview.orientation.pitch - rv.default_orientation.pitch;

		rv.screenview.orientation.yaw =
			rv.screenview.orientation.yaw - rv.default_orientation.yaw;
	end

	finalize_3dmodel(rv.vid);
	return rv;
end

local function set_pos(model, res)
	local p = {};
	local o = {};

	if (res) then
		if (res.position and type(res.position) == "table") then
			p = res.position;
		end
		if (res.orientation and type(res.orientation) == "table") then
			o = res.orientation;
		end
	end

	local x = -1 * (p.x and p.x or 0.0);
	local y = -1 * (p.y and p.y or 0.2);
	local z = -1 * (p.z and p.z or 2.0);
	local roll = o.roll and o.roll or 0;
	local pitch = o.pitch and o.pitch or 0;
	local yaw = o.yaw and o.yaw or 0;
	move3d_model(model.vid, x, y, z, 20);
	rotate3d_model(model.vid, roll, pitch, yaw, 20, ROTATE_ABSOLUTE);
end

local function modelwnd(name)
	local res = load_model(name);
	if (not res or not valid_vid(res.vid)) then
		return;
	end

	local cam = null_surface(1, 1);
	scale3d_model(cam, 1.0, -1.0, 1.0);

-- setup a rendetarget for this model alone
	local tgtsurf = alloc_surface(VRESW, VRESH);
	define_rendertarget(tgtsurf, {cam, res.vid}, RENDERTARGET_DETACH,
		RENDERTARGET_NOSCALE, -1, RENDERTARGET_FULL);
	move3d_model(res.vid, 0.0, -0.2, -2.0);
	camtag_model(cam, 0.01, 100.0, 45.0, 1.33);
	show_image(res.vid);
	show_image(cam);

-- and bind to a new window
	local wnd = active_display():add_window(tgtsurf, {scalemode = "stretch"});
	wnd.bindings = {
	TAB = function() wnd.model_move = not wnd.model_move; end
	};
	wnd.clipboard_block = true;
	wnd:set_title(string.format("model(%s)", name));
	wnd:add_handler("resize", function(ctx, w, h)
		if (not ctx.in_drag_rz) then
			image_resize_storage(tgtsurf, w, h);
			rendertarget_forceupdate(tgtsurf);
		end
		resize_image(tgtsurf, w, h);
	end);

-- modify mouse handlers and re-register
	wnd.handlers.mouse.canvas.drag = function(ctx, vid, dx, dy)
		if (wnd.model_move) then
			local props = image_surface_properties(res.vid);
			move3d_model(res.vid, props.x + dx * -0.01, props.y, props.z + dy * -0.01);
		else
			rotate3d_model(res.vid, 0, dy, dx, 0, ROTATE_RELATIVE);
		end
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
		eval = function() return res.display_slot ~= nil and
			#get_valid_windows(wnd, res); end,
		handler = function() return get_valid_windows(wnd, res); end
	},
	{
		name = "view",
		label = "View",
		kind = "action",
		eval = function() return res.screenview ~= nil; end,
		handler = function(wnd)
			if (wnd.in_view) then
				wnd.in_view = nil;
				set_pos(res);
			else
				wnd.in_view = true;
				set_pos(res, res.screenview);
			end
		end
	},
	};
-- missing - player stepping on tick, toggle view- position
	return wnd;
end

global_menu_register("open",
{
	name = "model",
	label = "Model",
	submenu = true,
	kind = "value",
	set = function()
		return model_list()
	end,
	eval = function()
		return #model_list() > 0;
	end,
	handler = function(ctx, val)
		modelwnd(val);
	end
});

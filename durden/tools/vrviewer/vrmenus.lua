local function add_model_menu(wnd, layer)

-- deal with the 180/360 transition shader-wise
	local lst = {
		pointcloud = "Point Cloud",
		sphere = "Sphere",
		hemisphere = "Hemisphere",
		rectangle = "Rectangle",
		cylinder = "Cylinder",
		halfcylinder = "Half-Cylinder",
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
			layer:add_model(k, val);
			layer:relayout();
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
		description = "Set the default layer thickness",
		kind = "value",
		hint = "(0.001..99)",
		initial = tostring(layer.depth),
		validator = gen_valid_num(0.001, 99.0),
		handler = function(ctx, val)
			layer.depth = tonumber(val);
		end
	},
	{
		name = "radius",
		label = "Radius",
		description = "Set the layouting radius",
		kind = "value",
		hint = "(0.001..99)",
		initial = tostring(layer.radius),
		validator = gen_valid_num(0.001, 99.0),
		handler = function(ctx, val)
			layer.radius = tonumber(val);
			layer:relayout();
		end
	},
	{
		name = "fixed",
		label = "Fixed",
		initial = layer.fixed and "true" or "false",
		set = {"true", "false"},
		kind = "value",
		description = "Lock the layer in place",
		handler = function(ctx, val)
			layer:set_fixed(val == "true");
		end
	},
	{
		name = "ignore",
		label = "Ignore",
		description = "This layer will not be considered for relative selection",
		set = {"true", "false"},
		kind = "value",
		handler = function(ctx, val)
			layer.ignore = val == "true";
		end
	},
	};
end

local function set_source_asynch(wnd, layer, model, source, status)
	if (status.kind == "load_failed" or status.kind == "terminated") then
		blend_image(model.vid, model.opacity, model.ctx.animation_speed);
		delete_image(source);
		return;
	elseif (status.kind == "loaded") then
		blend_image(model.vid, model.opacity, model.ctx.animation_speed);
		image_sharestorage(source, model.vid);
		image_texfilter(source, FILTER_BILINEAR);
		model.source = source;
	end
end

local function build_connpoint(wnd, layer, model)
	return {
		{
			name = "replace",
			label = "Replace",
			kind = "value",
			description = "Replace model source with contents provided by an external connection",
			validator = function(val) return val and string.len(val) > 0; end,
			hint = "(connpoint name)",
			handler = function(ctx, val)
				model:set_connpoint(val, "replace");
			end
		},
		{
			name = "temporary",
			label = "Temporary",
			kind = "value",
			hint = "(connpoint name)",
			description = "Swap out model source whenever there is a connection active",
			validator = function(val) return val and string.len(val) > 0; end,
			handler = function(ctx, val)
				model:set_connpoint(val, "temporary");
			end
		},
		{
			name = "reveal",
			label = "Reveal",
			kind = "value",
			hint = "(connpoint name)",
			description = "Model is only visible when there is a connection active",
			validator = function(val) return val and string.len(val) > 0; end,
			handler = function(ctx, val)
				model:set_connpoint(val, "reveal");
			end
		}
	};
end

local function model_settings_menu(wnd, layer, model)
	local res = {
	{
		name = "source",
		label = "Source",
		kind = "value",
		description = "Specify the path to a resource that should be mapped to the model",
		validator =
		function(str)
			return str and string.len(str) > 0;
		end,
		handler = function(ctx, res)
			if (not resource(res)) then
				return;
			end
			switch_default_imageproc(IMAGEPROC_FLIPH);
			local vid = load_image_asynch(res,
				function(...)
					set_source_asynch(wnd, layer, model, ...);
				end
			);
			switch_default_imageproc(IMAGEPROC_NORMAL);

-- link so life cycle matches model
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
			model:destroy();
		end
	},
	{
		name = "browse",
		label = "Browse",
		description = "Browse for a source image or video to map to the model",
		kind = "action",

-- eval so that we can present it in WMs that have it
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
		name = "rotate",
		label = "Rotate",
		description = "Set the current model-layer relative rotation",
		kind = "value",
		validator = suppl_valid_typestr("fff", -359, 359, 0),
		handler = function(ctx, val)
			local res = suppl_unpack_typestr("fff", -359, 359);
			model.rel_ang[1] = res[1];
			model.rel_ang[2] = res[2];
			model.rel_ang[3] = res[3];
		end,
	},
	{
		name = "flip",
		label = "Flip",
		description = "Force- override t-coordinate space (vertical flip)",
		kind = "value",
		set = {"true", "false"},
		handler = function(ctx, val)
			if (val == "true") then
				model.force_flip = true;
			else
				model.force_flip = false;
			end
			image_shader(model.vid,
				model.force_flip and model.shader.flip or model.shader.normal);
		end
	},
	{
		name = "spin",
		label = "Spin",
		description = "Increment or decrement the current model-layer relative rotation",
		kind = "value",
		validator = suppl_valid_typestr("fff", -359, 359, 0),
		handler = function(ctx, val)
			local res = suppl_unpack_typestr("fff", -359, 359);
			model.rel_ang[1] = math.fmod(model.rel_ang[1] + res[1], 360);
			model.rel_ang[2] = math.fmod(model.rel_ang[2] + res[2], 360);
			model.rel_ang[3] = math.fmod(model.rel_ang[3] + res[3], 360);
		end,
	},
	{
		name = "map",
		label = "Map",
		description = "Map the contents of another window to the model",
		kind = "value",
		set = function()
			local lst = {};
			for wnd in all_windows(nil, true) do
				table.insert(lst, wnd:identstr());
			end
			return lst;
		end,
		eval = function()
			if (type(durden) ~= "function") then
				return false;
			end
			for wnd in all_windows(nil, true) do
				return true;
			end
		end,
		handler = function(ctx, val)
			for wnd in all_windows(nil, true) do
				if wnd:identstr() == val then
					model.external = wnd.external;
					image_sharestorage(wnd.canvas, model.vid);
					model:show();
					return;
				end
			end
		end
	},
	{
		name = "connpoint",
		label = "Connection Point",
		description = "Allow external clients to connect and map to this model",
		submenu = true,
		kind = "action",
		handler = function()
			return build_connpoint(wnd, layer, model);
		end
	},
	{
		name = "curvature",
		label = "Curvature",
		kind = "value",
		description = "Set the model curvature z- distortion",
		handler = function(ctx, val)
			model:set_curvature(tonumber(val));
		end,
		validator = gen_valid_num(-0.5, 0.5),
	},
	{
		name = "stereoscopic",
		label = "Stereoscopic Model",
		description = "Mark the contents as stereoscopic and apply a view dependent mapping",
		kind = "value",
		set = {"none", "sbs", "sbs-rl", "oau", "oau-rl"},

		handler = function(ctx, val)
			if (val == "none") then
				model:set_stereo({
					0.0, 0.0, 1.0, 1.0,
					0.0, 0.0, 1.0, 1.0
				});
			elseif (val == "sbs") then
				model:set_stereo({
					0.0, 0.0, 0.5, 1.0,
					0.5, 0.0, 0.5, 1.0
				});
			elseif (val == "sbs-rl") then
				model:set_stereo({
					0.5, 0.0, 0.5, 1.0,
					0.0, 0.0, 0.5, 1.0
				});
			elseif (val == "oau") then
				model:set_stereo({
					0.0, 0.0, 1.0, 0.5,
					0.0, 0.5, 1.0, 0.5
				});
			elseif (val == "oau-rl") then
				model:set_stereo({
					0.0, 0.5, 1.0, 0.5,
					0.0, 0.0, 1.0, 0.5
				});
			end
		end
	},
	};
-- stereo, source, external connection point
	return res;
end

local function change_model_menu(wnd, layer)
	local res = {
	{
		name = "selected",
		kind = "action",
		submenu = true,
		label = "Selected",
		handler = function()
			return model_settings_menu(wnd, layer, layer.selected);
		end,
		eval = function()
			return layer.selected ~= nil;
		end
	}
	};

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

local term_counter = 0;
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
			kind = "value",
			name = "terminal",
			handler = function(ctx, val)
				layer:add_terminal(val);
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
			eval = function()
				return #layer.models > 1;
			end,
			kind = "value",
			validator = function(val)
				return (
					gen_valid_num(-1*(#layer.models),1*(#layer.models))
				)(val);
			end,
			hint = "(< 0: left, >0: right)",
			description = "Switch center/focus window with one to the left or right",
			handler = function(ctx, val)
				val = tonumber(val);
				if (val < 0) then
					layer:swap(true, -1*val);
				elseif (val > 0) then
					layer:swap(false, val);
				end
			end
		},
		{
			name = "destroy",
			label = "Destroy",
			description = "Destroy the layer and all associated models and connections",
			kind = "value",
			set = {"true", "false"},
			handler = function(ctx, val)
				if (val == "true") then
					layer:destroy();
				end
			end
		},
		{
			name = "switch",
			label = "Switch",
			description = "Switch layer position with another layer",
			kind = "value",
			set = function()
				local lst = {};
				local i;
				for j, v in ipairs(wnd.layers) do
					if (v.name ~= layer.name) then
						table.insert(lst, v.name);
					end
				end
				return lst;
			end,
			eval = function() return #wnd.layers > 1; end,
			handler = function(ctx, val)
				local me;
				for me, v in ipairs(wnd.layers) do
					if (v == layer.name) then
						break;
					end
				end

				local src;
				for src, v in ipairs(wnd.layers) do
					if (v.name == val) then
						break;
					end
				end

				wnd.layers[me] = wnd.layers[src];
				wnd.layers[src] = layer;
				wnd:reindex_layers();
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
				blend_image(layer.anchor, 0.0, wnd.animation_speed);
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
				blend_image(layer.anchor, layer.opacity, wnd.animation_speed);
			end,
		},
		{
			name = "focus",
			label = "Focus",
			description = "Set this layer as the active focus layer",
			kind = "action",
			eval = function()
				return #wnd.layers > 1 and wnd.selected_layer ~= layer;
			end,
			handler = function()
				wnd.selected_layer = layer;
			end,
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
				move3d_model(layer.anchor, layer.dx, layer.dy, layer:zpos(), res[4]);
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
	local res = {
	};

	if (wnd.selected_layer) then
		table.insert(res, {
			name = "current",
			submenu = true,
			kind = "action",
			description = "Currently focused layer",
			eval = function() return wnd.selected_layer ~= nil; end,
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
					move3d_model(v.anchor, v.dx, v.dy, layer:zpos(), wnd.animation_speed);
				end
			end
		});
	end

	table.insert(res, {
	label = "Add",
	description = "Add a new model layer";
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
		wnd:add_layer(val);
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


local function load_space(wnd, prefix, path)
	local lst = system_load(prefix .. "spaces/" .. path, false);
	if (not lst) then
		warning("vr-load space (" .. path .. ") couldn't load/parse script");
		return;
	end
	local cmds = lst();
	if (not type(cmds) == "table") then
		warning("vr-load space (" .. path .. ") script did not return a table");
	end

-- defer layouter until all has been loaded
	local dispatch = wnd.default_layouter;
	wnd.default_layouter = function() end;
	for i,v in ipairs(cmds) do
		dispatch_symbol("#" .. v);
	end

	wnd.default_layouter = dispatch;
	for _,v in ipairs(wnd.layers) do
		v:relayout();
	end
end

local function hmd_config(wnd, opts)
	return {
	{
	name = "reset",
	label = "Reset Orientation",
	description = "Set the current orientation as the new base reference",
	kind = "action",
	handler = function()
		active_display():message("sent reset event");
		reset_target(wnd.vr_state.vid);
	end
	}};
end


local function global_settings(wnd, opts)
	return {
	{
		name = "vr_settings",
		kind = "value",
		label = "VR Bridge Config",
		description = "Set the arguments that will be passed to the VR device",
		handler = function(ctx, val)
			wnd.hmd_arg = val;
		end
	}
	};
end

return
function(wnd, opts)
	system_load(
		(opts.prefix and opts.prefix or "") .. "vrsetup.lua")(ctx, opts);

local res = {{
	name = "close_vr",
	description = "Terminate the current VR session and release the display",
	kind = "action",
	label = "Close VR",
	eval = function()
		return wnd.in_vr ~= nil and type(durden) == "function";
	end,
	handler = function()
		wnd:drop_vr();
	end
},
{
	name = "settings",
	submenu = true,
	kind = "action",
	description = "Layer/device configuration",
	label = "Config",
	eval = function() return type(durden) == "function"; end,
	handler = function(ctx)
		return global_settings(wnd, opts);
	end
},
{
	name = "layers",
	kind = "action",
	submenu = true,
	label = "Layers",
	description = "Model layers for controlling models and data sources",
	handler = function()
		return layer_menu(wnd, opts);
	end
},
{
	name = "space",
	label = "Space",
	kind = "value",
	set =
	function()
		local set = glob_resource(opts.prefix .. "spaces/*.lua", APPL_RESOURCE);
		return set;
	end,
	eval = function()
		local set = glob_resource(opts.prefix .. "spaces/*.lua", APPL_RESOURCE);
		return set and #set > 0;
	end,
	handler = function(ctx, val)
		load_space(wnd, opts.prefix, val);
	end,
},
{
	name = "hmdconfig",
	label = "HMD Configuration",
	kind = "action",
	submenu = true,
	eval = function()
		return wnd.vr_state ~= nil;
	end,
	handler = function() return hmd_config(wnd, opts); end
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
		return res and type(durden) == "function";
	end,
	handler = function(ctx, val)
		wnd:setup_vr(wnd, val);
	end
}};
	return res;
end

--
-- UI / menu mapping
--

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
			layer:add_model(k, val)
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
			layer:set_fixed(val == LBL_YES);
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
		blend_image(model.vid, model.opacity, model.ctx.animation_speed);
		delete_image(source);
		return;
	elseif (status.kind == "loaded") then
		blend_image(model.vid, model.opacity, model.ctx.animation_speed);
		image_sharestorage(source, model.vid);
		image_texfilter(source, FILTER_BILINEAR);
	end
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
		name = "map",
		label = "Map",
		description = "Map the contents of another window to the model",
		kind = "value",
		set = function()
			local lst = {};
			for wnd in all_windows() do
				if (valid_vid(wnd.external)) then
					table.insert(lst, wnd:identstr());
				end
			end
			return lst;
		end,
		eval = function()
			for wnd in all_windows() do
				if (valid_vid(wnd.external)) then
					return true;
				end
			end
		end,
		handler = function(ctx, val)
			for wnd in all_windows() do
				if wnd:identstr() == val then
					model.external = wnd.external;
					image_sharestorage(wnd.canvas, model.vid);
					return;
				end
			end
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
			kind = "action",
			name = "terminal",
			handler = function()
				layer:add_terminal();
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
	local res = {
	};

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


local function load_presets(wnd, prefix, path)
	local lst = system_load(prefix .. "presets/" .. path, false);
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
	name = "near_size",
	label = "Near Size",
	description = "Reported display base size for nearest layer",
	kind = "value";
	initial = function() return tostring(opts.near_layer_sz); end,
	validator = gen_valid_num(256, 4096),
	handler = function(ctx, val)
		wnd.near_layer_sz = tonumber(val);
	end
	},
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
		return wnd.in_vr ~= nil;
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
	name = "preset",
	label = "Preset",
	kind = "value",
	set =
	function()
		local set = glob_resource(opts.prefix .. "presets/*.lua", APPL_RESOURCE);
		return set;
	end,
	eval = function()
		local set = glob_resource(opts.prefix .. "presets/*.lua", APPL_RESOURCE);
		return set and #set > 0;
	end,
	handler = function(ctx, val)
		load_presets(wnd, opts.prefix, val);
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
		return res;
	end,
	handler = function(ctx, val)
		setup_vr_display(wnd, val);
	end
}};
	return res;
end

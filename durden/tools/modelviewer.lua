--
-- Rework of old modelviewer,
--
-- First to just support basic meshes so that a stereo output would present
-- with the correct sampled surface and the right distance between two cameras
-- (setup linktarget and nudge camera to match distance).
--

local h_depth = 0.05
local depth = 0.1
local subdiv_factor = {1.0, 0.4}

local function wnd_to_model(cwin, model, wnd)
	mesh_shader(model.vid, display, model.display_mesh);
	set_image_as_frame(model.vid, wnd.canvas, model.display_slot);
	cwin.menu_input_disable = false;
	cwin.menu_state_disable = false;
	cwin.external = wnd.external;
	cwin.external_prot = true;
end

local function get_valid_windows(cwin, model)
	local lst = {};
	for wnd in all_windows() do
		if (valid_vid(wnd.external)) then
			table.insert(lst, {
				kind = "action",
				name = "map_" .. wnd.name,
				label = wnd:identstr(),
				handler = function()
					wnd_to_model(cwin, model, wnd);
				end
			});
		end
	end
	return lst;
end

local function modelwnd(mesh)
	local cam = null_surface(1, 1)
	scale3d_model(cam, 1.0, -1.0, 1.0)

-- setup a rendetarget for this model alone
	local tgtsurf = alloc_surface(VRESW, VRESH);
	define_rendertarget(tgtsurf,
		{cam, mesh}, RENDERTARGET_DETACH, RENDERTARGET_NOSCALE, -1, RENDERTARGET_FULL)

-- the camera controls for near/far/fov/AR should reflect any stereo display
	move3d_model(mesh, 0.0, -0.2, -2.0)
	camtag_model(cam, 0.01, 100.0, 45.0, 1.33)
	show_image({cam, mesh})

-- and bind to a new window
	local wnd = active_display():add_window(tgtsurf, {scalemode = "stretch"})
	wnd.bindings = {}

	wnd:set_title(string.format("model(%s)", name))

-- rebuild the rendertarget and draw a frame on each resize
	wnd:add_handler("resize",
		function(ctx, w, h)
			if (not ctx.in_drag_rz) then
				image_resize_storage(tgtsurf, w, h)
				rendertarget_forceupdate(tgtsurf)
			end
			resize_image(tgtsurf, w, h)
		end
	)

-- change canvas drag to pan or rotate
	local old_dragh = wnd.handlers.mouse.canvas.drag

	wnd.handlers.mouse.canvas.drag =
	function(ctx, vid, dx, dy)
		if (old_dragh(ctx, vid, dx, dy)) then
			return
		end

		if (wnd.model_move) then
			local props = image_surface_properties(mesh)
			move3d_model(mesh, props.x + dx * -0.01, props.y, props.z + dy * -0.01)
		else
			rotate3d_model(mesh, 0, dy, dx, 0, ROTATE_RELATIVE)
		end
		return true
	end

-- there should be a cleaner way to adjust the handler chain now
	local lst = {}
	for k,v in pairs(wnd.handlers.mouse.canvas) do
		table.insert(lst, k)
	end

	mouse_droplistener(wnd.handlers.mouse.canvas)
	mouse_addlistener(wnd.handlers.mouse.canvas, lst)
	show_image(tgtsurf)

	wnd.actions = {}
	return wnd
end

local set =
{
	sphere =
	function()
		return build_sphere(h_depth, 360, 360, 1, false)
	end,
	hemisphere =
	function()
		return build_sphere(h_depth, 360, 180, 1, true)
	end,
	rectangle =
	function()
-- rect_inv, 0.5625 scalef?
		return
			build_3dplane(-h_depth, -h_depth, h_depth, h_depth, 0,
			(depth / 20) * subdiv_factor[1],
			(depth / 20) * subdiv_factor[2], 1, true)
	end,
	cylinder =
	function()
		return build_cylinder(h_depth, depth, 360, 1)
	end,
	halfcylinder =
	function()
		return build_cylinder(h_depth, depth, 360, 1, "half")
	end,
	cube =
	function()
-- image_framesetsize(mesh, 6, FRAMESET_SPLIT)
		return build_3dbox(depth, depth, depth, 1, true)
	end
}

menus_register("global", "tools",
{
	name = "model",
	label = "Model Viewer",
	description = "3D model viewer",
	kind = "value",
	set = function()
		local res = {}
		for k,v in pairs(set) do
			table.insert(res, k)
		end
		table.sort(set)
-- dynamic enumeration with _decode based mesh loading missing
	end,
	handler =
	function(ctx, val)
		modelwnd(set[val]())
	end
})

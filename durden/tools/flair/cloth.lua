--
-- numerous improvements to do here still,
--
-- the biggest one being moving to pushing the vertices as secondary
-- textures and doing vertex-stage displacement so that we can
-- interpolate between current and next stage in simulation.
--
-- then there should be collision by pinning, unpinning and displacing
-- against a list of line segments from the titlebars that are present,
-- along with a tear/burn destruction (change indices into degenerates
-- and use a dissolve+gradient style effect along with marching
-- particles).
--
local verlet_build = system_load("tools/flair/verlet.lua")();
local timer_counter = 1;

local function cloth_setup(wnd, destroy)
-- scale parameters based on window tesselation levels, tesselation
-- based on window size with some clamps as it is rather CPU heavy
	local t_s = gconfig_get("cloth_level");
	wnd.old_border = image_surface_properties(wnd.border).opacity;
	wnd.verlet_control = verlet_build;
	blend_image(wnd.border, 0.0, 10);

	local synch_verlet = function()
		image_tesselation(wnd.canvas,
			function(ctx, n_v, v_sz)
				local v = wnd.verlet.points;
				for j=1,#v do
					ctx:vertices(j-1, v[j].x, v[j].y);
				end
			end
		);
	end

-- if the titlebar is hidden, we instead pin to the cursor position on canvas
	local cx, cy = mouse_xy();
	local props = image_surface_resolve(wnd.canvas);
	local lx = math.clamp(cx - props.x, 0, props.width);
	local ly = math.clamp(cy - props.y, 0, props.height);
	local lx = lx / props.width;
	local ly = ly / props.height;
	local tx = math.floor(lx * t_s);
	local ty = math.floor(ly * t_s);

	image_tesselation(wnd.canvas, t_s, t_s,
		function(ctx, n_v, v_sz)
				local pass = gconfig_get("cloth_precision");
				local mass = gconfig_get("cloth_mass");
				local damp_s = gconfig_get("cloth_damp_s");
				local damp_t = gconfig_get("cloth_damp_t");
				wnd.verlet = verlet_build.build({}, t_s, t_s,
				gconfig_get("cloth_passes"),
				gconfig_get("cloth_spacing"),
				gconfig_get("cloth_gravity"),
				function(x, y)
					local px, py = ctx:vertices(y * t_s + x);

-- if the titlebar is hidden, we take the other tactic of pinning to the
-- mouse cursor position on canvas (assuming that actually initiated it)
					local pin = (destroy == nil and y == 0 and
						not destroy and not wnd.hide_titlebar);

					return px, py, pin, mass, damp_s, damp_t;
			end
			);
			wnd.verlet.acc_x = 0;
			wnd.verlet.acc_y = 0;
		end
	);

-- four-point pin at cursor position
	if (wnd.hide_titlebar) then
		verlet_build.pin(wnd.verlet, tx, ty, true);
		if (tx < t_s-1) then
			verlet_build.pin(wnd.verlet, tx+1, ty, true);
			if (ty < t_s-1) then
				verlet_build.pin(wnd.verlet, tx+1, ty+1, true);
				verlet_build.pin(wnd.verlet, tx, ty+1, true);
			else
				verlet_build.pin(wnd.verlet, tx+1, ty-1, true);
				verlet_build.pin(wnd.verlet, tx, ty-1, true);
			end
		else
			verlet_build.pin(wnd.verlet, tx-1, ty, true);
			if (ty < t_s-1) then
				verlet_build.pin(wnd.verlet, tx-1, ty+1, true);
				verlet_build.pin(wnd.verlet, tx, ty+1, true);
			else
				verlet_build.pin(wnd.verlet, tx-1, ty-1, true);
				verlet_build.pin(wnd.verlet, tx, ty-1, true);
			end
		end
	end

	synch_verlet();
	wnd.verlet.update = function()
		if (wnd.verlet.acc_x ~= 0 or wnd.verlet.acc_y ~= 0) then
			local fx = -(wnd.verlet.acc_x / wnd.wm.width);
			local fy = -(wnd.verlet.acc_y / wnd.wm.height);
			wnd.verlet.acc_x = 0;
			wnd.verlet.acc_y = 0;
			local af = verlet_build.add_force;
			local dh = wnd.verlet.h;
			local dw = wnd.verlet.w;
			for y=1,dh do
				for x=1,dw do
					af(wnd.verlet, fx, fy, x, y);
				end
				fx = fx * 1.05; -- some momentum
			end
		end
		return true;
	end

	local tn = "cloth_" .. timer_counter;
	wnd.verlet.timer_name = tn;
	timer_counter = timer_counter + 1;
	timer_add_periodic(wnd.verlet.timer_name, 1, false, function()
			if (not wnd.canvas or not wnd.verlet) then
				timer_delete(tn);
			else
-- apply accumulated forces from dragging window around, doing it
-- per event is expensive
				if (wnd.verlet.update()) then
					verlet_build.tick(wnd.verlet);
					synch_verlet();
				end
			end
		end, true
	);
end

local function cloth_begin(wnd)
	cloth_setup(wnd);
end

local function cloth_destroy(wnd)
	cloth_begin(wnd, true);
end

-- if we end directly, it looks very jerky, want a fast transition
-- back to the original coordinates. Run a new timer,
local function cloth_end(wnd)
	if (not wnd or not wnd.verlet) then
		return;
	end

	verlet_build.restore(wnd.verlet, 10);
	blend_image(wnd.border, wnd.old_border, 11);
	tag_image_transform(wnd.border, MASK_OPACITY, function()
		wnd.verlet = nil;
		image_tesselation(wnd.canvas, 1, 1);
	end);
	wnd.old_border = nil;
end

local function cloth_apply(wnd, dx, dy)
	if (wnd.verlet) then
		if ( (dx < 0) ~= (wnd.verlet.acc_x < 0) or
			( (dx < 0) ~= (wnd.verlet.acc_y < 0) ) ) then
			wnd.verlet.update();
		end

		wnd.verlet.acc_x = wnd.verlet.acc_x + dx;
		wnd.verlet.acc_y = wnd.verlet.acc_y + dy;
	end
end

gconfig_register("cloth_level", 20);
gconfig_register("cloth_passes", 2);
gconfig_register("cloth_mass", 1);
gconfig_register("cloth_spacing", 0.15);
gconfig_register("cloth_gravity", 0.0150);
gconfig_register("cloth_damp_s", 0.99);
gconfig_register("cloth_damp_t", 0.99);

local cloth_config = {
	{
		name = "level", label = "Subdivisions", kind = "value",
		initial = function() return gconfig_get("cloth_level"); end,
		description = "Set the number of subdivisions that should be used (quality - CPU tradeoff)",
		validator = gen_valid_num(10, 100),
		hint = "(1 .. 100)",
		handler = function(ctx, val) gconfig_set("cloth_level", tonumber(val)); end
	},
	{
		name = "passes", label = "Passes", kind = "value",
		initial = function() return gconfig_get("cloth_passes"); end,
		hint = "(1 .. 10)",
		description = "Set the number of integration passes (precision - CPU tradeoff)",
		validator = gen_valid_num(1, 10),
		handler = function(ctx, val) gconfig_set("cloth_passes", tonumber(val)); end
	},
	{
		name = "mass", label = "Mass", kind = "value",
		initial = function() return gconfig_get("cloth_mass"); end,
		hint = "(0.1 .. 10)",
		description = "Change the simulated cloth surface mass",
		validator = gen_valid_float(0.1, 10.0),
		handler = function(ctx, val) gconfig_set("cloth_mass", tonumber(val)); end
	},
	{
		name = "spacing", label = "Spacing", kind = "value",
		initial = function() return gconfig_get("cloth_spacing"); end,
		validator = gen_valid_float(0.001, 1.0),
		description = "Change the distance between grid particles",
		hint = "(0.001, 1.0)",
		handler = function(ctx, val) gconfig_set("cloth_spacing", tonumber(val)); end
	},
	{
		name = "gravity", label = "Gravity", kind = "value",
		initial = function() return gconfig_get("cloth_gravity"); end,
		validator = gen_valid_float(0.001, 0.1),
		description = "Change the strength of gravity",
		hint = "(0.001, 0.1)",
		handler = function(ctx, val) gconfig_set("cloth_gravity", tonumber(val)); end
	},
	{
		name = "damp_s", label = "Damp(s)", kind = "value",
		initial = function() return gconfig_get("cloth_damp_s"); end,
		description = "Change force- dampening in plane-local s (X axis)",
		validator = gen_valid_float(0.1, 2.0),
		hint = "(0.1, 2.0)",
		handler = function(ctx, val) gconfig_set("cloth_damp_s", tonumber(val)); end
	},
	{
		name = "damp_t", label = "Damp(t)", kind = "value",
		initial = function() return gconfig_get("cloth_damp_t"); end,
		validator = gen_valid_float(0.1, 2.0),
		description = "Change force- dampening in plane-local t (Y axis)",
		hint = "(0.1, 2.0)",
		handler = function(ctx, val) gconfig_set("cloth_damp_t", tonumber(val)); end
	}
};

local cloth_menu = {
	name = "cloth",
	label = "Cloth Physics",
	kind = "action",
	submenu = true,
	eval = function()
		return gconfig_get("flair_drag") == "cloth";
	end,
	handler = cloth_config
};

return {
	label = 'cloth',
	menu = cloth_menu,
	start = cloth_begin,
	stop = cloth_end,
	update = cloth_apply
};

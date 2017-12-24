-- simple particle system generator
--
-- initiated with a table of possible callbacks:
--  create(vid, state) : build surface, seed state, let system tag
--                       vid is set to a linked null surface at starting
--                       position and a starting particle size
--  update(vid, state, tickcount) : logical processing
--  collision(state_a, state_b) : two-particle collisions
--  ui_collision(state_a, anchor_vid,
--     abs_x(,y,x2,y2), rel_cpx, cpy) : particle has collided with an ui obj
--  ui_destroy(state, anchor_vid) : global notice on destroy
--  destroy(vid, state)
--
local in_psys = false;
local psys_list = {};

local function psys_create(v)
	local nsrf = null_surface(
		math.random(v.emitter.min_w, v.emitter.max_w),
		math.random(v.emitter.min_h, v.emitter.max_h)
	);
	show_image(nsrf);
	link_image(nsrf, v.anchor);

-- set offset and set direction based on emitter geometry
	if (v.emitter.shape == "rectangle") then
		move_image(nsrf,
			math.random(v.emitter.x1, v.emitter.x2),
			math.random(v.emitter.y1, v.emitter.y2)
		);
	end

	local iv = {
		vid = nsrf
	};

	v.create(iv);
	table.insert(v.particles, iv);
end

local function psys_step()
	for _,v in ipairs(psys_list) do
		for _,p in ipairs(v.particles) do
			v.update(p);
		end
	if (v.counter > 0) then
		v.counter = v.counter - 1;
	else
-- try emit
		if (#v.particles < v.particle_limit) then
			psys_create(v);
			v.counter = v.counter_start;
		else
			local p = table.remove(v.particles, 1);
			v.destroy(p, 5);
		end
	end
	end
end

return function(handlers, opts)
	local res = {};
	if (not handlers or not handlers.create or not handlers.update) then
		warning("flair/psys - invalid particle system");
		return;
	end

	if (not opts) then
		opts = {};
	end

	local display = active_display();

-- defer timer registration until first system is set, and use a shared timer
	if (not in_psys) then
		timer_add_periodic("flair_psys", 1, false, psys_step, false);
		in_psys = true;
	end

	local new_sys = {
		create = handlers.create,
		update = handlers.update,
		destroy = handlers.destroy,
		display = display,
		counter_start = 1,
		counter = 1,
		particle_limit = opts.particle_limit and opts.particle_limit or 100,
		anchor = null_surface(1, 1),
		particles = {}
	};

	show_image(new_sys.anchor);
	link_image(new_sys.anchor, display.order_anchor);

	if (not opts.emitter) then
		new_sys.emitter = {
			shape = "rectangle",
			x1 = 0, y1 = 0,
			x2 = math.random(1, display.width) - 1, y2 = 1,
			min_w = 1, max_w = 4, min_h = 1, max_h = 4,
			dx = {-1, 1},
			dy = {0, 1}
		}
	else
		new_sys.emitter = opts.emitter;
	end

	table.insert(psys_list, new_sys);
end

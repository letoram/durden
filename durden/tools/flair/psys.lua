-- simple particle system generator
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
		math.random(v.particle_min_w, v.particle_max_w),
		math.random(v.particle_min_h, v.particle_max_h)
	);
	show_image(nsrf);
	link_image(nsrf, v.anchor);

-- set offset and set direction based on emitter geometry
	local dir = v:apply_emitter(nsrf);
	local iv = {
		direction = dir,
		velocity = math.random(v.particle_min_vel, v.particle_max_vel),
		vid = nsrf
	};

-- either lifespan or when it goes off screen
-- (dynamic systems should treat the screen as a hard boundary)
	if (v.lifespan) then
		expire_image(v.vid, v.lifespan);
	end
end

local function psys_step()
	for _,v in ipairs(psys_list) do
		for _,p in ipairs(v.particles) do
			v.update(p.vid, p.state, 1);
		end
	if (v.counter > 0) then
		v.counter = v.counter - 1;
	else
-- try emit
		if (v.particle_count < v.particle_limit) then
			psys_create(v);
			v.counter = v.counter_start;
		end
	end
	end
end

return function(handlers, opts)
	local res = {};

-- defer timer registration until first system is set, and use a shared timer
	if (not in_psys) then
		timer_add_periodic("flair_psys", 1, false, psys_step, false);
		in_psys = true;
	end

	table.insert(psys_list, new_sys);
-- opts: initial seed counter, upper limit, distribution function/method, ..
end

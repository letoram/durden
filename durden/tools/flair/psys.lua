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
--  expire(vid, state)
--
local in_psys = false;

-- track all active particle systems
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

	v.create(iv, v);
	table.insert(v.particles, iv);
end

local function psys_step()
	local attach = set_context_attachment();

	for _,v in ipairs(psys_list) do
		set_context_attachment(v.display.rtgt_id);
		v:step();
		if (#v.particles > 0) then
			for i=#v.particles,1,-1 do
				if (not v.update(v.particles[i], v)) then
					v.expire(v.particles[i], 5);
					table.remove(v.particles, i);
					psys_create(v);
				end
			end
		end
		if (v.counter > 0) then
			v.counter = v.counter - 1;
		else
-- try emit
			if (#v.particles < v.particle_limit) then
				psys_create(v);
				v.counter = v.counter_start;
			end
		end
	end

	set_context_attachment(attach);
end

local function psys_destroy(system)
	table.remove_match(psys_list, system);
	table.remove_match(system.display.display_effects, system);
	blend_image(system.anchor, 0.0, 20);
	expire_image(system.anchor, 20);
end

return function(name, handlers, opts)
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
		name = name,
		create = handlers.create,
		update = handlers.update,
		expire = handlers.expire,
		destroy = psys_destroy,
		step = handlers.step,
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
			x1 = 0, y1 = -40,
			x2 = display.width, y2 = 0,
			min_w = 1, max_w = 4, min_h = 1, max_h = 4,
			dx = {-1, 1},
			dy = {0, 1}
		}
	else
		new_sys.emitter = opts.emitter;
	end

	if (not display.display_effects) then
		display.display_effects = {};
	end

	table.insert(psys_list, new_sys);
	table.insert(display.display_effects, new_sys);
end

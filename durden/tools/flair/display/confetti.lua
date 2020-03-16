-- stupid particle rules modelling confetti blast
local ht = {};

local bin_ind = 1;

local function confetti_create(state, system)
	local bin = system.bin[bin_ind];
	bin_ind = bin_ind + 1 > 3 and 1 or bin_ind + 1;
	state.x = bin[1] + math.random(-50, 50);
	state.y = system.emitter.y1 + math.random(10, 100);
	state.ang = bin[2] + (0.5 - math.random()) * 0.1 * math.pi;
	state.ticks = 0;
	state.r = math.random() * 200;
	state.g = math.random() * 200;
	state.b = math.random() * 200;
	state.phase = 0;
	image_color(state.vid, state.r, state.g, state.b);
	show_image(state.vid);

	local props = image_surface_properties(state.vid);
	state.mass =
		1.0 - ((props.width * props.height) /
		(system.emitter.max_w * system.emitter.max_h));

	state.rang = math.random(1, 180);
	state.rvel = math.random(1, 10);
	state.acceleration_x = 40 * state.mass * math.cos(-state.ang);
	state.acceleration_y = 40 * state.mass * math.sin(-state.ang);
	move_image(state.vid, state.x, state.y);
	rotate_image(state.vid, state.rang);
end

local function confetti_update(state, system)
	if (state.fixed) then
		return;
	end

-- change rotational direction periodically
	if (state.ticks > 0) then
		state.ticks = state.ticks - 1;
	else
--		state.ang = 270 + math.random(-22, 23);
		state.ticks = 10 + math.random(1, 10);
	end

-- local rotation and shimmer'
	state.rang = (state.rang + state.rvel) % 360;
	if (math.abs(state.rang - 90) < 10) then
		image_color(state.vid, 227, 227, 227);
	else
		image_color(state.vid, state.r, state.g, state.b);
	end

-- apply to vid
	rotate_image(state.vid, state.rang, 1);
	move_image(state.vid, state.x, state.y, 1);
	local ny = state.y;
	state.y = state.y + state.acceleration_y + system.force_y;
	state.x = state.x + state.acceleration_x;
-- falling, reduce speed and drift back and forth in x
	if (ny > state.y) then
		state.x = state.x + system.force_x +
			math.abs(math.sin(state.phase / (2*math.pi)) * state.rvel);
		state.phase = (state.phase + 1) % 180;
		state.acceleration_y = state.acceleration_y + state.mass * 0.8922;
	else
-- slowly reduce accleration
		state.acceleration_x = 0;
		state.rvel = state.rvel * (state.rvel > 1 and 0.8 or 1);
		state.acceleration_y = state.acceleration_y + state.mass * 0.0288;
		state.x = state.x + state.acceleration_x + system.force_x;
	end

	return true;
end

local step_sz = 2 * 3.1457 / 360.0;
local function confetti_step(system)
	system.ticks = system.ticks + 1;
	system.counter = (system.counter + 0.01) % 360;

	if (system.ticks > 1000) then
		system:destroy();
	end

	system.force_x = math.pow(math.sin(system.counter * step_sz) * 0.5 + 0.5, 4);

	return true;
end

local function confetti_expire(state)
	delete_image(state.vid);
end

local function confetti_setup(system)
	local disp = active_display();
	local third = disp.width / 3;

-- three bins, then ~45 degree cone random distribution per bin
	system.bin = {
		{0.5 * third, 0.25 * math.pi},
		{third + 0.5 * third, 0.5 * math.pi},
		{third + third + 0.5 * third, 0.75 * math.pi}
	};

	system.ticks = 0;
	system.factor = 0.1;
	system.force_y = -9.82;
	system.force_x = 0;
	system.counter = 0;

-- emitter won't actually be used here more than for the color
	system.emitter = {
		shape = "rectangle",
		kind = "color",
		x1 = 0, y1 = disp.height,
		x2 = 0, y2 = disp.height,
		min_w = 5, max_w = 25, min_h = 4, max_h = 10,
	}
end

return {
	create = confetti_create,
	update = confetti_update,
	expire = confetti_expire,
	step = confetti_step,
	setup = confetti_setup,
	collision_model = "none"
},
{
	particle_burst = 400,
	particle_limit = 0,
};

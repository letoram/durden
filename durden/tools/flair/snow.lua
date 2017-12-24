-- particle rules simulating falling snow
--

local white = fill_surface(4, 4, 255, 255, 255);

local function snow_create(state)
	image_sharestorage(white, state.vid);
	blend_image(state.vid, 0.5 + 0.5 * math.random());
	rotate_image(state.vid, math.random(0, 359));
	state.velocity_x = 0;
	state.velocity_y = 0;
	state.acceleration_x = 0;
	state.acceleration_y = 0.1;
end

local function snow_update(state)
	nudge_image(state.vid, state.velocity_x, state.velocity_y);
	state.velocity_x = state.velocity_x + state.acceleration_x;
	state.velocity_y = state.velocity_y + state.acceleration_y;
end

local function snow_step(state)
-- vary the global wind
	state.force_x = math.pow(math.sin(counter) * 0.5 + 0.5, 4) * 150;
	state.force_y = math.sin(counter * 100) * 20;
end

local function snow_destroy(state)
	delete_image(state.vid);
end

return {
	create = snow_create,
	update = snow_update,
	destroy = snow_destroy,
	step = snow_step
};

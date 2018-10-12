-- simple particle rules modelling snow
--
-- none of the fun stuff yet (force-field wind motion matching cursor movement)
-- or collision-detection / response (merge/accumulate on surfaces)
--
local white = fill_surface(4, 4, 255, 255, 255);
local ht = {};

local function snow_create(state, system)
	image_sharestorage(white, state.vid);
	blend_image(state.vid, 0.5 + 0.5 * math.random());
	rotate_image(state.vid, math.random(0, 359));
	state.velocity_x = 0;
	state.velocity_y = 0;
	local props = image_surface_properties(state.vid);
	state.mass = props.width * props.height;
	state.acceleration_x = 0;
	state.acceleration_y = math.random() * 2;
	state.force_x = 0;
	state.force_y = 0;
end

local function snow_update(state, system)
	if (state.fixed) then
		return;
	end
	nudge_image(state.vid, state.velocity_x, state.velocity_y, 1);
	state.velocity_x = state.velocity_x + state.acceleration_x + system.force_x;
	state.velocity_y = state.velocity_y + state.acceleration_y + system.force_y;
	return image_surface_properties(state.vid).y < system.display.height;
end

local step_sz = 2 * 3.1457 / 360.0;
local counter = 0;

-- vary the global wind
local function snow_step(system)
	counter = (counter + 0.01) % 360;
	system.force_x = math.pow(math.sin(counter * step_sz) * 0.5 + 0.5, 4);
	system.force_y = math.abs(math.sin(counter * step_sz)) * 0.05;
	return true;
end

local function snow_expire(state)
	delete_image(state.vid);
end

return {
	create = snow_create,
	update = snow_update,
	expire = snow_expire,
	step = snow_step,
	collision_model = "full"
};

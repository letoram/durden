-- particle rules simulating falling snow
--
-- emission:
-- set direction to +y
-- apply force (wind), distance and 1.0 / 1.0 + dist.
-- integration:
--   x += sx, y += sy
--  sx += ax, sy += ay
--
--

local function snow_create(vid, state)
	print("time to create");
end

local function snow_update(vid, state, tickcount)
	print("time to step");
end

return {
	create = snow_create,
	update = snow_update,
	destroy = snow_destroy
};

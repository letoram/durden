--
-- display- global effects
--
-- these are treated as either a freestanding effect that exist in the same
-- attachment as the targeted display, or as a last- stage compositing effect
-- that goes with the rt. The latter case is a singleton due to its cost and
-- the problem that its output becomes the display rendertarget input source
-- for last stage colorization etc. shader.
--
-- this is activated per display in order to have displays where this is not
-- enabled, e.g. a HMD or presentation projector.
--

local snow_rules, snow_opts = system_load("tools/flair/snow.lua", false)();

return {
	{
		name = "snow",
		label = "Snow",
		description = "Snow Simulator",
		create = function(disp, ...)
			return flair_supp_psys("snow", snow_rules, snow_opts);
		end
	}
};

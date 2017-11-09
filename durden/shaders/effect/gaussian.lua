-- simple 2-pass gaussian blur effect
-- note that the scaling doesn't work on targets that autocrop,
-- typically the terminal
local punif = {
	weight = {
	label = "weight",
	utype = 'f',
	default = 1.0,
	low = 0.1,
	high = 2.0
}
};

return {
	version = 1,
	label = "Gaussian Blur",
	filter = "bilinear",
	passes = {
		{
			filter = "bilinear",
			output = "bilinear",
			scale = {0.5, 0.5},
			maps = {},
			uniforms = punif,
			frag_source = "gaussian_h.frag",
		},
		{
			filter = "bilinear",
			output = "bilinear",
			uniforms = punif,
			scale = {1.0, 1.0},
			maps = {},
			frag_source = "gaussian_v.frag",
		}
	}
};

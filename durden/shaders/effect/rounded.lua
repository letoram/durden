return {
	version = 1,
	label = "Rounded",
	filter = "none",
	no_rendertarget = true,
	passes = {
	{
		filter = "none",
		output = "none",
		scale = {1.0, 1.0},
		maps = {},
		frag_source = "rounded.frag",
		uniforms = {
			radius = {
				label = 'Radius',
				utype = 'f',
				default = 5,
				description = 'Corner Radius Circle',
				low = 1,
				high = 100,
			},
			sigma = {
				label = 'Sigma',
				utype = 'f',
				default = 2,
				description = 'Shadow Blur Coefficient',
				low = 1,
				high = 100
			},
		}
	}
	}
};

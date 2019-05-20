return {
	version = 1,
	label = "Dropshadow",
	filter = "none",
	frag_source = "dropshadow.frag",
	uniforms = {
		radius = {
			label = 'Radius',
			utype = 'f',
			default = 5,
			description = 'Corner Radius Circle',
			low = 1,
			high = 20,
		},
		sigma = {
			label = 'Sigma',
			utype = 'f',
			default = 2,
			description = 'Shadow Blur Coefficient',
			low = 1,
			high = 20
		},
		weight = {
			label = 'Weight',
			utype = 'f',
			default = 0.5,
			description = 'Shadow Blur Weight',
			low = 0.1,
			high = 1.0
		},
		color = {
			label = "Color",
			utype = 'fff',
			default = {1.0, 0.0, 1.0},
			low = 0.0,
			high = 1.0,
			description = 'Base shadow color to use',
		},
		mix_factor = {
			label = "Mix Factor",
			utype = 'f',
			default = 0,
			low = 0,
			high = 1,
			description = '> 0, mix source texture with base color'
		}
	}
};

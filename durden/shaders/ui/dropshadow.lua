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
			dscription = 'Shadow Blur Weight',
			low = 0.1,
			high = 1.0
		}
	}
};

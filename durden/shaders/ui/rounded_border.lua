return {
	version = 1,
	label = "Rounded Border",
	filter = "none",
	frag_source = "rounded_border.frag",
	uniforms = {
		radius = {
			label = 'Radius',
			utype = 'f',
			default = 20,
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
		shadow_color = {
			label = "Shadow",
			utype = 'fff',
			default = {0.05, 0.05, 0.05},
			low = 0.0,
			high = 1.0,
			description = 'Base shadow color to use',
		},
		border_color = {
			label = "Border",
			utype = 'fff',
			default = {0.7, 0.7, 0.7},
			low = 0.0,
			high = 1.0,
			description = "Border color to use"
		},
		border_thickness = {
			label = "Thickness",
			utype = 'f',
			default = {0.04},
			low = 0.01,
			high = 0.1,
			description = "Range assigned for border",
		},
	}
};

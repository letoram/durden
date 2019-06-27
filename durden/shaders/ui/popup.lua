return {
	version = 1,
	label = "Popup",
	filter = "none",
	frag_source = "popup.frag",
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
		shadow_color = {
			label = "Shadow",
			utype = 'fff',
			default = {0.05, 0.05, 0.05},
			low = 0.0,
			high = 1.0,
			description = 'Base shadow color to use',
		},
		background_color = {
			label = "Background",
			utype = 'fff',
			default = {0.3, 0.3, 0.3},
			low = 0.0,
			high = 1.0,
			description = 'Background color to use',
		},
		border_color = {
			label = "Border",
			utype = 'fff',
			default = {0.7, 0.7, 0.7},
			low = 0.0,
			high = 1.0,
			description = "Border color to use"
		},
		select_color = {
			label = "Select",
			utype = 'fff',
			default = {0.3, 0.3, 0.7},
			low = 0.0,
			high = 1.0,
			description = "Selection color to use",
		},
		range = {
			label = "Range",
			utype = 'ff',
			hidden = true,
			default = {0.2, 0.3},
			low = 0.0,
			high = 1.0,
			description = "Surface-coordinates for selection color"
		}
	}
};

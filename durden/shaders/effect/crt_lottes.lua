-- Timothy Lottes CRT shader
--

return {
	version = 1,
	label = "CRT-Lottes",
	filter = "bilinear",
-- needed to have txcos that is relative to orig. size
	passes = {
	{
		filter = "none",
		output = "none",
		scale = {1.0, 1.0},
		maps = {},
		frag_source = "crt_lottes.frag",
		uniforms = {
		hard_scan = {
			label = "Hard scan",
			utype = "f",
			default = {-8.0},
			low = -20.0,
			high = 0.0,
			step = 1.0
		},
		hard_pix = {
			label = "Hard Pix",
			utype = "f",
			default = {-3.0},
			low = -20.0,
			high = 0.0,
			step = 1.0
		},
		warp_xy = {
			label = "Warp XY",
			utype = "ff",
			default = {0.031, 0.041},
			low = 0.0,
			high = 0.125,
			step = 0.01
		},
		mask_dark = {
			label = "Dark Mask",
			utype = "f",
			default = {0.5},
			low = 0,
			high = 2.0,
			step = 0.1
		},
		mask_light = {
			label = "Light Mask",
			utype = "f",
			default = {1.5},
			low = 0.0,
			high = 2.0,
			step = 0.1
		},
		linear_gamma = {
			label = "Linear Gamma",
			utype = "f",
			default = {1.0},
			low = 0.0,
			high = 1.0,
			step = 1.0
		},
		shadow_mask = {
			label = "Shadow Mask",
			utype = "f",
			default = {3.0},
			low = 0.0,
			high = 4.0,
			step = 1.0
		},
		bright_boost = {
			label = "Brightness Boost",
			utype = "f",
			default = {1.0},
			low = 0.0,
			high = 2.0,
			step = 0.05
		},
		bloom_x = {
			label = "Bloom X",
			utype = "f",
			default = {-1.5},
			low = -2.0,
			high = -0.5,
			step = 0.1
		},
		bloom_y = {
			label = "Bloom Y",
			utype = "f",
			default = {-2.0},
			low = -4.0,
			high = -1.0,
			step = 0.1
		},
		bloom_amount = {
			label = "Bloom Amount",
			utype = "f",
			default = {0.15},
			low = 0.0,
			high = 1.0,
			step = 0.05
		},
		filter_shape = {
			label = "Filter Shape",
			utype = "f",
			default = {2.0},
			low = 0.0,
			high = 10.0,
			step = 0.05
		}
		}
	}
	}
};


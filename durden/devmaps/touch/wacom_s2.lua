return {
	label = "Wacom Intuos S 2",
	name = "wacom_s2",
	matchflt = "Wacom Intuos S 2 Pen",
	autorange = false,
	range = {0, 0, 15200, 9500},
	classifier = "relmouse",
	activation = {0.0, 0.0, 1.0, 1.0},
	scale_x = 1.0,
	scale_y = 1.0,
	submask = 0xffff,
	default_cooldown = 2,
	mt_eval = 5,
	motion_block = false,
	warp_press = false,
	timeout = 1,
	swipe_threshold = 0.2,
	drag_threshold = 0.2,
	gestures = {
	}
};

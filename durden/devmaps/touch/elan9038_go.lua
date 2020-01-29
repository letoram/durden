local remap_tbl = {};
remap_tbl[0] = 0;
remap_tbl[1] = 0;

-- special buttons:
-- 32 - presence
-- 33 - eraser presence
--  1 - pen buttoN
--  0 - pen on surface
-- eraser-button : doesn't respond (kernel level)

return {
	label = "Elan Surface GO Pen",
	name = "elan_9038_pen",
	matchstr = "ELAN9038:00 04F3:261A",
	autorange = false,
	range = {0, 0, 13312, 8960},
	classifier = "absmouse",
	axis_remap = remap_tbl,
	activation = {0.0, 0.0, 1.0, 1.0},
	scale_x = 1.0,
	scale_y = 1.0,
	button_gesture = {[1] = "doubletap"},
	default_cooldown = 2,
	mt_eval = 5,
	motion_block = false,
	warp_press = true,
	timeout = 1,
	swipe_threshold = 0.2,
	drag_threshold = 0.2,
	gestures = {
-- idle_return, popup helper menu to select / control modes
		["doubletap"] = "/global",
--		["idle_return"] = "/global/tools/dterm",
	}
};

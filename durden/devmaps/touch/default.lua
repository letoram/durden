--
-- Default touch-pad profile, without this script available,
-- the touchpad support will be disabled. Copy and change 'label',
-- name and 'matchflt' to support customized profiles for different
-- devices.
--

return {
	label = "default",
	name = "default",

-- track / remember sample values to figure out device range
	autorange = true,

-- invalid default range due to "autorange"
	range = {VRESW, VRESH, 1, 1},
	classifier = "relmouse",
	activation = {0.1, 0.1, 0.9, 0.9},

-- "pre-mouse" acceleration
	scale_x = 3.0,
	scale_y = 2.5,

-- mask to disable certain button indices for digital events
	submask = 0xffff,

-- ignore samples between state changes for a number of ticks
	default_cooldown = 2,

-- window for drag-vs-swipe evaluation
	mt_eval = 5,

-- reset touch- tracking after n ticks of no input samples
	timeout = 10,

-- minimum weighted normalized distance to move for gesture to register
	swipe_threshold = 0.2,
	drag_threshold = 0.2,

-- menu path to trigger on gestures, valid are:
-- swipe(n)_(dir) where (n) == 2,3,4... and (dir) == up,down,left,right
-- drag(n)_(dir) where (n) == 2,3,4... and (dir) == up,down,left,right
	gestures = {
		swipe3_right = '!workspace/switch/next',
		swipe3_left = '!workspace/switch/prev',
		drag2_up = '!input/mouse/button/4',
		drag2_down = '!input/mouse/button/5',
	}
};

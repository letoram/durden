--
-- Default touch-pad profile, without this script available,
-- the touchpad support will be disabled. Copy and change 'label',
-- name and 'matchflt' to support customized profiles for different
-- devices.
--

return {
	label = "default",
	name = "default",

-- device string pattern or explicit string for auto- selecting profile,
-- not needed for the special 'default' name
	matchflt = nil,

-- track / remember sample values to figure out device range
	autorange = true,

-- invalid default range due to "autorange"
	range = {VRESW, VRESH, 1, 1},

-- other option is 'absmouse'
	classifier = "relmouse",

-- ignore samples until we get one inside (>= [1,2] <= [3,4])
	activation = {0.1, 0.1, 0.9, 0.9},

-- "pre-mouse" acceleration
	scale_x = 3.0,
	scale_y = 2.5,

-- ignore samples between state changes for a number of ticks
	default_cooldown = 2,

-- window for drag-vs-swipe evaluation
	mt_eval = 5,

-- useful when combining touch displays, track pad and regular mouse,
-- motion block stops cursor movement (gestures only) and warp_press
-- makes digital events warp to last known device-specific x,y, send a
-- press and then jump back
	motion_block = false,
	warp_press = false,

-- ignore all digital events on the device, only use touch for 'click'
	button_block = false,

-- reset touch- tracking after n ticks of no input samples
	timeout = 10,

-- minimum weighted normalized distance to move for gesture to register
	swipe_threshold = 0.2,
	drag_threshold = 0.05,
	drag_step = 0.01,

-- options for various rotated screens, inversions are applied after swap
	swap_xy = false,
	invert_x = false,
	invert_y = false,

-- treat 2f drag gestures as analog mouse wheel, masking out any
-- drag2_up/drag2_down gestures
	drag_2f_analog = false,
	drag_2f_analog_factor = {100, 100},

-- menu path to trigger on gestures, valid are:
-- swipe(n)_(dir) where (n) == 2,3,4... and (dir) == up,down,left,right
-- drag(n)_(dir) where (n) == 2,3,4... and (dir) == up,down,left,right
	gestures = {
		swipe3_right = '/global/workspace/switch/next',
		swipe3_left = '/global/workspace/switch/prev',
		drag2_up = '/global/input/mouse/button/4',
		drag2_down = '/global/input/mouse/button/5',
	}
};

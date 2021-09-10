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

-- ignore multitouch entirely
	mt_disable = false,

-- useful when combining touch displays, track pad and regular mouse,
-- motion block stops cursor movement (gestures only) and warp_press
-- makes digital events warp to last known device-specific x,y, send a
-- press and then jump back
	motion_block = false,
	warp_press = false,

-- some devices provide both 'touch' based press and digital input
-- press events which can lead to ghost 'clicks', this feature ignores
-- all the digital inputs
	button_block = false,

-- For mouse simulation classifiers, the wheel is a source of problems
-- as some drivers exclusively provide digital 'ticks' and some act as
-- a relative-analog sensor. This has lead to emulating ticks in the
-- analog case, and clients that can't deal with analog wheels. This
-- setting will emit 2-finger drags as wheel action in the dominant
-- axis and don't emit these as discrete 'gesture' events.
	drag_2f_analog = false,
	drag_2f_analog_factor = {100, 100},

-- some drivers give button presses for various gestures such as
-- double-tap, remap these to their gestures (or some unknown one
-- like ignore) to mask these
	button_gestures = {
		[1] = "doubletap",
		[2] = {"held, released"},
		[37] = "ignore"
	},

-- some devices that aren't detected as touch properly need to have
-- their axis mapping specified explicitly
  axis_map = {[0] = 0, [1] = 1},

-- reset touch- tracking after n ticks of no input samples, also used
-- to evaluate 'n' for tap\_n and longpress gestures
	timeout = 10,

-- interpret the device as idle after n ticks of no input samples
	idle = 500,

-- minimum weighted normalized distance to move for gesture to register
	swipe_threshold = 0.2,
	drag_threshold = 0.2,

-- menu path to trigger on gestures, valid are:
-- swipe(n)_(dir) where (n) == 2,3,4... and (dir) == up,down,left,right
-- drag(n)_(dir) where (n) == 2,3,4... and (dir) == up,down,left,right
-- tap(n) where (n) is the number of taps within the timeout period
-- longpress
-- idle_enter when a device goes from being tracked as active to idle
-- idle_return when a device goes from being tracked as idle to active
-- match when a device emits samples for the first time and match a profile

	gestures = {
		swipe3_right = '/global/workspace/switch/next',
		swipe3_left = '/glbal/workspace/switch/prev',
		drag2_up = '/global/input/mouse/button/4',
		drag2_down = '/global/input/mouse/button/5',
	}
};

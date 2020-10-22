return {
	{
		name = "surface_dial",
		label = "Surface Dial System Multi Axis",
		gestures = {
			["click"] = nil, -- replace with desired path
			["dblclick"] = nil,
			["idle_enter"] = nil,
			["idle_leave"] = nil,
		},
		scale = 1,
		scale_press = 2
	},
	{
		name = "power_mate",
		label = "Griffin PowerMate",
		gestures = {
			["click"] = nil, -- replace with desired path
			["dblclick"] = "/global",
			["idle_enter"] = nil,
			["idle_leave"] = nil,
			["longpress"] = "/target"
		},
		scale = 1,
		scale_press = 2
	},
-- while not exactly 'similar' to other rotary controllers,
-- it is similar enough to emulate the rest (i.e. rz -> step)
--
-- the : prefix in the path is an input module specific emulation action
	{
		name = "space_mouse",
		label = "3Dconnexion SpaceMouse Pro",
		buttons = {
			[1]   = "/global/input/keyboard/symbol/escape", -- ESC
			[8]   = "", -- Alt
			[9]   = "", -- Shift
			[10]  = "", -- Control
			[11]  = "", -- spin
			[256] = "/global", -- Menu
			[268] = "/global/input/mouse/buttons/1", -- 1
			[269] = "/global/input/mouse/buttons/2", -- 2
			[270] = "/global/input/mouse/buttons/3", -- 3
			[281] = "", -- 4
			[257] = "/target", -- fit
			[258] = "", -- top
			[260] = "", -- right
			[261] = "", -- front
			[264] = "", -- roll
		},
		gestures = {
			["idle_enter"] = nil,
			["idle_leave"] = nil,
		},
		axis_map = {
			[4] = 0, -- x
			[3] = 1, -- y
			[2] = 2, -- z
			[5] = 3, -- rz
		},
		resample =
		function(axis, sample)
			local norm = math.clamp(math.abs(sample) / 350, 0, 1);
			return sample * (1/350) * 32767;
		end,
		elastic = true,
		tick_rate = 2, -- affects sensitivity
		scale = 1,
		scale_press = 2
	}
};

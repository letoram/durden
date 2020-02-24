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
	}
};

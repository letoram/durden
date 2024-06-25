local tbl =
{
-- voice synthesiser arguments
    model = "English (Great Britain)",
    gain = 0.5, -- audo gain on source
    gap = 10,   -- ms between words
    pitch = 40, -- 0  .. 100: 0 = low
		rate = 240,  -- 10 .. 450: wpm
		range = 60, -- 0  .. 100: 0 = monotome
    channel = "r", -- l, r or lr,
		name = "cursor_eng",
		punct = 1,
		cappitch = 5000,
-- set of events that this voice will cover
    actions = {
 			cursor = "",
			key_echo = "",
    },

		cursor =
		{
			xy_beep = "C2",
			xy_beep_timer = 5,
		},

-- keybindings that will take over the defaults while voice is activated
    bindings =
    {
    }
}

return tbl

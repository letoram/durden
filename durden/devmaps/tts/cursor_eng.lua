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
 			cursor = "curs "
    },

		cursor =
		{
			alt_text = "over ",
			xy_beep = {65.41, 523.25},
			xy_beep_timer = 15,
			gain = 0.7,
		},

-- keybindings that will take over the defaults while voice is activated
    bindings =
    {
			m2_c = "/global/tools/tts/voices/cursor_eng/cursor_region/intensity=32,32",
			m2_o = "/global/tools/tts/voices/cursor_eng/cursor_region/ocr=64",
			m2_s = "/global/tools/tts/voices/cursor_eng/cursor_region/edge_intensity=32,32",
    }
}

return tbl

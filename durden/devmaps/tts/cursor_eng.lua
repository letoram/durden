local tbl =
{
-- voice synthesiser arguments
    model = "English (Great Britain)",
    gain = 0.5, -- audo gain on source
    gap = 10,   -- ms between words
    pitch = 40, -- 0  .. 100: 0 = low
		rate = 300,  -- 10 .. 450: wpm
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
			xy_beep_tone = "sine",
			xy_tuitone = "square", -- tone to play for cells with content
			xy_tuitone_length = 0.15,
			xy_tuitone_empty = "triangle", -- tone to play for empty cells
			xy_tuitone_empty_length = 0.1, -- shorter beep
			xy_tone_max = 0.15, -- at full brightness
			xy_tone_min = 0.05, -- at zero brightness
			xy_beep_timer = 15, -- how often the cursor will be sampled (1s = 25)
			gain = 0.7, -- max gain for the cursor tones
		},

		reset_beep = {660, 0.1},

-- keybindings that will take over the defaults while voice is activated
    bindings =
    {
			q = "/global/tools/tts/voices/cursor_eng/cursor_region/ocr=64",
			w = "/global/tools/tts/voices/cursor_eng/cursor_region/ocr_window",
			e = "/global/tools/tts/voices/cursor_eng/cursor_region/edge_intensity=32,32",
			["4"] = "/global/tools/tts/voices/cuersor_eng/flush",
    }
}

return tbl

local tbl =
{
-- voice synthesiser arguments
    model = "English (Great Britain)",
    gain = 1.0, -- audo gain on source
    gap = 10,   -- ms between words
    pitch = 60, -- 0  .. 100: 0 = low
		rate = 180,  -- 10 .. 450: wpm
		range = 60, -- 0  .. 100: 0 = monotome
    channel = "l", -- l, r or lr,
		name = "basic_eng",
		punct = 1,
		cappitch = 5000,

-- set of events that this voice will cover
    actions = {
    	select = {"title", "title_text"},
			menu = "menu",
			dispatch = "run",
			clipboard = "clip",
			clipboard_paste = "clip",
			notification = "notify",
			menu = "menu"
    },

-- keybindings that will take over the defaults while voice is activated
    bindings =
    {
			m1_r = "/global/tools/tts/voices/basic_eng/flush",
			m1_F1 = "/global/tools/tts/voices/basic_eng/input_incrate",
			m1_F2 = "/global/tools/tts/voices/basic_eng/input_decrate",
			m1_t = "/global/tools/tts/voices/basic_eng/slow_replay"
    }
}

return tbl

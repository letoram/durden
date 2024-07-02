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
    	select = {"wind", "tit", "title_text"},
			menu = "menu",
			dispatch = "run",
			clipboard = "clip set",
			clipboard_paste = "clip paste",
			notification = "notify",
			menu = "menu",
			a11ywnd = "wind",
    },

-- called whenever voice flush is requested, disable by settil to false or nil
		reset_beep = {440, 0.1},

-- this would position the voice back and to left
--		position = {-5, 0, -5},

-- pattern- matches and replacements
		replace =
		{
			{"^[-]", ""},
			{"^terminal[-]", "term "},
			{"$ [-] Chromium", ""},
		},

-- special options and bindings for menu navigation which different input system
		menu =
		{
			key_echo = true,
			speak_prompt = "lctrl_t",
			speak_description = "lctrl_h",
			speak_path = "lctrl_p",
			speak_set = "lctrl_s",
			speak_reset = "lctrl_r"
		},

-- keybindings that will take over the defaults while voice is activated
    bindings =
    {
			m1_r = "/global/tools/tts/voices/basic_eng/flush",
			m1_F2 = "/global/tools/tts/voices/basic_eng/input/incrate",
			m1_F3 = "/global/tools/tts/voices/basic_eng/input/decrate",
			m1_F1 = "/global/tools/tts/voices/basic_eng/read_bindings",
			m1_t = "/global/tools/tts/voices/basic_eng/slow_replay",
			m1_u = "/global/tools/tts/voices/basic_eng/text_window/row_down",
			m1_i = "/global/tools/tts/voices/basic_eng/text_window/row_up",
			m1_y = "/global/tools/tts/voices/basic_eng/text_window/cursor_before",
			m1_o = "/global/tools/tts/voices/basic_eng/text_window/cursor_after",
			m1_p = "/global/tools/tts/voices/basic_eng/text_window/changes"
    }
}

return tbl

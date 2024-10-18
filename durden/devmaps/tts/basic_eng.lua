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
		punct = 1, -- 0: none, 1: all, 2: some
		cappitch = 5000,
		default = true,

-- set of events that this voice will cover
    actions = {
    	select = {"wind ", "tit ", "title_text", " "},
			menu = "menu ",
			dispatch = "run ",
			clipboard = "clip set ",
			clipboard_paste = "clip paste ",
			notification = "notify ",
			menu = "menu ",
			a11ywnd = "wind ",
    },

-- called whenever voice flush is requested, disable by settil to false or nil
		reset_beep = {440, 0.1},
		a11y_font_sz = 18,
		a11y_font = "hack.ttf",

-- this would position the voice back and to left
--		position = {-5, 0, -5},

-- pattern- matches and replacements
		replace =
		{
			{"^[-]", ""},
			{"^terminal[-]", "term "},
			{"$ [-] Chromium", ""},
			{":", " colon "},
			{";", " semicolon "},
			{"%.", " dot "}
		},

-- special options and bindings for menu navigation which different input system
		menu =
		{
			key_echo = true,
			speak_prompt = "lctrl_t",
			speak_description = "lctrl_h",
			speak_path = "lctrl_p",
			speak_set = "lctrl_s",
			speak_reset = "lctrl_r",
			val_prefix = "val req ",
			val_suffix = "cur ",
			popup_prefix = "pop ",
		},

    bindings =
    {
			r = "/global/tools/tts/voices/basic_eng/flush",
			F2 = "/global/tools/tts/voices/basic_eng/input/incrate",
			F3 = "/global/tools/tts/voices/basic_eng/input/decrate",
			t = "/global/tools/tts/voices/basic_eng/slow_replay",
			s = "/global/tools/tts/voices/basic_eng/text_window/row_down",
			d = "/global/tools/tts/voices/basic_eng/text_window/row_up",
			a = "/global/tools/tts/voices/basic_eng/text_window/cursor_before",
			f = "/global/tools/tts/voices/basic_eng/text_window/cursor_after",
			g = "/global/tools/tts/voices/basic_eng/text_window/synch_cursor"
    }
}

return tbl

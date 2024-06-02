local tbl =
{
    model = "English (Great Britain)",
    gain = 1.0, -- audo gain on source
    gap = 10,   -- ms between words
    pitch = 50, -- 0  .. 100: 0 = low
		rate = 80,  -- 10 .. 450: wpm
		range = 50, -- 0  .. 100: 0 = monotome
    channel = "l", -- l, r or lr,
		name = "basic_eng",

    autos = { -- these resolve to a prefix spoken on a global event trigger, then the event data itself
    	on_select = {"title", "wnd.title_text"},
			on_menu = "menu",
			on_dispatch = "run",
    },

    bindings =
    {
--			m1_m2_c = "/global/tools/tts/basic_eng/speak/clipboard",
-- big advantage here would be access to contents on tui surfaces so we can read line at position
    }
}

return tbl

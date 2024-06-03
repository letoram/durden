local tbl =
{
    model = "English (Great Britain)",
		dictionary = "en",
    gain = 1.0, -- audo gain on source
    gap = 10,   -- ms between words
    pitch = 60, -- 0  .. 100: 0 = low
		rate = 180,  -- 10 .. 450: wpm
		range = 60, -- 0  .. 100: 0 = monotome
    channel = "l", -- l, r or lr,
		name = "basic_english",
		punct = 1,
		cappitch = 5000,

    actions = {
-- these resolve to a prefix spoken, then target members for the data
    	select = {"title", "title_text"},
 -- these resolve to a prefix spoken on a global event trigger, then the event data itself
			menu = "menu",
			dispatch = "run",
			clipboard = "clip",
			clipboard_paste = "clip",
			notification = "notify",
    },

    bindings =
    {
--			m1_m2_c = "/global/tools/tts/basic_eng/speak/clipboard",
-- big advantage here would be access to contents on tui surfaces so we can read line at position
    }
}

return tbl

-- basic test layout for something

return {
	width = 1280,
	height = 720,
	dynamic = false,
	items = {
		{
			order = 0,
			x = 0,
			x2 = 1280,
			y = 0,
			y2 = 720,
			rotation = 0,
			shader = "vignette",
			static_media = "$random:wallpapers/*.jpg",
			reload_timer = 1000,
			reload_fade = 10
		},
		{
			order = 1,
			x = 150,
			x2 = 855,
			y = 40,
			y2 = 430,
			slot = "preview",
		},
		{
			order = 2,
			x = 730,
			x2 = 970,
			y = 260,
			y2 = 430,
			slot = "extra_1"
		},
		{
			order = 1,
			x = 1000,
			x2 = 1140,
			y = 260,
			y2 = 430,
			slot = "mascot",
		},
		{
			order = 1,
			x = 800,
			y = 100,
			x2 = 1180,
			y2 = 660,
			selector = "list",
			config = {
				font = "default.ttf",
				font_sz = 24,
				text_color = "ffffff",
				background = {28, 28, 28, 127},
				animation = 10
			}
		}
	},
	on_load = "/target/composition/selectors/list/generate=/home"
}

return {
	label = "Statusbar(TextBg)",
	version = 1,
	frag =
[[
	uniform vec4 color;
	float obj_opacity;

	void main()
	{
		gl_FragColor = color;
	}
]],
	uniforms = {
		color = {
			label = 'Color',
			utype = 'ffff',
			default = {1.0, 1.0, 1.0, 0.01}
		}
	},
	states = {
		active = { uniforms = { color = {1.0, 1.0, 1.0, 0.2} } },
		locked = { uniforms = { color = {0.4078, 0.05, 0.05, 0.9} } }
	}
};

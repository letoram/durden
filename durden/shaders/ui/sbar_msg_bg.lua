return {
	label = "Statusbar(TextBg)",
	version = 1,
	frag =
[[
	uniform vec4 col;
	float obj_opacity;

	void main()
	{
		gl_FragColor = col;
	}
]],
	uniforms = {
		col = {
			label = 'Color',
			utype = 'ffff',
			default = {1.0, 1.0, 1.0, 0.01}
		}
	},
	states = {
		active = { uniforms = { col = {1.0, 1.0, 1.0, 0.2} } },
		locked = { uniforms = { col = {0.4078, 0.05, 0.05, 0.9} } }
	}
};

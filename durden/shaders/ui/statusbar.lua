return {
	label = "Statusbar",
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
		col= {
			label = 'Color',
			utype = 'ffff',
			default = {0.5, 0.5, 0.5, 0.1}
		}
	}
};

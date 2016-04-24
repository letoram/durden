return {
	label = "Statusbar",
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
			default = {0.5, 0.5, 0.5, 0.1}
		}
	}
};

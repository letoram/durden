return {
	label = "Launchbar(Background)",
	version = 1,
	frag =
[[
	uniform vec4 col;
	uniform float obj_opacity;

	void main()
	{
		gl_FragColor = vec4(col.rgb, col.a * obj_opacity);
	}
]],
	uniforms = {
		col = {
			label = 'Color',
			utype = 'ffff',
			default = {0.0, 0.0, 0.0, 0.8},
			low = 0.0,
			high = 1.0
		}
	}
};

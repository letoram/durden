return {
	label = "Launchbar(Background)",
	version = 1,
	frag =
[[
	uniform vec4 color;
	uniform float obj_opacity;

	void main()
	{
		gl_FragColor = vec4(color.rgb, color.a * obj_opacity);
	}
]],
	uniforms = {
		color = {
			label = 'Color',
			utype = 'ffff',
			default = {0.0, 0.0, 0.0, 0.8},
			low = 0.0,
			high = 1.0
		}
	}
};

return {
	label = "Launchbar",
	version = 1,
	frag =
[[
	uniform vec3 obj_col;
	uniform float obj_opacity;

	void main()
	{
		gl_FragColor = vec4(obj_col, obj_opacity);
	}
]],
	uniforms = {}
};

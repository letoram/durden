return {
	label = "Titlebar",
	version = 1,
	frag =
[[
	uniform vec3 col;
	uniform float obj_opacity;

	void main()
	{
		gl_FragColor = vec4(col.rgb, obj_opacity);
	}
]],
	uniforms = {
		col = {
			label = 'Color',
			utype = 'fff',
			default = {1.0, 1.0, 1.0}
		}
	},
	states = {
		suspended = {uniforms = { col = {0.6, 0.0, 0.0} } },
		active = { uniforms = { col = {0.235, 0.4078, 0.53} } },
		inactive = { uniforms = { col = {0.109, 0.21, 0.349} } },
		alert = { uniforms = { col = {1.0, 0.54, 0.0} } },
	}
};

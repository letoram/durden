return {
	label = "Titlebar(icon)",
	version = 1,
	frag =
[[
	uniform float obj_opacity;
	uniform sampler2D map_tu0;
	uniform vec4 weights;
	varying vec2 texco;

	void main()
	{
		vec4 col = texture2D(map_tu0, texco).rgba;
		col.a *= obj_opacity;
		gl_FragColor = weights * col;
	}
]],
	uniforms = {
		weights = {
			label = 'Weights',
			utype = 'ffff',
			default = {1.0, 1.0, 1.0, 0.2}
		}
	},
	states = {
		suspended = {uniforms = { weights = {1.0, 0.0, 0.0, 0.2} } },
		active = { uniforms = { weights = {1.0, 1.0, 1.0, 0.7} } },
		inactive = { uniforms = { weights = {1.0, 1.0, 1.0, 0.2} } },
		alert = { uniforms = { weights = {1.0, 1.0, 1.0, 1.0} } },
	}
};

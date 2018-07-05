return {
	label = "Titlebar",
	version = 1,
	frag =
[[
	uniform vec4 col;
	uniform float obj_opacity;
	uniform vec3 obj_col;
	uniform float weight;

	void main()
	{
		gl_FragColor = vec4(mix(obj_col.rgb, col.rgb, weight), col.a * obj_opacity);
	}
]],
	uniforms = {
		col = {
			label = 'Color',
			utype = 'ffff',
			default = {1.0, 1.0, 1.0, 1.0}
		},
		weight = {
			label = 'Weight',
			utype = 'f',
			default = {0.0},
			description = 'Mix weight between source color and state color'
		}
	},
	states = {
		suspended = {uniforms = { col = {0.6, 0.0, 0.0, 0.9}, weight = 1.0 } },
		active = { uniforms = { col = {0.0, 0.0, 0.0, 0.9}, weight = 0.0} },
		inactive = { uniforms = { col = {0.0, 0.0, 0.0, 0.9}, weight = 0.8} },
		alert = { uniforms = { col = {1.0, 0.54, 0.0, 0.9}, weight = 1.0} }
	}
};

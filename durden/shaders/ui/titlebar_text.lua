-- used for text labels and similar items on statusbar that need to
-- inherit visibility but not subject itself to that alpha
return {
	label = "Titlebar(Text)",
	version = 1,
	frag = [[
	uniform sampler2D map_tu0;
	varying vec2 texco;
	uniform vec3 col;
	uniform float obj_opacity;

	void main()
	{
		float alpha = texture2D(map_tu0, texco).a;
		gl_FragColor = vec4(col.rgb, alpha * obj_opacity);
	}
]],
	uniforms = {
		col=	{
		label = 'Color',
		utype = 'fff',
		default = {1.0, 1.0, 1.0},
		low = 0.0,
		high = 1.0
		}
	},
	states = {
		active = { uniforms = { col= {1.0, 1.0, 1.0} } },
		inactive = { uniforms = { col= {0.8, 1.0, 0.8} } },
	}
};

-- used for text labels and similar items on statusbar that need to
-- inherit visibility but not subject itself to that alpha
return {
	label = "Titlebar(Text)",
	version = 1,
	frag = [[
	uniform sampler2D map_tu0;
	varying vec2 texco;
	uniform vec3 color;
	uniform float obj_opacity;

	void main()
	{
		float alpha = texture2D(map_tu0, texco).a;
		gl_FragColor = vec4(color.rgb, alpha * obj_opacity);
	}
]],
	uniforms = {
		color =	{
		label = 'Color',
		utype = 'fff',
		default = {1.0, 1.0, 1.0},
		low = 0.0,
		high = 1.0
		}
	},
	states = {
		active = { uniforms = { color = {1.0, 1.0, 1.0} } },
		inactive = { uniforms = { color = {0.8, 1.0, 0.8} } },
	}
};

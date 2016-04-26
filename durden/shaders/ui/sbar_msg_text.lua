-- used for text labels and similar items on statusbar that need to
-- inherit visibility but not subject itself to that alpha
return {
	label = "Statusbar(Text)",
	version = 1,
	frag =
[[
	uniform sampler2D map_tu0;
	varying vec2 texco;
	float obj_opacity;

	void main()
	{
		gl_FragColor = vec4(texture2D(map_tu0, texco).rgba);
	}
]],
	uniforms = {
	},
};

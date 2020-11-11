-- used for text labels and similar items on statusbar that need to
-- inherit visibility but not subject itself to that alpha
return {
	label = "Statusbar(TileText)",
	version = 1,
	frag =
[[
	uniform sampler2D map_tu0;
	uniform float factor;
	uniform float mix_u;
	uniform vec3 col;
	varying vec2 texco;

	void main()
	{
		vec4 txcol = texture2D(map_tu0, texco);
		vec3 bc = mix(col, txcol.rgb, mix_u);
		gl_FragColor = vec4(bc.rgb * factor, txcol.a);
	}
]],
	uniforms = {
		col =	{
		label = 'Color',
		utype = 'fff',
		default = {1.0, 1.0, 1.0},
		low = 0.0,
		high = 1.0
		},
		factor = {
		label = 'Factor',
		utype = 'f',
		default = 1.0,
		low = 0.1,
		high = 1.0
		},
-- use static color or override?
		mix_u = {
		label = 'Mix',
		utype = 'f',
		default = 1.0,
		low = 0.0,
		high = 1.0
		}
	},
	states = {
		inactive = { uniforms = { factor = 0.3 } }
	}
};

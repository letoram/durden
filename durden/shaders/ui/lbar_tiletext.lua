return {
	version = 1,
	label = "lbar tile-text",
	frag = [[
uniform sampler2D map_tu0;
uniform vec4 col;
uniform float obj_opacity;
varying vec2 texco;

void main()
{
	vec4 txv = texture2D(map_tu0, texco).rgba;
	float luma = (txv.r + txv.g + txv.b) / 3.0;
	gl_FragColor = vec4(col.r * luma,
		col.g * luma, col.b * luma, txv.a * obj_opacity);
}
]],
	uniforms = {
		col = {
			label = "Text Color",
			utype = 'ffff',
			default = {1.0, 1.0, 1.0, 1.0},
			low = 0,
			high = 1.0
		},
	},
	states = {
		active = { uniforms = { col = {1.0, 1.0, 1.0, 1.0} } },
		inactive = { uniforms = { col = {0.5, 0.5, 0.5, 1.0} } },
	}
};

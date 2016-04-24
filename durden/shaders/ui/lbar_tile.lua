return {
	version = 1,
	label = "Launchbar(Tile)",
	frag = [[
uniform vec4 col_bg;
uniform float obj_opacity;
uniform vec2 obj_output_sz;

void main()
{
	gl_FragColor = vec4(col_bg.rgb, col_bg.a * obj_opacity);
}
]],
	uniforms = {
		col_bg = {
			label = "Background Color",
			utype = 'ffff',
			default = {1.0, 0.08, 0.08, 1.0},
			low = 0,
			high = 1.0
		},
	},
	states = {
		active = { uniforms = { col_bg = {0.1, 0.1, 0.1, 1.0} } },
		inactive = { uniforms = { col_bg = {0.05, 0.05, 0.05, 0.5} } }
	}
};

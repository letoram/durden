return {
	version = 1,
	label = "Statusbar(Tile)",
	frag = [[
uniform float border;
uniform vec3 col_border;
uniform vec3 col_bg;
uniform vec2 obj_output_sz;
varying vec2 texco;

void main()
{
	float bstep_x = border/obj_output_sz.x;
	float bstep_y = border/obj_output_sz.y;

	bvec2 marg1 = greaterThan(texco, vec2(1.0 - bstep_x, 1.0 - bstep_y));
	bvec2 marg2 = lessThan(texco, vec2(bstep_x, bstep_y));
	float f = float( !(any(marg1) || any(marg2)) );

	gl_FragColor = vec4(mix(col_border, col_bg, f), 1.0);
}
]],
	uniforms = {
		col_border = {
			label = 'Border Color',
			utype = 'fff',
			default = {0.5, 0.5, 0.5},
			low = 0,
			high = 1.0
		},
		border = {
			label = 'Border Size',
			utype = 'f',
			default = 1.0,
			low = 0.0,
			high = 10.0
		},
		col_bg = {
			label = "Tile Color",
			utype = 'fff',
			default = {0.135, 0.135, 0.135},
			low = 0,
			high = 1.0
		},
 	},
	states = {
		inactive = { uniforms = {
			col_border = {0.3, 0.3, 0.3},
			col_bg = {0.03, 0.03, 0.03}
		} },
		alert = { uniforms = {
			col_border = {1.0, 1.0, 0.0},
			col_bg = {0.549, 0.549, 0.0}
		} }
	}
};

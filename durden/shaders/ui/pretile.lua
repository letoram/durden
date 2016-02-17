return {
	version = 1,
	label = "Pretile",
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
			default = {0.7, 0.0, 0.0},
			low = 0,
			high = 1.0
		},
		col_bg = {
			label = "Tile Color",
			utype = 'fff',
			default = {0.06, 0.0, 0.0},
			low = 0,
			high = 1.0
		},
		border = {
			label = 'Border Size',
			utype = 'f',
			default = 1.0,
			low = 0.0,
			high = 10.0
		}
	},
	states = {
	}
};

return {
	version = 1,
	label = "Statusbar(Tile)",
	frag = [[
uniform float border;
uniform float factor;
uniform vec3 obj_col;
uniform vec4 col_bg;
uniform vec2 obj_output_sz;
varying vec2 texco;

#ifdef FULL_BORDER
float full_border(float bstep_x, float bstep_y)
{
	bvec2 marg1 = greaterThan(texco, vec2(1.0 - bstep_x, 1.0 - bstep_y));
	bvec2 marg2 = lessThan(texco, vec2(bstep_x, bstep_y));
	return float( !(any(marg1) || any(marg2)) );
}
#else
float underline(float bstep_y)
{
	return float( !(texco.t > 1.0 - bstep_y && (texco.s > 0.2 && texco.s < 0.8 )) );
}
#endif

void main()
{
	float bstep_y = border/obj_output_sz.y;

#ifdef FULL_BORDER
	float bstep_x = border/obj_output_sz.x;
	float f = full_border(bstep_x, bstep_y);
#else
	float f = underline(bstep_y);
#endif
	vec4 fg = vec4(obj_col.r, obj_col.g, obj_col.b, 1.0);
	gl_FragColor =
		vec4(factor, factor, factor, 0.3) * vec4(mix(fg, col_bg, f));
}
]],
	uniforms = {
		border = {
			label = 'Border Size',
			utype = 'f',
			default = 1.0,
			low = 0.0,
			high = 10.0
		},
		col_bg = {
			label = "Tile Color",
			utype = 'ffff',
			default = {0.135, 0.135, 0.135, 1.0},
			low = 0,
			high = 1.0
		},
		factor = {
			label = "Factor",
			utype = 'f',
			default = 1.0,
			low = 0.1,
			high = 1.0
		}
 	},
	states = {
		inactive = { uniforms = {
			factor = 0.2
		} },
		alert = { uniforms = {
			col_bg = {0.549, 0.549, 0.0, 1.0},
			factor = 1.0
		} }
	}
};

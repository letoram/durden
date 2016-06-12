return {
	version = 1,
	label = "Selection(Region)",
	frag = [[
uniform sampler2D map_tu0;
uniform vec2 obj_output_sz;
uniform float obj_opacity;
varying vec2 texco;

void main()
{
	float bstep_x = 1.0 / obj_output_sz.x;
	float bstep_y = 1.0 / obj_output_sz.y;

	bvec2 marg1 = greaterThan(texco, vec2(1.0 - bstep_x, 1.0 - bstep_y));
	bvec2 marg2 = lessThan(texco, vec2(bstep_x, bstep_y));
	float f = float( !(any(marg1) || any(marg2)) );

	gl_FragColor = vec4(texture2D(map_tu0, texco).rgb,
		1.0 - ((1.0 - obj_opacity) * f));
}
]],
	uniforms = {
	},
	states = {
	}
};

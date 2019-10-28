-- used for text labels and similar items on statusbar that need to
-- inherit visibility but not subject itself to that alpha
return {
	label = "Miniature",
	version = 1,
	frag =
[[
	uniform sampler2D map_tu0;
	uniform vec2 obj_output_sz;
	uniform float obj_opacity;
	varying vec2 texco;

	void main()
	{
		float step_s = 1.0 / obj_output_sz.x;
		float step_t = 1.0 / obj_output_sz.y;

/* bias towards center */
		if (texco.x > 0.5)
			step_s = step_s * -1.0;

		if (texco.y > 0.5)
			step_t = step_t * -1.0;

/* sample 2x2 */
		vec3 sum = vec3(0);
		vec3 a = texture2D(map_tu0,
			vec2(texco.x + 0.0 * step_s, texco.y + 0.0 * step_t)).rgb;
		vec3 b = texture2D(map_tu0,
			vec2(texco.x + 1.0 * step_s, texco.y + 0.0 * step_t)).rgb;
		vec3 c = texture2D(map_tu0,
			vec2(texco.x + 1.0 * step_s, texco.y + 1.0 * step_t)).rgb;
		vec3 d = texture2D(map_tu0,
			vec2(texco.x + 0.0 * step_s, texco.y + 1.0 * step_t)).rgb;

/* and add together, maybe adjust weights on intensity? */
		sum += a * 0.2;
		sum += b * 0.2;
		sum += c * 0.2;
		sum += d * 0.2;

	gl_FragColor = vec4(sum,  obj_opacity);
	}
]],
	uniforms = {
	},
	states = {
		active = { uniforms = { } }
	}
};

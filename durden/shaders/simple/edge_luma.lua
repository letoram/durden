return {
	version = 1,
	label = "Edge Detection",
	filter = "none",
	uniforms = {
	},
	frag =
[[
uniform sampler2D map_tu0;
uniform vec2 obj_output_sz;
uniform float obj_opacity;
varying vec2 texco;

void main(void)
{
	vec4 n[9];
	float ss = 1.0 / obj_output_sz.x;
	float st = 1.0 / obj_output_sz.y;

/* sample around current */
	vec4 samples[9];
	samples[0] = texture2D(map_tu0, texco + vec2(-ss, -st));
	samples[1] = texture2D(map_tu0, texco + vec2(0.0, -st));
	samples[2] = texture2D(map_tu0, texco + vec2(-ss, -st));
	samples[3] = texture2D(map_tu0, texco + vec2(-ss, 0.0));
	samples[4] = texture2D(map_tu0, texco);
	samples[5] = texture2D(map_tu0, texco + vec2( ss, 0.0));
	samples[6] = texture2D(map_tu0, texco + vec2(-ss,  st));
	samples[7] = texture2D(map_tu0, texco + vec2(0.0,  st));
	samples[8] = texture2D(map_tu0, texco + vec2( ss,  st));

	vec4 edge_h = samples[2] + (2.0 * samples[5]) +
		samples[8]-(samples[0] + (2.0 * samples[3]) + samples[6]);

	vec4 edge_v = samples[0] + (2.0 * samples[1]) +
		samples[2]-(samples[6] + (2.0 * samples[7]) + samples[8]);

	vec4 sobel = sqrt(edge_h * edge_h + edge_v * edge_v);
	float luma = max(max(sobel.r, sobel.g), sobel.b);

	gl_FragColor = vec4(luma, luma, luma, obj_opacity);
}
]]
};

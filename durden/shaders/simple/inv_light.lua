return {
	version = 1,
	label = "Invert Light",
	filter = "none",
	uniforms = {
	},
	frag =
[[
uniform sampler2D map_tu0;
uniform float obj_opacity;
varying vec2 texco;

void main()
{
	vec3 col = texture2D(map_tu0, texco).rgb;
	float mv = min(min(col.r, col.g), col.b);
	float Mv = 1.0 - max(max(col.r, col.g), col.b);
	float delta = Mv - mv;
	col += vec3(delta, delta, delta);
	gl_FragColor = vec4(col, obj_opacity);
}]]
};

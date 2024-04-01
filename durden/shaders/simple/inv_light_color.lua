return {
	version = 1,
	label = "Invert/Preserve",
	description = "Inverts light/dark but preserves color at the expense of contrast",
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
	vec3 c = texture2D(map_tu0, texco).rgb;
	float shift = c.a - min(c.r, min(c.g, c.b)) - max(c.r, max(c.g, c.b));
	c = vec4(shift + c.r, shift + c.g, shift + c.b, c.a);
	gl_FragColor = vec4(c.r, c.g, c.b, c.a * obj_opacity);
}]]
};

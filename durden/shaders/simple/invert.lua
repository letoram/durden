return {
	version = 1,
	label = "Invert",
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
	gl_FragColor = vec4(1.0 - col.r, 1.0 - col.g, 1.0 - col.b, obj_opacity);
}]]
};

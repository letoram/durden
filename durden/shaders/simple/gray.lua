return {
	version = 1,
	label = "Luma",
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
	float luma = 0.2126 * col.r + 0.7152 * col.g + 0.0722 * col.b;
	gl_FragColor = vec4(luma, luma, luma, obj_opacity);
}]]
};

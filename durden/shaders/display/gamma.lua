return {
	version = 1,
	label = "Gamma",
	filter = "none",
-- needed to have txcos that is relative to orig. size
	uniforms = {
		exponent = {
			label = "Exponent",
			utype = "fff",
			default = {2.2, 2.2, 2.2},
			low = 0.1,
			high = 3.0,
		}
	},
	frag =
[[
uniform sampler2D map_tu0;
uniform vec3 exponent;
varying vec2 texco;

void main(){
	vec3 col = pow(texture2D(map_tu0, texco).rgb, 1.0 / exponent);
	gl_FragColor = vec4(col, 1.0);
}]]
};

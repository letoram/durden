return {
	version = 1,
	label = "Weighted",
	filter = "none",
	uniforms = {
		weights = {
			label = "Weights",
			utype = "fff",
			low = 0.0,
			high = 100.0,
			default = {1.0, 1.0, 1.0}
		}
	},
	frag =
[[
uniform sampler2D map_tu0;
uniform vec3 weights;
varying vec2 texco;

void main(){
	vec3 col = texture2D(map_tu0, texco).rgb;
	gl_FragColor = vec4(col * weights, 1.0);
}]]
};

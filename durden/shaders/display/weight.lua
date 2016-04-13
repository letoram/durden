return {
	version = 1,
	label = "Weighted",
	filter = "none",
-- needed to have txcos that is relative to orig. size
	uniforms = {
		weights = {
			utype = "fff",
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
	gl_FragColor = vec4(col * weightS, 1.0);
}]]
};

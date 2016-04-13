return {
	version = 1,
	label = "Basic",
	filter = "none",
-- needed to have txcos that is relative to orig. size
	uniforms = {
	},
	frag =
[[
uniform sampler2D map_tu0;
varying vec2 texco;

void main(){
	vec3 col = texture2D(map_tu0, texco).rgb;
	gl_FragColor = vec4(col, 1.0);
}]]
};

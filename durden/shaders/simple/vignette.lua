return {
	version = 1,
	label = "Vignette",
	filter = "none",
	uniforms = {
		amount = {
			label = "Radius",
			utype = "f",
			low = 0.0,
			high = 50.0,
			default = {15.0},
		},
	},
	frag =
[[
uniform sampler2D map_tu0;
uniform float obj_opacity;
varying vec2 texco;
uniform vec3 factor;
uniform float amount;

void main()
{
	vec4 col = texture2D(map_tu0, texco);
	vec2 suv = texco * (1.0 - texco.yx);
	float vig = suv.x * suv.y * amount;
	vig = pow(vig, 0.25);

	gl_FragColor = vec4(col.rgb * vig, obj_opacity);
}]]
};

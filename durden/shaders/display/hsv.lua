-- courtesy of https://gamedev.stackexchange.com/questions/59797/glsl-shader-change-hue-saturation-brightness

return {
	version = 1,
	label = "HSV",
	filter = "none",
	uniforms = {
		weights = {
			label = "Weight",
			utype = "fff",
			low = 0.0,
			high = 360.0,
			default = {0.0, 1.0, 1.0}
		}
	},
	frag =
[[
uniform sampler2D map_tu0;
uniform vec3 weights;
varying vec2 texco;

vec3 rgb2hsv(vec3 c)
{
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void main(){
	vec3 col = texture2D(map_tu0, texco).rgb;
	vec3 hsv = rgb2hsv(col).xyz;
	hsv.x = mod(hsv.x + (weights.x / 360.0), 1.0);
	hsv.yz *= weights.yz;
	hsv.yz = clamp(hsv.yz, 0.0, 1.0);
	col = hsv2rgb(hsv);

	gl_FragColor = vec4(col, 1.0);
}]]
};

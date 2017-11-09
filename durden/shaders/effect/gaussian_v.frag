uniform sampler2D map_tu0;
uniform float obj_opacity;
uniform vec2 obj_output_sz;
varying vec2 texco;
uniform float weight;

void main()
{
	vec4 sum = vec4(0.0);
	float blurv = 1.0 / obj_output_sz.y;
	sum += texture2D(map_tu0, vec2(texco.x, texco.y - 4.0 * blurv)) * 0.05;
	sum += texture2D(map_tu0, vec2(texco.x, texco.y - 3.0 * blurv)) * 0.09;
	sum += texture2D(map_tu0, vec2(texco.x, texco.y - 2.0 * blurv)) * 0.12;
	sum += texture2D(map_tu0, vec2(texco.x, texco.y - 1.0 * blurv)) * 0.15;
	sum += texture2D(map_tu0, vec2(texco.x, texco.y - 0.0 * blurv)) * 0.16;
	sum += texture2D(map_tu0, vec2(texco.x, texco.y + 1.0 * blurv)) * 0.15;
	sum += texture2D(map_tu0, vec2(texco.x, texco.y + 2.0 * blurv)) * 0.12;
	sum += texture2D(map_tu0, vec2(texco.x, texco.y + 3.0 * blurv)) * 0.09;
	sum += texture2D(map_tu0, vec2(texco.x, texco.y + 4.0 * blurv)) * 0.05;
	gl_FragColor = vec4(sum.r * weight, sum.g * weight, sum.b * weight, obj_opacity);
}

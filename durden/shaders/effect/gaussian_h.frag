uniform sampler2D map_tu0;
uniform float obj_opacity;
uniform vec2 obj_output_sz;
uniform float weight;
varying vec2 texco;

void main()
{
	vec4 sum = vec4(0.0);
	float blurh = 1.0 / obj_output_sz.x;
	sum += texture2D(map_tu0, vec2(texco.x - 4.0 * blurh, texco.y)) * 0.05;
	sum += texture2D(map_tu0, vec2(texco.x - 3.0 * blurh, texco.y)) * 0.09;
	sum += texture2D(map_tu0, vec2(texco.x - 2.0 * blurh, texco.y)) * 0.12;
	sum += texture2D(map_tu0, vec2(texco.x - 1.0 * blurh, texco.y)) * 0.15;
	sum += texture2D(map_tu0, vec2(texco.x - 0.0 * blurh, texco.y)) * 0.16;
	sum += texture2D(map_tu0, vec2(texco.x + 1.0 * blurh, texco.y)) * 0.15;
	sum += texture2D(map_tu0, vec2(texco.x + 2.0 * blurh, texco.y)) * 0.12;
	sum += texture2D(map_tu0, vec2(texco.x + 3.0 * blurh, texco.y)) * 0.09;
	sum += texture2D(map_tu0, vec2(texco.x + 4.0 * blurh, texco.y)) * 0.05;
	gl_FragColor = vec4(sum.r * weight, sum.g * weight, sum.b * weight, obj_opacity);
}

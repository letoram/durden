/*
 * shadow solution courtesy of Evan Wallace,
 * 'Fast Rounded Rectangle Shadows'
 * madebyevan.com/shaders/fast-rounded-rectangle-shadows
 * (MIT license), see github.com/evanw/glfx.js
 */
	uniform float obj_opacity;
	uniform float radius;
	uniform float sigma;
	uniform float weight;
	uniform float border_thickness;

	uniform vec2 obj_output_sz;
	uniform vec3 obj_col;
	uniform vec3 shadow_color;
	uniform vec3 border_color;
	varying vec2 texco;
	uniform sampler2D map_tu0;

vec2 error_function(vec2 x)
{
	vec2 s = sign(x), a = abs(x);
	x = 1.0 + (0.278393 + (0.230389 + 0.078108 * (a * a)) * a) * a;
	x *= x;
	return s - s / (x * x);
}

float gaussian(float x, float sigma)
{
	const float pi =  3.141592653589793;
	return exp(-(x * x) / (2.0 * sigma * sigma)) / (sqrt(2.0 * pi) * sigma);
}

float rounded_shadow_x(float x, float y, float sigma, float corner, vec2 halfv)
{
	float delta = min(halfv.y - corner - abs(y), 0.0);
	float curved = halfv.x - corner + sqrt(max(0.0, corner * corner - delta * delta));
	vec2 integral = 0.5 + 0.5 * error_function((x + vec2(-curved, curved)) * (sqrt(0.5)/sigma));
	return integral.y - integral.x;
}

float rounded_box_shadow(vec2 lower, vec2 upper, vec2 point, float sigma, float corner)
{
	vec2 center = (lower + upper) * 0.5;
	vec2 halfv = (upper - lower) * 0.5;
	point -= center;
	float low = point.y - halfv.y;
	float high = point.y + halfv.y;
	float start = clamp(-3.0 * sigma, low, high);
	float end = clamp(3.0 * sigma, low, high);

	float step = (end - start) / 4.0;
	float y = start + step * 0.5;
	float value = 0.0;
	for (int i = 0; i < 4; i++){
		value += rounded_shadow_x(point.x, point.y - y, sigma, corner, halfv) * gaussian(y, sigma) * step;
		y += step;
	}
	return value;
}

void main()
{
	float padding = 3.0 * sigma;
	vec2 vert = mix(vec2(0.0, 0.0) - padding, obj_output_sz + padding, texco);

	vec2 rvec = vec2(radius, radius);
	vec2 high = obj_output_sz;
	vec3 col;

/* with a in a small interval (say 0.90 to 0.99) use the border-color instead */
	float a = rounded_box_shadow(vec2(0.0, 0.0), high, vert, sigma, radius);

	if (a < 0.99){
		col = border_color;
		if (a < 0.99 - border_thickness){
			col = shadow_color;
			a *= weight;
		}
	}
	else {
		col = texture2D(map_tu0, texco).rgb;
	}

	gl_FragColor = vec4(col, max(obj_opacity * a, 0.0));
}

uniform sampler2D map_tu0;
varying vec2 texco;

uniform float hard_scan;
uniform float hard_pix;
uniform vec2 warp_xy;
uniform float mask_dark;
uniform float mask_light;
uniform float linear_gamma;
uniform float shadow_mask;
uniform float bright_boost;
uniform float bloom_x;
uniform float bloom_y;
uniform float bloom_amount;
uniform float filter_shape;

uniform vec2 obj_output_sz;
// uniform vec2 obj_storage_sz;

#define obj_storage_sz obj_output_sz

/* performance tuning */
// #define SIMPLE_LINEAR_GAMMA
#define DO_BLOOM

#ifdef SIMPLE_LINEAR_GAMMA
float to_linear1(float c){return c;}
vec3 to_linear(vec3 c){return c;}
vec3 to_srgb(vec3 c)
{
    return pow(c, vec3(1.0 / 2.2));
}
#else
float to_linear1(float c)
{
	if (linear_gamma == 0.)
		return c;

	if (c <= 0.04045)
		return c / 12.92;
	else
		return pow((c + 0.055) / 1.055, 2.4);
}

vec3 to_linear(vec3 c)
{
	if (linear_gamma==0.)
		return c;

	return vec3(
		to_linear1(c.r), to_linear1(c.g), to_linear1(c.b)
	);
}

// Linear to sRGB.
// Assuming using sRGB typed textures this should not be needed.
float to_srgb1(float c)
{
	if (linear_gamma == 0.)
		return c;

	if (c < 0.0031308)
		return c * 12.92;
	else
		return 1.055 * pow(c, 0.41666) - 0.055;
}

vec3 to_srgb(vec3 c)
{
	if (linear_gamma == 0.)
		return c;

	return vec3(
		to_srgb1(c.r), to_srgb1(c.g), to_srgb1(c.b)
	);
}
#endif

// Nearest emulated sample given floating point position and texel offset.
// Also zero's off screen.
vec3 fetch(vec2 pos,vec2 off){
	pos = (
		floor(pos*obj_storage_sz.xy+off) +
		vec2(0.5,0.5)
	) / obj_storage_sz.xy;

#ifdef SIMPLE_LINEAR_GAMMA
	return to_linear(
		bright_boost * pow(
			texture2D(map_tu0, pos.xy).rgb,
			vec3(2.2)
		)
	);
#else
	return to_linear(
		bright_boost * texture2D(map_tu0, pos.xy).rgb
	);
#endif
}

// Distance in emulated pixels to nearest texel.
vec2 dist(vec2 pos)
{
	pos = pos * obj_storage_sz.xy;
	return -((pos - floor(pos)) - vec2(0.5));
}

// 1D gaussian.
float gaus(float pos, float scale)
{
	return exp2(scale*pow(abs(pos), filter_shape));
}

// 3-tap gaussian filter along horz line.
vec3 horz3(vec2 pos, float off)
{
	vec3 b = fetch(pos, vec2(-1.0, off));
	vec3 c = fetch(pos, vec2( 0.0, off));
	vec3 d = fetch(pos, vec2( 1.0, off));
	float dst = dist(pos).x;

// Convert distance to weight.
	float scale = hard_pix;
	float wb = gaus(dst-1.0,scale);
	float wc = gaus(dst+0.0,scale);
	float wd = gaus(dst+1.0,scale);

	// Return filtered sample.
	return (b * wb + c * wc + d * wd) / (wb + wc + wd);
}

// 5-tap gaussian filter along horz line.
vec3 horz5(vec2 pos,float off){
	vec3 a = fetch(pos,vec2(-2.0, off));
	vec3 b = fetch(pos,vec2(-1.0, off));
	vec3 c = fetch(pos,vec2( 0.0, off));
	vec3 d = fetch(pos,vec2( 1.0, off));
	vec3 e = fetch(pos,vec2( 2.0, off));

// Convert distance to weight.
	float dst = dist(pos).x;

	float scale = hard_pix;
	float wa = gaus(dst - 2.0, scale);
	float wb = gaus(dst - 1.0, scale);
	float wc = gaus(dst + 0.0, scale);
	float wd = gaus(dst + 1.0, scale);
	float we = gaus(dst + 2.0, scale);

// Return filtered sample.
	return
		(a * wa + b * wb + c * wc + d * wd + e * we) /
		(wa + wb + wc + wd + we);
}

// 7-tap gaussian filter along horz line.
vec3 horz7(vec2 pos, float off)
{
	vec3 a = fetch(pos, vec2(-3.0, off));
	vec3 b = fetch(pos, vec2(-2.0, off));
	vec3 c = fetch(pos, vec2(-1.0, off));
	vec3 d = fetch(pos, vec2( 0.0, off));
	vec3 e = fetch(pos, vec2( 1.0, off));
	vec3 f = fetch(pos, vec2( 2.0, off));
	vec3 g = fetch(pos, vec2( 3.0, off));

	float dst = dist(pos).x;

// Convert distance to weight.
	float scale = bloom_x;
	float wa = gaus(dst - 3.0, scale);
	float wb = gaus(dst - 2.0, scale);
	float wc = gaus(dst - 1.0, scale);
	float wd = gaus(dst + 0.0, scale);
	float we = gaus(dst + 1.0, scale);
	float wf = gaus(dst + 2.0, scale);
	float wg = gaus(dst + 3.0, scale);

// Return filtered sample.
	return
		(a * wa + b * wb + c * wc + d * wd + e * we + f * wf + g * wg) /
		(wa + wb + wc + wd + we + wf + wg);
}

// Return scanline weight.
float scan(vec2 pos, float off)
{
	float dst = dist(pos).y;
	return gaus(dst + off, hard_scan);
}

// Return scanline weight for bloom.
float bloom_scan(vec2 pos, float off)
{
	float dst = dist(pos).y;
	return gaus(dst + off, bloom_y);
}

// Allow nearest three lines to effect pixel.
vec3 tri(vec2 pos)
{
	vec3 a = horz3(pos,-1.0);
	vec3 b = horz5(pos, 0.0);
	vec3 c = horz3(pos, 1.0);

	float wa = scan(pos,-1.0);
	float wb = scan(pos, 0.0);
	float wc = scan(pos, 1.0);

	return a*wa + b*wb + c*wc;
}

// Small bloom.
vec3 bloom(vec2 pos)
{
	vec3 a = horz5(pos,-2.0);
	vec3 b = horz7(pos,-1.0);
	vec3 c = horz7(pos, 0.0);
	vec3 d = horz7(pos, 1.0);
	vec3 e = horz5(pos, 2.0);

	float wa = bloom_scan(pos,-2.0);
	float wb = bloom_scan(pos,-1.0);
	float wc = bloom_scan(pos, 0.0);
	float wd = bloom_scan(pos, 1.0);
	float we = bloom_scan(pos, 2.0);

	return a * wa + b * wb + c * wc + d * wd + e * we;
}

// Distortion of scanlines, and end of screen alpha.
vec2 warp(vec2 pos)
{
	pos = pos * 2.0 - 1.0;
	pos *= vec2(
		1.0 + (pos.y * pos.y) * warp_xy[0],
		1.0 + (pos.x * pos.x) * warp_xy[1]
	);

	return pos*0.5 + 0.5;
}

// Shadow mask.
vec3 mask(vec2 pos)
{
	vec3 mask = vec3(mask_dark, mask_dark, mask_dark);

// Very compressed TV style shadow mask.
	if (shadow_mask == 1.0){
		float line = mask_light;
		float odd = 0.0;

		if (fract(pos.x * 0.166666666) < 0.5)
			odd = 1.0;
		if (fract((pos.y + odd) * 0.5) < 0.5)
			line = mask_dark;

		pos.x = fract(pos.x*0.333333333);

		if (pos.x < 0.333)
			mask.r = mask_light;
		else if (pos.x < 0.666)
			mask.g = mask_dark;
		else
			mask.b = mask_light;
		mask*=line;
	}

// Aperture-grille.
	else if (shadow_mask == 2.0){
		pos.x = fract(pos.x*0.333333333);
		if (pos.x < 0.333)
			mask.r = mask_light;
		else if (pos.x < 0.666)
			mask.g = mask_light;
		else
			mask.b = mask_light;
	}

// Stretched VGA style shadow mask (same as prior shaders).
	else if (shadow_mask == 3.0){
		pos.x += pos.y * 3.0;
		pos.x = fract(pos.x * 0.166666666);

		if (pos.x < 0.333)
			mask.r = mask_light;
		else if (pos.x < 0.666)
			mask.g = mask_light;
		else
			mask.b = mask_light;
	}

// VGA style shadow mask.
	else if (shadow_mask == 4.0){
		pos.xy = floor(pos.xy * vec2(1.0, 0.5));
		pos.x += pos.y * 3.0;
		pos.x = fract(pos.x*0.166666666);

		if (pos.x < 0.333)
			mask.r = mask_light;
		else if (pos.x < 0.666)
			mask.g = mask_light;
		else
			mask.b = mask_light;
	}

	return mask;
}

void main()
{
	vec2 pos =
		warp(texco.xy * (obj_storage_sz.xy / obj_output_sz.xy)) *
		(obj_output_sz.xy / obj_storage_sz.xy);

	vec3 col = tri(pos);

#ifdef DO_BLOOM
	col.rgb += bloom(pos) * bloom_amount;
#endif

	if (shadow_mask > 0.0)
		col.rgb *= mask(gl_FragCoord.xy * 1.000001);

/* TODO/FIXME - hacky clamp fix */
	vec2 bordertest = (pos);
	if (bordertest.x > 0.0001 && bordertest.x < 0.9999 &&
		bordertest.y > 0.0001 && bordertest.y < 0.9999){
		col.rgb = col.rgb;
	}
	else{
		col.rgb = vec3(0.0);
	}

	gl_FragColor = vec4(to_srgb(col.rgb), 1.0);
}


-- needed optimizations
--
-- a. only stepframe / update once per frame (don't event-drive from other
--    states, invalidate + preframe state is ok)
-- b. synch / track the caster-set rather than rebuild
-- c. occlusion-pass to filter non-visible
-- d. use depth buffer?
-- e. use shadow-map as lookup for each render-output? (awful to write)
-- f. downscale + blur + upscale + discard full-opaque (or use alpha test)
-- g. re-use deformed surfaces? (i.e. cloth-drag-window should cast shadow)
-- h. alpha- only mode
-- i. draw rt without background in shadow mode, just use rt as shadow map
--    on composition and just ignore all the rest, but would need depth vals.
-- j. memory consumption can be reduced with:
--    https://github.com/mattdesl/lwjgl-basics/wiki/2D-Pixel-Perfect-Shadows
-- g. just go nuts and go raytrace / gi / radiosity
-- h. limit (a) to the rate of the output display, (pfp- mask needed in eh)
--

-- sketch for dynamic shadows,
--
-- for both versions we build a rendertarget with the shadow casters,
-- 1. linearize active space
-- 2. for each window, use the wnd.width/wnd.height if shadowcaster
-- 3. draw into dst as opaque
-- 4. hook to update on each animated frame with window animations
--
-- one options is:
-- raytrace / render into 1D texture based on a point light (cursor)
--
-- other option is:
--  gaussian blur step, draw as overlay and discard opaque
--

-- we keep the shaders and support script separate from the other
-- subsystems so that the effects are easier to develop, test and
-- share outside a full durden setup
--

local shadow_gaussian_h = [[
uniform sampler2D map_tu0;
uniform float obj_opacity;
uniform vec2 obj_output_sz;
varying vec2 texco;

float get_alpha(float s, float t, float ra)
{
	vec4 cv = texture2D(map_tu0, vec2(s, t));
	return cv.a; //float(ra > cv.a);
}

void main()
{
	float sum = .0;
	float blurh = 1.0 / obj_output_sz.x;
	float ra = texture2D(map_tu0, texco.st).a;

	if (ra < 0.09)
		discard;

#ifdef PASS2
	sum += get_alpha(texco.x - 4.0 * blurh, texco.y, ra) * 0.05;
	sum += get_alpha(texco.x - 3.0 * blurh, texco.y, ra) * 0.09;
	sum += get_alpha(texco.x - 2.0 * blurh, texco.y, ra) * 0.12;
	sum += get_alpha(texco.x - 1.0 * blurh, texco.y, ra) * 0.15;
	sum += get_alpha(texco.x - 0.0 * blurh, texco.y, ra) * 0.16;
	sum += get_alpha(texco.x + 1.0 * blurh, texco.y, ra) * 0.15;
	sum += get_alpha(texco.x + 2.0 * blurh, texco.y, ra) * 0.12;
	sum += get_alpha(texco.x + 3.0 * blurh, texco.y, ra) * 0.09;
	sum += get_alpha(texco.x + 4.0 * blurh, texco.y, ra) * 0.05;
#else
	sum += get_alpha(texco.x, texco.y - 4.0 * blurh, ra) * 0.05;
	sum += get_alpha(texco.x, texco.y - 3.0 * blurh, ra) * 0.09;
	sum += get_alpha(texco.x, texco.y - 2.0 * blurh, ra) * 0.12;
	sum += get_alpha(texco.x, texco.y - 1.0 * blurh, ra) * 0.15;
	sum += get_alpha(texco.x, texco.y - 0.0 * blurh, ra) * 0.16;
	sum += get_alpha(texco.x, texco.y + 1.0 * blurh, ra) * 0.15;
	sum += get_alpha(texco.x, texco.y + 2.0 * blurh, ra) * 0.12;
	sum += get_alpha(texco.x, texco.y + 3.0 * blurh, ra) * 0.09;
	sum += get_alpha(texco.x, texco.y + 4.0 * blurh, ra) * 0.05;
#endif

	float a = float(sum > 1.0);
	gl_FragColor = vec4(sum, sum, sum, 1.0); // 1.0 * a); // sum > 1.0);
}
]];

local shid = build_shader(nil, shadow_gaussian_h, "sgh");

local function tiler_casters(tiler, fx, fy)
	local lst = {};

-- bin shadow caster order, encode into alpha channel (tradeoff in number
-- of shadow caster levels) and then use the alpha value in the shader when
-- doing the blur sampling
	for j,k in ipairs(tiler.windows) do
		local props = image_surface_resolve(k.border);
		local nsrf = color_surface(props.width*fx, props.height*fy, 255, 255, 255);

		if (not valid_vid(nsrf)) then
			return;
		else
			show_image(nsrf);
			move_image(nsrf, props.x * fx, props.y * fy);
			blend_image(nsrf, 0.1 + props.order / 100);
			order_image(nsrf, props.order);
			force_image_blend(nsrf, BLEND_FORCE);
			table.insert(lst, nsrf);
		end
	end

-- other shadow casters can be added here, e.g. statusbar
	return lst;
end

local function build_map(w, h)
	local surf = alloc_surface(0.3 * w, 0.3 * h);

	define_rendertarget(
		surf, tiler_casters(active_display(), 0.4, 0.4),
		RENDERTARGET_DETACH, RENDERTARGET_NOSCALE, 0,
			bit.bor(RENDERTARGET_COLOR, RENDERTARGET_ALPHA));
	image_color(surf, 0, 0, 0, 0);
	order_image(surf, 1000);
	blend_image(surf, 1.0);
	resize_image(surf, w, h);
	rendertarget_forceupdate(surf);
	image_shader(surf, shid);
	return surf;
end

return function()
	return build_map(active_display().width, active_display().height);
end

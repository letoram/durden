local frag_1 = [[
varying vec2 texco;

vec3 hsv2rgb(vec3 c)
{
	vec3 step = vec3(0.0, 4.0, 2.0);
	vec3 rgb = clamp(
		abs(
			mod(c.x * 6.0 + step, 6.0) - 3.0
		) - 1.0, 0.0, 1.0
	);
	return c.z * mix(vec3(1.0), rgb, c.y);
}

void main()
{
	gl_FragColor = vec4(hsv2rgb(vec3(texco.s, 1.0, 1.0 - texco.t)), 1.0);
}
]];

local frag2 = [[
/* conversion of IQs palette demo
 * License: MIT
 * Copyright (C) 2015 Inigo Quilez */

varying vec2 texco;

vec3 pal(float t, vec3 a, vec3 b, vec3 c, vec3 d )
{
    return a + b*cos( 6.28318*(c*t+d) );
}

void main()
{
	vec2 p = texco;
    // compute colors
    vec3                col = pal( p.x, vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,1.0,1.0),vec3(0.0,0.33,0.67) );
    if( p.y>(1.0/7.0) ) col = pal( p.x, vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,1.0,1.0),vec3(0.0,0.10,0.20) );
    if( p.y>(2.0/7.0) ) col = pal( p.x, vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,1.0,1.0),vec3(0.3,0.20,0.20) );
    if( p.y>(3.0/7.0) ) col = pal( p.x, vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,1.0,0.5),vec3(0.8,0.90,0.30) );
    if( p.y>(4.0/7.0) ) col = pal( p.x, vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,0.7,0.4),vec3(0.0,0.15,0.20) );
    if( p.y>(5.0/7.0) ) col = pal( p.x, vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(2.0,1.0,0.0),vec3(0.5,0.20,0.25) );
    if( p.y>(6.0/7.0) ) col = pal( p.x, vec3(0.8,0.5,0.4),vec3(0.2,0.4,0.2),vec3(2.0,1.0,1.0),vec3(0.0,0.25,0.25) );
	float f = fract(p.y * 7.0);
	col *= smoothstep( 0.49, 0.47, abs(f-0.5) );
	col *= 0.5 + 0.5*sqrt(4.0*f*(1.0-f));
	gl_FragColor = vec4(col, 1.0);
}
]];

-- we do this as a generate+readback thing
local function probe(ctx, yh, ident)
	return 1;
end

local shader_1;
local shader_2;
local function build_colorimage(w, h)
	local nelem = 2;
	local cellw = math.ceil(w / nelem);

-- temporary rendertarget to image
	local v1 = null_surface(cellw, y);
	local v2 = null_surface(cellw, y);
	if (not valid_vid(v2)) then
		delete_image(v1);
		return;
	end
	local v3 = null_surface(cellw, y);
	if (not valid_vid(v3)) then
		delete_image(v2);
		return;
	end

	if not shader_1 then
		shader_1 = build_shader(nil, frag_1, "colorpick_1");
	end

	if not shader_2 then
		shader_2 = build_shader(nil, frag_2, "colorpick_2");
	end

-- build intermediate buffer
	show_image({v1, v2, v3});
	local buf = alloc_surface(w, h, true);
	if not valid_vid(buf) then
		delete_image(v1);
		delete_image(v2);
		delete_image(v3);
		return;
	end

-- offscreen render to buffer
	image_shader(v1, shader_1);
	image_shader(v2, shader_2);
	show_image({v1, v2, v3});
	define_rendertarget(buf,
		{v1, v2, v3}, RENDERTARGET_DETACH, RENDERTARGET_NOSCALE, 0);
	rendertarget_forceupdate(buf);

-- save the contents but delete all other resources
	rendertarget_detach(buf, v1);
	image_sharestorage(buf, v1);
	delete_image(buf);

	return v1;
end

local shader;
local function show(ctx, anchor, ofs, yh)
	local w = math.clamp(yh * 3.0, 0, active_display().width);
	local vid = build_colorimage(w, yh);
	if not valid_vid(vid) then
		return 0, 0;
	end

	local buf = alloc_surface(w, yh, true);
	if not valid_vid(buf) then
		return 0;
	end

-- attach so we autoclean
	show_image(surf);
	link_image(surf, anchor);
	image_inherit_order(surf, true);

-- add the clickhandler that lets us actually get the color

	return w, yh;
end

-- could also cache this a bit and add a cleanup timer to make it faster
local function destroy(ctx)
	if ctx.mouseh then
		mouse_droplistener(ctx.mouseh);
		ctx.mouseh = nil;
	end
end

return {
	name = "colorpick",
-- the name specifies what kind of format should be set on click
	paths = {
		"special:colorpick_r8g8b8",
		"special:colorpick_r8g8b8a8",
		"special:colorpick_rgbstr",
		"special:colorpick_rgbaf",
		"special:colorpick_rgbf"
	},
	show = show,
	probe = probe,
	destroy = destroy
};
